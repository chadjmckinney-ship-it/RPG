extends SceneTree
## Dialogue, quest log, tracker and barrow screenshots: OUT_DIR=/tmp godot --path . -s res://tests/screenshot_quests.gd
func _initialize():
	await process_frame
	var out: String = OS.get_environment("OUT_DIR")
	var gs = root.get_node("GameState")
	gs.reset()
	root.get_node("TimeOfDay").time = 0.55
	var main = load("res://main.tscn").instantiate()
	main.spawn_encounters = false
	root.add_child(main)
	current_scene = main
	for k in 30: await process_frame
	var maud = null
	for a in main.actors:
		if a.get("npc_id") == "maud": maud = a
	main.panels.open_dialogue(maud)
	main.panels._pick(0)
	for k in 10: await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + "/ash_dialogue.png")
	print("shot dialogue")
	main.panels._pick(0)
	for k in 10: await process_frame
	gs.inventory.add("grave-dust", 3)
	main.panels.open_quests()
	for k in 10: await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + "/ash_questlog.png")
	print("shot questlog")
	main.panels.close_all()
	for k in 30: await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + "/ash_tracker.png")
	print("shot tracker")
	# jump to the barrow
	var barrow = root.get_node("GameState").world
	var at = load("res://systems/story.gd").setup(main.world).barrow
	var lead = main.party.members[0]
	main.pathfinder.ensure_covers(at)
	lead.place_at(main.party._free_near(at + Vector2i(4, 4), {}))
	main.streamer.focus_cell = at
	main.streamer.load_all_now()
	main._spawn_barrow()
	root.get_node("TimeOfDay").time = 0.9
	for k in 40: await process_frame
	root.get_node("TacticalPause").set_paused(true)
	for k in 5: await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + "/ash_barrow.png")
	print("shot barrow")
	quit()
