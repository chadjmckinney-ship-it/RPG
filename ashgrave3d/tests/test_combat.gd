extends TestCase
## N2: 3D combat — strikes, statuses, riposte, area abilities, creature AI, kills and XP.

func _boot(recruited: Array) -> Node:
	GameState.reset()
	GameState.recruited = recruited
	TacticalPause.settings.on_enemy_spotted = false
	TacticalPause.settings.on_low_health = false
	var main: Node = load("res://main.tscn").instantiate()
	main.spawn_encounters = false
	tree.root.add_child(main)
	await tree.process_frame
	return main

func _done(main: Node) -> void:
	main.queue_free()
	await tree.process_frame
	GameState.reset()
	TacticalPause.settings.on_enemy_spotted = true
	TacticalPause.settings.on_low_health = true

func test_strike_damages_and_statuses_tick() -> void:
	var main: Node = await _boot(["maren"])
	var maren: PartyMember = main.party.members[0]
	var foe: Creature = main.spawn_creature("risen", main.party.free_near(maren.cell + Vector2i(1, 0), {}))
	foe.evasion = 0.0
	var hp := foe.hp
	maren._strike(foe)
	check(foe.hp < hp, "a strike did no damage")
	check(not foe.floaters.is_empty(), "no damage number")
	foe.add_status({"id": "poison", "time": 2.5, "dps": 4.0})
	var before := foe.hp
	for i in 90:
		foe._tick_statuses(1.0 / 30.0)
	check(foe.hp <= before - 8.0 + 0.01, "poison should tick twice over 3 s (%s -> %s)" % [before, foe.hp])
	check(not foe.statuses.has("poison"), "poison should expire")
	await _done(main)

func test_riposte_only_adjacent() -> void:
	var main: Node = await _boot(["maren"])
	var maren: PartyMember = main.party.members[0]
	maren.riposte = 1.0
	var far: Creature = main.spawn_creature("crossbow", main.party.free_near(maren.cell + Vector2i(5, 0), {}))
	var hp_far := far.hp
	maren._on_damaged(far)
	check(far.hp == hp_far, "riposte hit a distant attacker")
	var near: Creature = main.spawn_creature("risen", main.party.free_near(maren.cell + Vector2i(1, 0), {}))
	near.place_at(maren.cell + Vector2i(1, 0))
	near.evasion = 0.0
	var hp_near := near.hp
	maren._on_damaged(near)
	check(near.hp < hp_near, "riposte didn't strike an adjacent attacker")
	await _done(main)

func test_area_abilities() -> void:
	var main: Node = await _boot(["maren", "oswin"])
	Progression.award(Progression.THRESHOLDS[4])
	var maren: PartyMember = main.party.members[0]
	var oswin: PartyMember = main.party.members[1]
	var foe: Creature = main.spawn_creature("risen", maren.cell + Vector2i(1, 0))
	foe.place_at(maren.cell + Vector2i(1, 0))
	var before := foe.hp
	maren._cast("cleave", maren, maren.cell)
	check(foe.hp < before, "Cleave didn't hurt an adjacent foe")
	maren.hp = 10.0
	oswin.place_at(maren.cell + Vector2i(0, 1))
	oswin._cast("sanctuary", oswin, oswin.cell)
	check(maren.hp > 10.0, "Sanctuary didn't heal a nearby ally")
	await _done(main)

func test_creature_chases_then_leashes_home() -> void:
	var main: Node = await _boot(["maren"])
	var maren: PartyMember = main.party.members[0]
	var hound: Creature = main.spawn_creature("hound", main.party.free_near(maren.cell + Vector2i(4, 0), {}))
	for i in 20:
		await tree.process_frame
	check(hound.aggressive(), "hound didn't notice Maren 4 cells away")
	hound.home = hound.cell + Vector2i(40, 0)    # pretend it's far from home
	for i in 5:
		await tree.process_frame
	check(hound.returning, "hound past its leash should head home")
	await _done(main)

