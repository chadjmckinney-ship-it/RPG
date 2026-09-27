extends TestCase
## Company XP and levels, talents, the third ability, regional danger and saving.

func _boot(recruited: Array) -> Node:
	GameState.recruited = recruited
	var main: Node = load("res://main.tscn").instantiate()
	main.spawn_encounters = false
	tree.root.add_child(main)
	await tree.process_frame
	return main

func test_levels_follow_thresholds() -> void:
	check(Progression.level_for(0) == 1, "0 XP should be level 1")
	check(Progression.level_for(79) == 1 and Progression.level_for(80) == 2, "level 2 starts at 80 XP")
	check(Progression.level_for(420) == 4, "420 XP should be level 4")
	check(Progression.level_for(999999) == Progression.MAX_LEVEL, "level should cap at %d" % Progression.MAX_LEVEL)
	for i in range(1, Progression.THRESHOLDS.size()):
		check(Progression.THRESHOLDS[i] > Progression.THRESHOLDS[i - 1], "thresholds must rise")

func test_award_emits_each_level() -> void:
	GameState.reset()
	var seen: Array = []
	var cb := func(lv): seen.append(lv)
	Events.leveled_up.connect(cb)
	Progression.award(230)          # 1 -> 3
	Progression.award(10)           # no new level
	Events.leveled_up.disconnect(cb)
	check(seen == [2, 3], "expected level-ups [2, 3], got %s" % [seen])
	check(Progression.xp_into_level() == 20 and Progression.xp_for_next() == 200, "wrong progress into level 3")
	GameState.reset()

func test_kill_xp_scales_with_rank() -> void:
	var base := Progression.kill_xp("risen", 0)
	check(base == 23, "risen should be worth 23 XP, got %d" % base)
	check(Progression.kill_xp("risen", 2) > base * 2, "rank 2 should more than double XP")
	check(Progression.kill_xp("barrow_lord", 0) == 180, "boss XP override ignored")

func test_growth_talents_and_third_ability() -> void:
	GameState.reset()
	var main: Node = await _boot(["maren", "oswin", "ketta"])
	var maren: PartyMember = main.party.members[0]
	var hp1 := maren.max_hp
	var atk1 := maren.attack
	check(maren.abilities.size() == 2, "level 1 should have two abilities")
	check(Talents.pending_tier("maren", 1) == -1, "no talent at level 1")
	Progression.award(Progression.THRESHOLDS[3])      # level 4
	check(maren.max_hp == hp1 + 3 * Talents.GROWTH.maren.max_hp, "growth not applied: %s -> %s" % [hp1, maren.max_hp])
	check(maren.hp == maren.max_hp, "a healthy member should stay at full health after levelling")
	check(Talents.pending_tier("maren", 4) == 0, "tier 1 should be open first")
	check(not Talents.choose("maren", 1, "riposte"), "could pick tier 2 before tier 1")
	check(Talents.choose("maren", 0, "duelist"), "couldn't pick Duelist")
	check(not Talents.choose("maren", 0, "scouts_legs"), "picked both talents of a tier")
	maren.recompute_stats()
	check(is_equal_approx(maren.attack, atk1 + 3 * Talents.GROWTH.maren.attack + 2.0), "Duelist/growth attack wrong: %s" % maren.attack)
	check(Talents.choose("maren", 1, "bleeding_cuts"), "couldn't pick Bleeding Cuts")
	maren.recompute_stats()
	check(maren.on_hit_status.get("id", "") == "bleed", "Bleeding Cuts should add bleed on hit")
	check(maren.abilities.size() == 2, "third ability too early")
	Progression.award(Progression.THRESHOLDS[4] - GameState.xp)   # level 5
	check(maren.abilities.size() == 3 and maren.abilities[2] == "cleave", "Cleave should unlock at 5")
	check(main.party.members[1].abilities.has("sanctuary") and main.party.members[2].abilities.has("volley"), "third abilities missing")
	Progression.award(Progression.THRESHOLDS[5] - GameState.xp)   # level 6
	Talents.choose("maren", 2, "hamstring_mastery")
	maren.recompute_stats()
	check(is_equal_approx(Abilities.effective(maren, "hamstring").cd, Abilities.get_def("hamstring").cd * 0.6), "ability cooldown modifier ignored")
	check(Abilities.effective(main.party.members[1], "hamstring") == Abilities.get_def("hamstring"), "modifiers leaked to another member")
	main.queue_free()
	await tree.process_frame
	GameState.reset()

