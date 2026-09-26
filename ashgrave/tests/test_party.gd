extends TestCase
## Boots the real main scene and drives the party.

func test_main_scene_boots_and_moves_party() -> void:
	var main: Node = load("res://main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	check(main.party.members.size() == 3, "expected 3 party members")
	check(main.streamer.loaded.size() >= 9, "chunks not loaded around spawn: %d" % main.streamer.loaded.size())
	var ground: TileMapLayer = main.ground
	var lead: PartyMember = main.party.members[0]
	check(ground.get_cell_source_id(lead.cell) != -1, "no ground tile under the leader")

	main.party.select(main.party.members.duplicate())
	# Pick a destination ~10 steps away that is open on all sides (room for the formation).
	var target := lead.cell
	var p: Array[Vector2i] = []
	for dx in range(-14, 15):
		for dy in range(-14, 15):
			var c: Vector2i = lead.cell + Vector2i(dx, dy)
			if absi(dx) + absi(dy) < 8:
				continue
			var open := true
			for ox in range(-2, 3):
				for oy in range(-2, 3):
					var n := c + Vector2i(ox, oy)
					if not main.world.walkable(n) or main.world.has_tree(n):
						open = false
			if open:
				p = main.pathfinder.find_path(lead.cell, c)
				if not p.is_empty():
					target = c
					break
		if target != lead.cell:
			break
	check(target != lead.cell, "no open reachable destination near spawn")
	var n: int = main.party.order_move_to(target)
	check(n == 3, "only %d of 3 members got a path" % n)

	# Tactical pause freezes movement.
	TacticalPause.set_paused(true)
	var before := lead.position
	var t0 := TimeOfDay.time
	for i in 10:
		await tree.process_frame
	check(lead.position == before, "leader moved while paused")
	check(TimeOfDay.time == t0, "clock advanced while paused")
	TacticalPause.set_paused(false)

	for i in 300:
		await tree.create_timer(0.1).timeout
		if not main.party.members.any(func(m): return m.is_moving()):
			break
	check(lead.cell == target, "leader ended at %s, wanted %s" % [lead.cell, target])
	var cells := {}
	for m in main.party.members:
		cells[m.cell] = true
	check(cells.size() == 3, "party members stacked on the same cell")
	main.queue_free()
	await tree.process_frame
