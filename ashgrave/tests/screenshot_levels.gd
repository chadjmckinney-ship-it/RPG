extends SceneTree
## Leveling screenshots: OUT_DIR=/tmp godot --path . -s res://tests/screenshot_levels.gd
## HUD XP bar and talent marker, a level-up, the Company tab, and ranked enemies.
func _initialize():
	await process_frame
	var out: String = OS.get_environment("OUT_DIR")
	var gs = root.get_node("GameState")
	gs.reset()
	gs.recruited = ["maren", "oswin", "ketta"]
	gs.xp = 400
	root.get_node("TimeOfDay").time = 0.5
	var main = load("res://main.tscn").instantiate()
	main.spawn_encounters = false
	root.add_child(main)
	current_scene = main
	root.get_node("TacticalPause").settings.on_enemy_spotted = false
	for k in 30: await process_frame
	var lead = main.party.members[0]
	var P = load("res://systems/progression.gd")
	P.award(40, "")   # -> level 4, with talents to pick
	for k in 10: await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + "/lv_levelup.png")
	main.panels.tab = "company"
	main.panels.toggle_pack()
	for k in 10: await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + "/lv_company.png")
	main.panels.close_all()
	var ranks = [0, 1, 2, 3]
	var types = ["risen", "risen", "ghoul", "boar"]
	var spot = main.world.spawn_cell() + Vector2i(0, 4)
	for i in 4:
		var c = main.party._free_near(spot + Vector2i(i * 2, -i * 2), {})
		var cr = main.spawn_creature(types[i], c, "", ranks[i])
		cr.set_process(false)
		print(cr.display_name, " Lv ", cr.level(), " hp ", cr.max_hp)
	for m in main.party.members:
		m.set_process(false)
	main.camera.zoom = Vector2(1.1, 1.1)
	main.camera.position = main.ground.map_to_local(spot + Vector2i(3, -3))
	main.camera.position_smoothing_enabled = false
	for k in 20: await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + "/lv_ranks.png")
	print("done")
	quit()
