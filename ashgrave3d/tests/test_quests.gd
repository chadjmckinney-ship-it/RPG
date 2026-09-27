extends TestCase
## Dialogue, quests (hand-written and generated), recruitment and their save data.

func _fresh() -> void:
	GameState.reset()
	GameState.new_world(1337)

func _boot(recruits := ["maren"]) -> Node:
	_fresh()
	GameState.recruited = recruits.duplicate()
	var main: Node = load("res://main.tscn").instantiate()
	main.spawn_encounters = false
	tree.root.add_child(main)
	await tree.process_frame
	TacticalPause.set_paused(false)
	return main

func _teardown(main: Node) -> void:
	main.panels.close_all()
	TacticalPause.set_paused(false)
	main.queue_free()
	await tree.process_frame
	GameState.reset()

func _choose_label(d: Dialogue, needle: String) -> bool:
	for i in d.node.choices.size():
		if needle in d.node.choices[i].label:
			return d.choose(i)
	return false

func test_script_ops() -> void:
	_fresh()
	ScriptOps.run_all(["flag:met", "give:hide:4", "rep:hollow:7"])
	check(ScriptOps.check("flag:met") and not ScriptOps.check("!flag:met"), "flag ops")
	check(ScriptOps.check("has:hide:4") and not ScriptOps.check("has:hide:5"), "has op")
	check(ScriptOps.check("coin:15") and not ScriptOps.check("coin:16"), "coin op")
	check(ScriptOps.check("rep:hollow:>=7") and not ScriptOps.check("rep:hollow:>=8"), "rep op")
	check(ScriptOps.check("recruited:maren") and ScriptOps.check("!recruited:oswin"), "recruited op")
	ScriptOps.run("take:hide:4")
	check(not ScriptOps.check("has:hide"), "take op")
	GameState.reset()

func test_story_locations() -> void:
	for s in [1337, 7, 424242, 99]:
		var w := WorldGen.new(s)
		var st := Story.setup(w)
		check(str(st) == str(Story.setup(WorldGen.new(s))), "story not deterministic for seed %d" % s)
		for id in ["start", "hollow", "company"]:
			check(not Story.village(w, st[id]).is_empty(), "seed %d: %s village missing" % [s, id])
		check(st.start != st.hollow, "seed %d: Nessa placed in the starting village" % s)
		for site in ["barrow", "chapel"]:
			var c: Vector2i = st[site]
			check(w.walkable(c) and w.village_near(c, 20.0).is_empty(), "seed %d: %s site bad at %s" % [s, site, c])

func test_generated_quests_point_at_real_things() -> void:
	var seen := {}
	for s in [1337, 7, 424242]:
		GameState.reset()
		GameState.new_world(s)
		var w := GameState.world
		var village_ids: Array = w.villages().map(func(v): return v.id)
		for v in w.villages():
			for job in ["keeper", "smith"]:
				for day in 4:
					var q := QuestGen.offer(w, "%s:%s" % [v.id, job], v, day)
					if q.is_empty():
						continue
					seen[q.template] = true
					for st in q.stages:
						check(st.target != null, "%s stage without a target" % q.title)
						match st.obj.type:
							"kill_camp":
								var ch := Vector2i(st.target[0] / WorldGen.CHUNK, st.target[1] / WorldGen.CHUNK)
								var ids: Array = Encounters.camps_for_chunk(w, ch).map(func(c): return c.id)
								check(ids.has(st.obj.camp), "%s points at missing camp %s" % [q.title, st.obj.camp])
							"talk":
								for opt in st.obj.options:
									var vid: String = opt.npc.split(":")[0]
									check(village_ids.has(vid), "%s talks to unknown npc %s" % [q.title, opt.npc])
									check(not opt.npc.ends_with(":villager"), "quest talk target is a nameless villager")
	for t in QuestGen.TEMPLATES:
		check(seen.has(t), "template %s never produced a quest" % t)
	GameState.reset()

