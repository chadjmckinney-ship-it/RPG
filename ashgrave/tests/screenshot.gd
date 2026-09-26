extends SceneTree
func _initialize():
	await process_frame
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	root.get_node("TimeOfDay").time = float(OS.get_environment("TOD")) if OS.get_environment("TOD") != "" else 0.45
	for i in 40: await process_frame
	main.party.select(main.party.members.duplicate())
	for i in 20: await process_frame
	root.get_viewport().get_texture().get_image().save_png(OS.get_environment("OUT"))
	quit()
