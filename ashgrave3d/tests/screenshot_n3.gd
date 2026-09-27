extends SceneTree
## N3 look: OUT_DIR=/tmp godot --path . -s res://tests/screenshot_n3.gd
var out := ""
var main

func shot(name: String) -> void:
	await process_frame
	await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + "/" + name + ".png")

func go(cell: Vector2i, dist := 17.0) -> void:
	var party = main.party
	for i in party.members.size():
		party.members[i].place_at(party.free_near(cell + party.FORMATION[i], {}))
	main.pathfinder.ensure_covers(cell)
	main.cam.position = party.members[0].position
	main.cam.distance = dist
	main.cam._place()
	main.terrain.focus_cell = cell
	main.terrain.load_all_now()
	for k in 20: await process_frame

func _initialize():
	await process_frame
	out = OS.get_environment("OUT_DIR")
	if OS.get_environment("TITLE") != "":
		var t = load("res://title.tscn").instantiate()
		root.add_child(t)
		current_scene = t
		await create_timer(2.0).timeout
		await shot("n3_title")
		quit()
		return
	var gs = root.get_node("GameState")
	gs.recruited = ["maren", "oswin", "ketta"]
	root.get_node("TimeOfDay").time = 0.45
	main = load("res://main.tscn").instantiate()
	main.spawn_encounters = false
	root.add_child(main)
	current_scene = main
	for k in 10: await process_frame
	var story = load("res://systems/story.gd")
	var v = story.village(main.world, story.setup(main.world).start)
	await go(v.center + Vector2i(0, 5), 20.0)
	await create_timer(1.0).timeout
	await shot("n3_village")
	main.cam.distance = 11.0
	main.cam._place()
	await shot("n3_village_close")
	# talk to Maud
	var maud = null
	var smith = null
	for a in main.actors:
		if is_instance_valid(a) and a.get("npc_id") == "maud": maud = a
		if is_instance_valid(a) and a.get("npc_id") == v.id + ":smith": smith = a
	maud.on_interact(main.party.members[0])
	await create_timer(0.5).timeout
	await shot("n3_dialogue")
	main.panels.open_trade(smith)
	await create_timer(0.3).timeout
	await shot("n3_trade")
	main.panels.tab = "company"
	main.panels._open("pack")
	await create_timer(0.3).timeout
	await shot("n3_company")
	main.panels._open("map")
	await shot("n3_map")
	main.panels.close_all()
	# the barrow and its lord, the burnt tower
	var s = story.setup(main.world)
	await go(s.barrow + Vector2i(0, 7), 22.0)
	root.get_node("Events").story_effect.emit("spawn:barrow")
	await create_timer(0.4).timeout
	root.get_node("TacticalPause").set_paused(true)
	await shot("n3_barrow")
	root.get_node("TacticalPause").set_paused(false)
	await go(s.ashen + Vector2i(0, 8), 24.0)
	await create_timer(1.5).timeout
	await shot("n3_tower")
	await go(s.chapel + Vector2i(0, 8), 22.0)
	await shot("n3_chapel")
	# evening in the village: lit by the sun low in the west
	root.get_node("TimeOfDay").time = 0.78
	await go(v.center + Vector2i(0, 4), 16.0)
	await create_timer(0.5).timeout
	await shot("n3_evening")
	print("done")
	quit()