func test_area_abilities() -> void:
	GameState.reset()
	var main: Node = await _boot(["maren", "oswin"])
	Progression.award(Progression.THRESHOLDS[4])
	var maren: PartyMember = main.party.members[0]
	var oswin: PartyMember = main.party.members[1]
	var foe: Creature = main.spawn_creature("risen", main.party.free_near(maren.cell + Vector2i(1, 0), {}))
	foe.place_at(maren.cell + Vector2i(1, 0))
	var before := foe.hp
	maren._cast("cleave", maren, maren.cell)
	check(foe.hp < before, "Cleave didn't hurt an adjacent foe")
	maren.hp = 10.0
	oswin.place_at(maren.cell + Vector2i(0, 1))
	oswin._cast("sanctuary", oswin, oswin.cell)
	check(maren.hp > 10.0, "Sanctuary didn't heal a nearby ally")
	main.queue_free()
	await tree.process_frame
	GameState.reset()

func test_riposte_only_against_adjacent() -> void:
	GameState.reset()
	var main: Node = await _boot(["maren"])
	var maren: PartyMember = main.party.members[0]
	maren.riposte = 1.0
	var far: Creature = main.spawn_creature("crossbow", maren.cell + Vector2i(5, 0))
	var hp_far := far.hp
	maren._on_damaged(far)
	check(far.hp == hp_far, "riposte hit a distant attacker")
	var near: Creature = main.spawn_creature("risen", maren.cell + Vector2i(1, 0))
	near.place_at(maren.cell + Vector2i(1, 0))
	near.evasion = 0.0
	var hp_near := near.hp
	maren._on_damaged(near)
	check(near.hp < hp_near, "riposte didn't strike an adjacent attacker")
	main.queue_free()
	await tree.process_frame
	GameState.reset()

func test_regional_rank_and_scaling() -> void:
	var w := WorldGen.new(4242)
	var s := w.spawn_cell()
	check(Encounters.rank_at(w, s) == 0, "the start should be rank 0")
	check(Encounters.rank_at(w, s + Vector2i(200, 0)) == 3, "far away should be rank 3")
	var ranks := {}
	for cy in WorldGen.WORLD_CHUNKS:
		for cx in WorldGen.WORLD_CHUNKS:
			for camp in Encounters.camps_for_chunk(w, Vector2i(cx, cy)):
				ranks[camp.rank] = true
				check(camp.rank == Encounters.rank_at(w, camp.cells[0]) or absi(camp.rank - Encounters.rank_at(w, camp.cells[0])) <= 1, "camp rank off")
	check(ranks.size() >= 3, "expected camps of several ranks, got %s" % [ranks.keys()])
	var a := Creature.new()
	a.world = w
	a.setup("risen", Vector2i(10, 10), 0)
	var b := Creature.new()
	b.world = w
	b.setup("risen", Vector2i(10, 10), 2)
	check(b.max_hp > a.max_hp and b.attack > a.attack and b.defense > a.defense, "rank didn't toughen the creature")
	check(b.display_name.begins_with("Dread ") and b.level() == 7, "rank 2 should be a Lv 7 'Dread' creature")
	for n in [a, b]:
		n.free()

func test_xp_script_effect_and_quest_rewards() -> void:
	GameState.reset()
	ScriptOps.run("xp:50")
	check(GameState.xp == 50, "xp:n effect didn't award XP")
	var q := QuestDefs.build("mq_dust", WorldGen.new(4242))
	check(q.get("reward", []).any(func(e): return String(e).begins_with("xp:")), "story quest has no XP reward")
	GameState.reset()

func test_xp_and_talents_survive_saving() -> void:
	GameState.reset()
	GameState.xp = 700
	GameState.talents = {"maren": ["duelist"]}
	var d: Dictionary = JSON.parse_string(JSON.stringify(GameState.to_dict([])))
	GameState.reset()
	GameState.load_dict(d)
	check(GameState.xp == 700 and Progression.level() == 5, "XP lost in save")
	check(GameState.talents.get("maren", []) == ["duelist"], "talents lost in save: %s" % [GameState.talents])
	GameState.reset()

func test_late_recruit_joins_at_company_level() -> void:
	GameState.reset()
	GameState.xp = Progression.THRESHOLDS[4]     # level 5
	var main: Node = await _boot(["maren"])
	var ketta: PartyMember = main.add_member("ketta", main.party.free_near(main.party.members[0].cell, {}))
	var base: float = Companions.DEFS.ketta.stats.max_hp
	check(ketta.max_hp == base + 4 * Talents.GROWTH.ketta.max_hp, "late recruit not at company level: %s" % ketta.max_hp)
	check(ketta.hp == ketta.max_hp and ketta.abilities.has("volley"), "late recruit missing health or Volley")
	main.queue_free()
	await tree.process_frame
	GameState.reset()
