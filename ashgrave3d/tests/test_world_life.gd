extends TestCase
## N3: villages and story NPCs stream with chunks, talking opens dialogue, panels build,
## story spawns, live portraits, the title screen, and loading a save into a fresh scene.

func _boot(recruited := ["maren"]) -> Node:
	GameState.reset()
	GameState.recruited = recruited
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

func _find_npc(main: Node, id: String) -> Villager:
	for a in main.actors:
		if is_instance_valid(a) and a is Villager and a.npc_id == id:
			return a
	return null

## Load the start village's chunk (it may be outside the streaming radius of the spawn).
func _load_start_village(main: Node) -> Dictionary:
	var v := Story.village(main.world, Story.setup(main.world).start)
	var ch: Vector2i = main.terrain.chunk_of(v.center)
	if not main.terrain.loaded.has(ch):
		main.terrain.load_chunk(ch)
	return v

func test_village_folk_stream_with_chunks() -> void:
	var main: Node = await _boot()
	var v := _load_start_village(main)
	var maud := _find_npc(main, "maud")
	check(maud != null and maud.display_name == "Warden Maud", "Warden Maud not in the start village")
	check(_find_npc(main, "oswin") != null, "Brother Oswin (unrecruited) missing")
	check(_find_npc(main, "%s:smith" % v.id) != null, "no smith")
	var folk: Array = main.actors.filter(func(a): return is_instance_valid(a) and a is Villager and a.village.get("id") == v.id)
	check(folk.size() == 6, "expected 4 villagers + 2 story NPCs, got %d" % folk.size())
	check(maud.body != null and maud.body.id == "maud", "story NPC should use its own model id")
	var ch: Vector2i = main.terrain.chunk_of(v.center)
	main.terrain.set_process(false)      # or streaming would load the chunk straight back
	main.terrain.unload_chunk(ch)
	await tree.process_frame
	await tree.process_frame
	check(not is_instance_valid(maud) and _find_npc(main, "maud") == null, "villagers not removed with their chunk")
	await _teardown(main)

func test_talking_opens_dialogue_and_trade() -> void:
	var main: Node = await _boot()
	var v := _load_start_village(main)
	var maud := _find_npc(main, "maud")
	maud.on_interact(main.party.leader())
	check(main.panels.mode == "dialogue" and TacticalPause.paused, "talking didn't open a pausing dialogue")
	check(main.panels.content.get_child_count() > 2, "dialogue has no choices")
	main.panels.close_all()
	check(not TacticalPause.paused, "closing didn't restore the pause state")
	var smith := _find_npc(main, "%s:smith" % v.id)
	main.panels.open_trade(smith)
	await tree.process_frame
	check(main.panels.mode == "trade" and main.panels.title.text.begins_with(smith.display_name), "trade screen didn't open")
	await _teardown(main)

func test_every_panel_builds() -> void:
	var main: Node = await _boot(["maren", "oswin", "ketta"])
	var p: Panels = main.panels
	for t in ["pack", "company", "gear", "craft", "quests", "factions"]:
		p.tab = t
		p._open("pack")
		await tree.process_frame
		check(p.content.get_child_count() > 0, "tab %s is empty" % t)
	for m in ["menu", "settings", "map"]:
		p._open(m)
		await tree.process_frame
		check(p.content.get_child_count() > 0, "%s is empty" % m)
	p.show_note("A note.")
	check(p.mode == "note", "note didn't open")
	await _teardown(main)

func test_story_spawns_bosses() -> void:
	var main: Node = await _boot()
	Events.story_effect.emit("spawn:barrow")
	var lord: Creature = null
	for a in main.actors:
		if is_instance_valid(a) and a is Creature and a.camp_id == "story:barrow" and a.type_id == "barrow_lord":
			lord = a
	check(lord != null and lord.rank == main.BOSS_RANK.barrow, "the Drowned Lord didn't rise at rank %d" % main.BOSS_RANK.barrow)
	var count: int = main.actors.filter(func(a): return is_instance_valid(a) and a is Creature and a.camp_id == "story:barrow").size()
	Events.story_effect.emit("spawn:barrow")
	var again: int = main.actors.filter(func(a): return is_instance_valid(a) and a is Creature and a.camp_id == "story:barrow").size()
	check(again == count, "barrow spawned twice")
	await _teardown(main)

