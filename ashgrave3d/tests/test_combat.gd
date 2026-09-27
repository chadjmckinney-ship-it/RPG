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
