extends SceneTree
## Every character and creature lined up on open ground: OUT_DIR=/tmp godot --path . -s res://tests/screenshot_lineup.gd
func _initialize():
	await process_frame
	var out: String = OS.get_environment("OUT_DIR")
	var gs = root.get_node("GameState")
	gs.reset()
	gs.recruited = ["maren", "oswin", "ketta"]
	root.get_node("TimeOfDay").time = 0.5
	var main = load("res://main.tscn").instantiate()
	main.spawn_encounters = false
	root.add_child(main)
	current_scene = main
	root.get_node("TacticalPause").settings.on_enemy_spotted = false
	for k in 20: await process_frame
	# Screen-horizontal rows run along (+1,-1); rows are stacked along (+3,+3).
	var w = main.world
	var origin = main.party.members[0].cell
	var spot = origin
	var found = false
	for r in range(0, 80):
		for dx in range(-r, r + 1):
			var c = origin + Vector2i(dx, r)
			var ok = true
			for k in range(-1, 9):
				for d in range(-2, 9):
					var n = c + Vector2i(k + d, -k + d)
					if not w.walkable(n) or w.has_tree(n) or not w.structure_at(n).is_empty():
						ok = false
			if ok:
				spot = c
				found = true
				break
		if found:
			break
	var types = ["risen", "revenant", "barrow_lord", "ghoul", "wight", "hound", "lurker", "boar", "crows", "bandit", "crossbow", "cultist", "ash_knight"]
	var all = []
	for i in main.party.members.size():
		var m = main.party.members[i]
		m.place_at(spot + Vector2i(i + 2, -(i + 2)))
		all.append(m)
	for i in types.size():
		var row = 1 + i / 7
		var k = i % 7
		var cr = main.spawn_creature(types[i], spot + Vector2i(k, -k) + Vector2i(3, 3) * row)
		cr.set_process(false)
		all.append(cr)
	for m in main.party.members:
		m.set_process(false)
	main.camera.position = main.ground.map_to_local(spot + Vector2i(3, -3) + Vector2i(3, 3)) + Vector2(0, -40)
	main.camera.position_smoothing_enabled = false
	main.camera.zoom = Vector2(0.85, 0.85)
	for a in all:
		a.face_vec = Vector2(0.2, 1)
		a.sprite.face(a.face_vec)
		a.sprite.play("idle", true)
	for k in 20: await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + "/lineup_idle.png")
	for a in all:
		a.sprite.play("attack", true)
	await create_timer(0.25).timeout
	root.get_viewport().get_texture().get_image().save_png(out + "/lineup_attack.png")
	for a in all:
		a.sprite.play("walk", true)
		a.sprite.face(Vector2(1, 0.4))
	await create_timer(0.3).timeout
	root.get_viewport().get_texture().get_image().save_png(out + "/lineup_walk.png")
	print("done")
	quit()
