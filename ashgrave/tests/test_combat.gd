extends TestCase
## Combat rules and scripted skirmishes against the real main scene.

func _boot() -> Node:
	GameState.recruited = ["maren", "oswin", "ketta"]
	var main: Node = load("res://main.tscn").instantiate()
	main.spawn_encounters = false
	tree.root.add_child(main)
	await tree.process_frame
	TacticalPause.settings.on_enemy_spotted = false
	TacticalPause.settings.on_low_health = false
	TacticalPause.set_paused(false)
	return main

func _teardown(main: Node) -> void:
	TacticalPause.set_paused(false)
	TacticalPause.settings.on_enemy_spotted = true
	TacticalPause.settings.on_low_health = true
	main.queue_free()
	await tree.process_frame

func _wait(seconds: float) -> void:
	await tree.create_timer(seconds).timeout

## Open cells a few steps from the leader, for placing monsters.
func _open_cells_near(main: Node, center: Vector2i, dist: int, n: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for r in range(dist, dist + 8):
		for dx in range(-r, r + 1):
			for dy in [-r, r]:
				var c: Vector2i = center + Vector2i(dx, dy)
				if out.size() < n and main.world.walkable(c) and not main.world.has_tree(c) and not out.has(c) \
						and not main.pathfinder.find_path(center, c).is_empty():
					out.append(c)
	return out

func test_damage_math() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var a := Actor.new()
	a.attack = 12.0
	var soft := Actor.new()
	soft.defense = 2.0
	var hard := Actor.new()
	hard.defense = 15.0
	var sum_soft := 0.0
	var sum_hard := 0.0
	for i in 500:
		var d1: Dictionary = Effect.damage(a, soft, 1.0, rng)
		var d2: Dictionary = Effect.damage(a, hard, 1.0, rng)
		check(d1.amount >= 1.0 and d2.amount >= 1.0, "damage below 1")
		check(d1.amount <= 12.0 * 1.25 * 1.1 * Effect.CRIT_MULT + 1, "damage above ceiling: %s" % d1.amount)
		sum_soft += d1.amount
		sum_hard += d2.amount
	check(sum_soft > sum_hard * 1.5, "defense barely matters (%d vs %d)" % [sum_soft, sum_hard])
	var weak := Actor.new()
	weak.attack = 1.0
	check(Effect.damage(weak, hard, 1.0, rng).amount >= 1.0, "minimum damage not enforced")
	for x in [a, soft, hard, weak]:
		x.free()

func test_statuses_freeze_while_paused() -> void:
	var main: Node = await _boot()
	var m: PartyMember = main.party.members[1]
	m.add_status({"id": "poison", "time": 5.0, "dps": 4.0})
	TacticalPause.set_paused(true)
	var hp: float = m.hp
	await _wait(1.5)
	check(m.hp == hp, "poison ticked while paused")
	check(m.statuses.has("poison") and m.statuses.poison.time == 5.0, "status timer ran while paused")
	TacticalPause.set_paused(false)
	await _wait(1.3)
	check(m.hp < hp, "poison did not tick once unpaused")
	await _teardown(main)

func test_queued_orders_run_in_sequence() -> void:
	var main: Node = await _boot()
	var m: PartyMember = main.party.members[0]
	var spots := _open_cells_near(main, m.cell, 5, 2)
	check(spots.size() == 2, "no open cells for waypoints")
	m.issue({"type": "move", "cell": spots[0]})
	m.issue({"type": "move", "cell": spots[1]}, true)
	check(m.orders.size() + (1 if m.current != null else 0) == 2, "second order didn't queue")
	var visited_first := false
	for i in 200:
		await _wait(0.05)
		if m.cell == spots[0]:
			visited_first = true
		if m.current == null and m.orders.is_empty():
			break
	check(visited_first, "never reached the first waypoint")
	check(m.cell == spots[1], "ended at %s, wanted %s" % [m.cell, spots[1]])
	await _teardown(main)

func test_ability_gating() -> void:
	var main: Node = await _boot()
	var oswin: PartyMember = main.party.members[1]
	check(oswin.can_use("shield_wall"), "fresh ability should be usable")
	check(oswin.use_ability("shield_wall"), "shield wall failed to start")
	await _wait(0.2)
	check(oswin.statuses.has("guard"), "shield wall didn't apply guard")
	check(not oswin.can_use("shield_wall"), "ability usable during cooldown")
	oswin.stamina = 0.0
	check(not oswin.can_use("mending"), "ability usable without stamina")
	check(not oswin.can_use("not_a_skill"), "unknown ability usable")
	# guard halves damage
	var hp := oswin.hp
	oswin.take_damage(20.0)
	check(is_equal_approx(hp - oswin.hp, 10.0), "guard reduced 20 to %s" % (hp - oswin.hp))
	await _teardown(main)

func test_skirmish_party_beats_two_hounds() -> void:
	var main: Node = await _boot()
	var lead: PartyMember = main.party.members[0]
	var cells := _open_cells_near(main, lead.cell, 4, 2)
	var hounds: Array = []
	for c in cells:
		hounds.append(main.spawn_creature("hound", c))
	check(hounds.size() == 2, "couldn't place hounds")
	main.party.select(main.party.members.duplicate())
	main.party.order_attack(hounds[0])
	for i in 300:
		await _wait(0.1)
		if hounds.all(func(h): return not is_instance_valid(h) or h.downed):
			break
	check(hounds.all(func(h): return not is_instance_valid(h) or h.downed), "hounds still standing after 30s")
	check(main.party.members.any(func(m): return m.alive()), "whole party fell to two hounds")
	check(main.combat_log.lines.any(func(l): return "slain" in l), "no kill in the combat log")
	await _teardown(main)

func test_nothing_happens_while_paused() -> void:
	var main: Node = await _boot()
	var lead: PartyMember = main.party.members[0]
	var h: Creature = main.spawn_creature("hound", _open_cells_near(main, lead.cell, 1, 1)[0])
	TacticalPause.set_paused(true)
	main.party.select(main.party.members.duplicate())
	main.party.order_attack(h)
	var before: Array = main.party.members.map(func(m): return m.hp)
	await _wait(1.5)
	check(h.hp == h.max_hp, "hound took damage while paused")
	check(main.party.members.map(func(m): return m.hp) == before, "party took damage while paused")
	await _teardown(main)

func test_creature_leashes_home() -> void:
	var main: Node = await _boot()
	var lead: PartyMember = main.party.members[0]
	var home: Vector2i = _open_cells_near(main, lead.cell, 3, 1)[0]
	var far: Array[Vector2i] = _open_cells_near(main, home, 16, 1)
	check(not far.is_empty(), "no far cell to test leash")
	# Move the party well away so nothing re-aggroes.
	var r: Creature = main.spawn_creature("risen", home)
	for m in main.party.members:
		m.downed = true
	r.place_at(far[0])
	for i in 300:
		await _wait(0.1)
		if r.cell_distance(home) <= 1.5 and not r.returning:
			break
	check(r.cell_distance(home) <= 1.5, "creature stayed %0.1f cells from home" % r.cell_distance(home))
	await _teardown(main)

func test_encounters_deterministic_and_valid() -> void:
	var w := WorldGen.new(1337)
	var spawn := w.spawn_cell()
	var total := 0
	for cx in range(4, 12):
		for cy in range(4, 12):
			var ch := Vector2i(cx, cy)
			var a := Encounters.camps_for_chunk(w, ch)
			var b := Encounters.camps_for_chunk(w, ch)
			check(str(a) == str(b), "camps differ between calls for %s" % ch)
			for camp in a:
				for c in camp.cells:
					total += 1
					check(w.walkable(c) and not w.has_tree(c), "camp creature on blocked cell %s" % c)
					check(Vector2(c - spawn).length() >= Encounters.SAFE_RADIUS, "camp too close to spawn at %s" % c)
	check(total > 20, "world is nearly empty of creatures (%d)" % total)