func test_recruit_moves_villager_into_party() -> void:
	var main: Node = await _boot()
	_load_start_village(main)
	Events.story_effect.emit("recruit:oswin")
	await tree.process_frame
	check(main.party.members.size() == 2 and main.party.members[1].companion_id == "oswin", "Oswin didn't join")
	check(_find_npc(main, "oswin") == null, "Oswin still stands in the village")
	await _teardown(main)

func test_live_portraits() -> void:
	var main: Node = await _boot()
	var maren: PartyMember = main.party.members[0]
	var tex: Texture2D = main.portraits.texture_for(maren)
	check(tex is ViewportTexture, "portrait isn't a viewport texture")
	check(tex == main.portraits.texture_for(maren), "portraits should be cached per model")
	var vp: SubViewport = main.portraits.get_child(0)
	check(vp.own_world_3d and vp.size == Vector2i(Portraits3D.SIZE, Portraits3D.SIZE), "portrait viewport misconfigured")
	check(vp.find_children("*", "CharacterModel", true, false).size() == 1, "portrait has no model")
	var cam: Camera3D = vp.find_children("*", "Camera3D", true, false)[0]
	check(cam.global_position.y > 1.3 and cam.global_position.z < 0.0, "portrait camera should be at head height, in front")
	await _teardown(main)

func test_title_screen_builds_backdrop() -> void:
	var title: Node = load("res://title.tscn").instantiate()
	tree.root.add_child(title)
	await tree.process_frame
	check(title.terrain != null and title.terrain.loaded.size() > 0, "no terrain behind the title")
	check(title.hero != null and title.hero.id == "maren", "Maren missing from the title")
	var first: Vector3 = title.cam.global_position
	for i in 5:
		await tree.process_frame
	check(title.cam.global_position != first, "camera should orbit")
	title.seed_edit.text = "4242"
	title._refresh_preview()
	check(title.preview.seed_value == 4242, "seed box not applied")
	title.queue_free()
	await tree.process_frame

func test_loading_a_save_into_a_new_scene() -> void:
	var main: Node = await _boot(["maren", "oswin"])
	var lead: PartyMember = main.party.members[0]
	var target: Vector2i = main.party.free_near(lead.cell + Vector2i(3, 2), {})
	lead.place_at(target)
	GameState.xp = 300
	var data: Dictionary = JSON.parse_string(JSON.stringify(GameState.to_dict(main.party_state())))
	await _teardown(main)
	GameState.pending_load = data
	var fresh: Node = load("res://main.tscn").instantiate()
	fresh.spawn_encounters = false
	tree.root.add_child(fresh)
	await tree.process_frame
	check(fresh.party.members.size() == 2, "recruits not restored")
	check(fresh.party.members[0].cell == target, "leader not placed where saved: %s vs %s" % [fresh.party.members[0].cell, target])
	check(GameState.xp == 300 and GameState.pending_load.is_empty(), "save not applied")
	await _teardown(fresh)

func test_village_folk_keep_apart() -> void:
	var main: Node = await _boot()
	var v := _load_start_village(main)
	var folk: Array = main.actors.filter(func(a): return is_instance_valid(a) and a is Villager and a.village.get("id") == v.id)
	check(folk.size() >= 4, "too few villagers to test spacing")
	# evening too: everyone heads for the tavern, the likeliest place to pile up
	for hour_time in [0.45, 0.8]:
		TimeOfDay.time = hour_time
		for f in folk:
			f._think = 0.0
			f._idle(0.1)
		for i in folk.size():
			for j in range(i + 1, folk.size()):
				var a: Vector2i = folk[i].spot
				var b: Vector2i = folk[j].spot
				check(maxi(absi(a.x - b.x), absi(a.y - b.y)) >= Villager.SPACING,
					"%s and %s both stand near %s at time %.2f" % [folk[i].display_name, folk[j].display_name, a, hour_time])
	await _teardown(main)

