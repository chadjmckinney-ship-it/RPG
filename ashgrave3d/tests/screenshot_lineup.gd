extends SceneTree
## Every character model side by side: OUT_DIR=/tmp godot --path . -s res://tests/screenshot_lineup.gd
const IDS := ["maren", "oswin", "ketta", "maud", "harl", "smith", "ghoul", "boar", "bandit"]

func _initialize():
	await process_frame
	var out := OS.get_environment("OUT_DIR")
	root.get_node("TimeOfDay").time = 0.42
	var main = load("res://main.tscn").instantiate()
	main.spawn_encounters = false
	root.add_child(main)
	current_scene = main
	for k in 10: await process_frame
	var lead = main.party.members[0]
	lead.visible = false
	# an open stretch of ground: 12 cells wide, no trees
	var open: Vector2i = lead.cell
	for r in range(2, 160):
		var c0: Vector2i = lead.cell + Vector2i(r, r / 2)
		var ok := true
		for dx in range(-7, 8):
			for dy in range(-4, 3):
				var c := c0 + Vector2i(dx, dy)
				if not main.world.walkable(c) or main.world.has_tree(c):
					ok = false
		if ok:
			open = c0
			break
	main.terrain.focus_cell = open
	main.terrain.load_all_now()
	var base: Vector3 = main.world.cell_to_world(open)
	var models := []
	for i in IDS.size():
		var m = load("res://actors/character_model.gd").new()
		main.add_child(m)
		m.setup(IDS[i])
		var p := base + Vector3((i - 4) * 1.1, 0, 0)
		p.y = main.world.ground_y(p)
		m.position = p
		m.rotation.y = PI + 0.35  # facing the camera (+Z), turned a little
		models.append(m)
		var tag := Label3D.new()
		tag.text = IDS[i]
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.font_size = 40
		tag.pixel_size = 0.004
		tag.position = p + Vector3(0, 2.15, 0)
		main.add_child(tag)
	main.cam.follow = null
	main.cam.position = base
	main.cam.yaw = 0.0
	main.cam.distance = 11.0
	main.cam._place()
	await create_timer(1.0).timeout
	root.get_viewport().get_texture().get_image().save_png(out + "/l_lineup.png")
	for m in models:
		m.play("walk")
		m.move_speed = 1.4
	await create_timer(0.5).timeout
	root.get_viewport().get_texture().get_image().save_png(out + "/l_walk.png")
	for m in models:
		m.play("attack")
	await create_timer(0.35).timeout
	root.get_viewport().get_texture().get_image().save_png(out + "/l_attack.png")
	quit()
