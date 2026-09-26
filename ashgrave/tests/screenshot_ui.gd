extends SceneTree
## Title, HUD, dialogue and map screenshots: OUT_DIR=/tmp godot --path . -s res://tests/screenshot_ui.gd
func _shot(name: String) -> void:
	for k in 8: await process_frame
	root.get_viewport().get_texture().get_image().save_png(OS.get_environment("OUT_DIR") + "/" + name + ".png")
	print("shot ", name)

func _initialize():
	await process_frame
	var gs = root.get_node("GameState")
	var title = load("res://title.tscn").instantiate()
	root.add_child(title)
	current_scene = title
	title.seed_edit.text = "1337"
	title._refresh_preview()
	await _shot("ui_title")
	title.queue_free()
	gs.reset()
	gs.recruited = ["maren", "oswin", "ketta"]
	root.get_node("TimeOfDay").time = 0.6
	var main = load("res://main.tscn").instantiate()
	main.spawn_encounters = false
	root.add_child(main)
	current_scene = main
	for k in 30: await process_frame
	main.party.select(main.party.members.duplicate())
	gs.quests = {}
	load("res://systems/quest_log.gd").start("mq_restless")
	await _shot("ui_hud")
	var maud = null
	for a in main.actors:
		if a.get("npc_id") == "maud": maud = a
	main.panels.open_dialogue(maud)
	await _shot("ui_dialogue")
	main.panels.close_all()
	main.panels.open_map()
	await _shot("ui_map")
	quit()
