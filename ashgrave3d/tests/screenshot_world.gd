extends SceneTree
## First look: OUT_DIR=/tmp godot --path . -s res://tests/screenshot_world.gd
func _initialize():
	await process_frame
	var out := OS.get_environment("OUT_DIR")
	var gs = root.get_node("GameState")
	gs.recruited = ["maren", "oswin", "ketta"]
	root.get_node("TimeOfDay").time = float(OS.get_environment("TOD")) if OS.get_environment("TOD") != "" else 0.42
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	current_scene = main
	for k in 30: await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + "/w_start.png")
	var party = main.party
	party.select(party.members.duplicate())
	var lead = party.members[0]
	var goal = party.free_near(lead.cell + Vector2i(8, 3), {})
	print("moved ", party.order_move_to(goal))
	await create_timer(1.2).timeout
	root.get_viewport().get_texture().get_image().save_png(out + "/w_walk.png")
	main.cam.distance = 9.0
	main.cam._place()
	await create_timer(0.4).timeout
	root.get_viewport().get_texture().get_image().save_png(out + "/w_close.png")
	main.cam.distance = 40.0
	main.cam._place()
	for k in 10: await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + "/w_far.png")
	print("done")
	quit()
