extends SceneTree
## Village, pack and trade screenshots + a real save/reload: OUT_DIR=/tmp godot --path . -s res://tests/screenshot_village.gd
func _initialize():
	await process_frame
	var out: String = OS.get_environment("OUT_DIR")
	var gs = root.get_node("GameState")
	root.get_node("TimeOfDay").time = 0.47
	var main = load("res://main.tscn").instantiate()
	main.spawn_encounters = false
	root.add_child(main)
	current_scene = main
	for k in 60: await process_frame
	await create_timer(1.0).timeout
	main.camera.zoom = Vector2(1.2, 1.2)
	var v = main.world.village_near(main.party.members[0].cell, 20.0)
	main.party.members[0].place_at(v.center + Vector2i(1, 1))
	for k in 60: await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + "/ash_village.png")
	print("shot ash_village")
	gs.inventory.add("iron-ore", 4); gs.inventory.add("hide", 5); gs.inventory.add("bitterroot", 6); gs.inventory.add("yew-bow")
	main.panels.tab = "craft"
	main.panels.toggle_pack()
	for k in 10: await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + "/ash_craft.png")
	print("shot ash_craft")
	main.panels.close_all()
	var smith = null
	for a in main.actors:
		if a.get("job") == "smith": smith = a
	main.panels.open_trade(smith)
	for k in 10: await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + "/ash_trade.png")
	print("shot ash_trade")
	main.panels.close_all()
	# real save -> reload scene -> check
	main.party.members[0].place_at(v.center + Vector2i(0, 2))
	print("SAVE ", main.save_game(), " at ", main.party.members[0].cell)
	gs.inventory.add("hide", 50)
	main.load_game()
	await create_timer(0.5).timeout
	var m2 = current_scene
	print("LOADED at ", m2.party.members[0].cell, " hide=", gs.inventory.count("hide"), " same_scene=", m2 == main)
	quit()