func test_talked_to_folk_face_the_speaker() -> void:
	var main: Node = await _boot()
	_load_start_village(main)
	var maud := _find_npc(main, "maud")
	var lead: PartyMember = main.party.leader()
	lead.place_at(main.party.free_near(maud.cell + Vector2i(2, -1), {}))
	maud.issue({"type": "move", "cell": maud.cell + Vector2i(3, 3)})
	maud.on_interact(lead)
	var d: Vector3 = lead.global_position - maud.global_position
	var want := atan2(-d.x, -d.z)
	check(absf(angle_difference(maud.body.rotation.y, want)) < 0.05, "Maud didn't turn to the speaker")
	check(maud.current == null and maud.orders.is_empty(), "Maud kept walking while spoken to")
	main.panels.close_all()
	for i in 20:
		maud._update_body()
	check(absf(angle_difference(maud.body.rotation.y, want)) < 0.05, "Maud turned away while the speaker is still there")
	lead.place_at(main.party.free_near(maud.cell + Vector2i(9, 0), {}))
	for i in 30:
		maud._update_body()
	var rest := atan2(-Actor.REST_FACING.x, -Actor.REST_FACING.z)
	check(absf(angle_difference(maud.body.rotation.y, rest)) < 0.05, "Maud should face the camera again once the speaker leaves")
	await _teardown(main)

func test_party_keeps_off_villagers() -> void:
	var main: Node = await _boot(["maren", "oswin"])
	_load_start_village(main)
	var maud := _find_npc(main, "maud")
	var party: PartyController = main.party
	party.select(party.members.duplicate())
	main.pathfinder.ensure_covers(maud.cell)
	var dest := party.free_near(maud.cell, {})
	check(dest != maud.cell and dest != maud.spot, "a move onto Maud ends on her cell")
	party.order_move_to(maud.cell)
	for m in party.members:
		var end: Vector2i = m.path[m.path.size() - 1] if not m.path.is_empty() else m.cell
		for a in main.actors:
			if is_instance_valid(a) and a is Villager:
				check(end != a.cell and end != a.spot, "%s heads for %s's cell" % [m.display_name, a.display_name])
	# a villager choosing a new spot won't pick a party member's cell
	var oswin: PartyMember = party.members[1]
	var want: Vector2i = maud.spot + Vector2i(0, 6)
	oswin.place_at(want)
	var got := maud.claim_spot(want)
	check(got != oswin.cell, "Maud picked the cell Oswin stands on")
	await _teardown(main)

## An open row of cells near c: 7 in a line along +x, all walkable and treeless, with a free row on each side.
func _open_row(main: Node, c: Vector2i) -> Vector2i:
	for r in range(0, 120):
		var c0 := c + Vector2i(r, r / 2)
		var ok := true
		for dx in range(-1, 8):
			for dy in range(-2, 3):
				var n := c0 + Vector2i(dx, dy)
				if not main.world.walkable(n) or main.world.has_tree(n):
					ok = false
		if ok:
			return c0
	return c

func test_people_walk_around_each_other() -> void:
	var main: Node = await _boot(["maren", "oswin"])
	var maren: PartyMember = main.party.members[0]
	var oswin: PartyMember = main.party.members[1]
	var row := _open_row(main, maren.cell)
	main.pathfinder.ensure_covers(row)
	oswin.place_at(row + Vector2i(3, 0))          # standing in the middle of the way
	maren.place_at(row)
	maren.order_move(main.pathfinder.find_path(row, row + Vector2i(6, 0)))
	var stepped_on := false
	for i in 400:
		maren._process(0.05)
		if maren.cell == oswin.cell:
			stepped_on = true
		if maren.path.is_empty():
			break
	check(not stepped_on, "Maren walked through Oswin")
	check(maren.cell == row + Vector2i(6, 0), "Maren didn't reach the far end (at %s)" % maren.cell)
	# a goal someone is standing on: stop next to them instead
	maren.place_at(row)
	maren.order_move(main.pathfinder.find_path(row, oswin.cell))
	for i in 400:
		maren._process(0.05)
		if maren.path.is_empty():
			break
	check(maren.cell != oswin.cell and maren.cell_distance(oswin.cell) < 2.0, "Maren should stop beside Oswin, not on him (at %s)" % maren.cell)
	await _teardown(main)