func test_kill_gives_xp_loot_and_clears_camp() -> void:
	var main: Node = await _boot(["maren"])
	var maren: PartyMember = main.party.members[0]
	var a: Creature = main.spawn_creature("risen", main.party.free_near(maren.cell + Vector2i(3, 0), {}), "test:camp")
	var b: Creature = main.spawn_creature("risen", main.party.free_near(maren.cell + Vector2i(3, 2), {}), "test:camp")
	var coins := GameState.inventory.count("coin")
	a.take_damage(9999, maren)
	check(GameState.xp == Progression.kill_xp("risen", 0), "kill XP not awarded")
	check(not GameState.cleared_camps.has("test:camp"), "camp cleared too early")
	b.take_damage(9999, maren)
	check(GameState.cleared_camps.has("test:camp"), "camp not cleared")
	check(GameState.inventory.count("coin") > coins, "no coin looted")
	await _done(main)

func test_camps_spawn_with_ranks() -> void:
	GameState.reset()
	var main: Node = load("res://main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	var creatures: Array = main.actors.filter(func(x): return x is Creature)
	check(not creatures.is_empty(), "no camps near the start")
	for c in creatures:
		check(c.rank == Encounters.rank_at(main.world, c.home) or absi(c.rank - Encounters.rank_at(main.world, c.home)) <= 1, "camp rank off")
	await _done(main)

func test_creatures_face_the_party_when_they_spot_it() -> void:
	var main: Node = await _boot(["maren"])
	var maren: PartyMember = main.party.members[0]
	var foe: Creature = main.spawn_creature("bandit", main.party.free_near(maren.cell + Vector2i(4, 2), {}))
	foe.snap_face(foe.global_position + Actor.rest_facing)       # looking at the camera, as when idle
	TacticalPause.settings.on_enemy_spotted = true
	foe._process(0.016)                                          # spots Maren; the game auto-pauses
	var d: Vector3 = maren.global_position - foe.global_position
	var want := atan2(-d.x, -d.z)
	check(TacticalPause.paused, "spotting should auto-pause")
	check(absf(angle_difference(foe.body.rotation.y, want)) < 0.05, "the bandit didn't turn to Maren when it spotted her")
	for i in 20:
		foe._process(0.016)                                      # paused: must not turn back to the camera
	check(absf(angle_difference(foe.body.rotation.y, want)) < 0.05, "the bandit turned away while paused")
	TacticalPause.set_paused(false)
	await _done(main)

func test_creatures_walk_around_each_other() -> void:
	var main: Node = await _boot(["maren"])
	var maren: PartyMember = main.party.members[0]
	# an open row, well away from Maren so nobody aggroes
	var row := maren.cell
	for r in range(12, 140):
		var c0 := maren.cell + Vector2i(r, r / 2)
		var ok := true
		for dx in range(-1, 8):
			for dy in range(-2, 3):
				if not main.world.walkable(c0 + Vector2i(dx, dy)) or main.world.has_tree(c0 + Vector2i(dx, dy)):
					ok = false
		if ok:
			row = c0
			break
	main.pathfinder.ensure_covers(row)
	var blocker: Creature = main.spawn_creature("risen", row + Vector2i(3, 0))
	var walker: Creature = main.spawn_creature("risen", row)
	blocker.set_process(false)
	walker.set_process(false)
	walker.order_move(main.pathfinder.find_path(row, row + Vector2i(6, 0)))
	var stepped_on := false
	for i in 400:
		walker._process(0.05)
		if walker.cell == blocker.cell:
			stepped_on = true
		if walker.path.is_empty():
			break
	check(not stepped_on, "one risen walked through the other")
	check(walker.cell == row + Vector2i(6, 0), "the risen didn't reach the far end (at %s)" % walker.cell)
	# creatures still close to melee range of the party: nobody steps around a foe
	check(not walker._avoids(maren) and not maren._avoids(walker), "creatures and the party shouldn't give way to each other")
	await _done(main)