func test_main_quest_flow() -> void:
	_fresh()
	GameState.inventory.add("coin", 0)
	var spawned := []
	var on_fx := func(e): spawned.append(e)
	Events.story_effect.connect(on_fx)
	QuestLog.start("mq_restless")
	var q: Dictionary = GameState.quests.mq_restless
	check(q.stage == 0 and QuestLog.current(q).obj.type == "kill_camp", "wrong first stage")
	var camp: String = QuestLog.current(q).obj.camp
	GameState.cleared_camps[camp] = true
	QuestLog.notify_kill("risen", camp)
	check(q.stage == 1, "clearing the camp didn't advance")
	var opts := QuestLog.talk_options("maud")
	check(opts.size() == 1 and opts[0].ok, "Maud has no turn-in option")
	var coin := GameState.inventory.count("coin")
	QuestLog.choose("mq_restless", opts[0].opt)
	check(q.status == "done" and GameState.inventory.count("coin") == coin + 30, "turn-in didn't pay")
	check(ScriptOps.check("active:mq_dust"), "second quest didn't start")
	# Grave Dust
	check(not QuestLog.talk_options("nessa")[0].ok, "Nessa accepted without dust")
	GameState.inventory.add("grave-dust", 3)
	QuestLog.choose("mq_dust", QuestLog.talk_options("nessa")[0].opt)
	check(ScriptOps.check("stage:mq_dust:1") and not GameState.inventory.has("grave-dust"), "dust hand-in failed")
	var barrow: Vector2i = Story.setup(GameState.world).barrow
	QuestLog.notify_positions([barrow + Vector2i(30, 0)])
	check(ScriptOps.check("stage:mq_dust:1"), "advanced while far from the barrow")
	QuestLog.notify_positions([barrow + Vector2i(2, 1)])
	check(ScriptOps.check("stage:mq_dust:2") and spawned.has("spawn:barrow"), "reaching the barrow didn't wake it")
	GameState.cleared_camps["story:barrow"] = true
	QuestLog.notify_kill("barrow_lord", "story:barrow")
	check(ScriptOps.check("stage:mq_dust:3"), "killing the barrow guard didn't advance")
	var choices := QuestLog.talk_options("harl")
	check(choices.size() == 1 and not choices[0].ok, "ledger choice available without the ledger")
	GameState.inventory.add("tithe-ledger")
	var companies: int = GameState.reputation.companies
	QuestLog.choose("mq_dust", QuestLog.talk_options("harl")[0].opt)
	check(ScriptOps.check("done:mq_dust") and ScriptOps.check("flag:ledger_companies"), "ledger decision didn't finish the quest")
	check(GameState.reputation.companies == companies + 30, "Harl's reputation reward missing")
	check(QuestLog.talk_options("maud").is_empty(), "stale choices after the decision")
	Events.story_effect.disconnect(on_fx)
	GameState.reset()

func test_dialogue_and_generated_work() -> void:
	var main: Node = await _boot()
	var start := Story.village(main.world, Story.setup(main.world).start)
	var maud: Villager = null
	var keeper: Villager = null
	for a in main.actors:
		if a is Villager:
			if a.npc_id == "maud": maud = a
			if a.npc_id == "%s:keeper" % start.id: keeper = a
	check(maud != null and keeper != null, "Maud or the tavern keeper missing from the start village")
	var d := Dialogue.new(maud)
	check(_choose_label(d, "What's happening"), "no way to ask Maud what's wrong")
	check(_choose_label(d, "I'll do it") and d.result == "end", "couldn't accept Maud's quest")
	check(ScriptOps.check("active:mq_restless"), "Maud's quest not active")
	var k := Dialogue.new(keeper)
	check(_choose_label(k, "Any work?"), "keeper offers no work")
	check(_choose_label(k, "I'll take it"), "couldn't accept work")
	var gen: Array = QuestLog.active().filter(func(q): return q.id.begins_with("gq"))
	check(gen.size() == 1 and gen[0].giver == keeper.npc_id, "generated quest not recorded")
	var again := Dialogue.new(keeper)
	var work: Array = again.node.choices.filter(func(c): return "Any work" in c.label)
	check(work.size() == 1 and not work[0].get("enabled", true), "keeper offered a second job")
	check(_choose_label(again, "trade") and again.result == "trade", "trade option missing")
	await _teardown(main)

func test_recruit_companion_in_world() -> void:
	var main: Node = await _boot()
	check(main.party.members.size() == 1, "should start with Maren alone")
	var oswin: Villager = null
	for a in main.actors:
		if a is Villager and a.npc_id == "oswin":
			oswin = a
	check(oswin != null, "Oswin not waiting in the start village")
	if oswin:
		var d := Dialogue.new(oswin)
		check(_choose_label(d, "Join my company") and _choose_label(d, "Welcome"), "recruit dialogue failed")
		await tree.process_frame
		check(main.party.members.size() == 2 and main.party.members[1].display_name == "Brother Oswin", "Oswin didn't join")
		check(not is_instance_valid(oswin) or oswin.is_queued_for_deletion(), "Oswin's NPC still in the village")
		check(ScriptOps.check("active:cq_oswin"), "Oswin's quest didn't start")
		var hp: float = main.party.members[1].max_hp
		ScriptOps.run("stat:oswin:max_hp:15")
		check(main.party.members[1].max_hp == hp + 15.0, "companion stat reward not applied")
		# Round-trip through save data
		var saved: Dictionary = JSON.parse_string(JSON.stringify(GameState.to_dict(main.party_state())))
		GameState.reset()
		GameState.load_dict(saved)
		check(GameState.recruited == ["maren", "oswin"], "recruits not saved: %s" % str(GameState.recruited))
		check(GameState.quests.cq_oswin.stage is int, "quest stage came back as %s" % typeof(GameState.quests.cq_oswin.stage))
		check(GameState.bonuses.oswin.max_hp == 15.0, "companion bonus not saved")
		check(ScriptOps.check("active:mq_restless") == false and ScriptOps.check("active:cq_oswin"), "quest state not restored")
	await _teardown(main)
