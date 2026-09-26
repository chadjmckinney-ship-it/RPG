extends SceneTree
## World-art tour: OUT_DIR=/tmp godot --path . -s res://tests/screenshot_world.gd
## Village by day and night, each biome's edge, and the three landmarks.
var main
var out: String

func _initialize():
	await process_frame
	out = OS.get_environment("OUT_DIR")
	root.get_node("TimeOfDay").time = 0.5
	main = load("res://main.tscn").instantiate()
	main.spawn_encounters = false
	root.add_child(main)
	current_scene = main
	root.get_node("TacticalPause").settings.on_enemy_spotted = false
	for k in 30: await process_frame
	var w = main.world
	var v = w.village_near(main.party.members[0].cell, 30.0)
	await shot("world_village_day", v.center + Vector2i(1, 2), 0.75)
	root.get_node("TimeOfDay").time = 0.95
	await shot("world_village_night", v.center + Vector2i(1, 2), 0.75)
	root.get_node("TimeOfDay").time = 0.5
	var T = WorldGen.Terrain
	for pair in [["world_forest", T.FOREST, T.MOOR], ["world_fen", T.FEN, T.WATER], ["world_crag", T.ROCK, T.HILLS],
			["world_ash", T.ASHFIELD, T.MOOR], ["world_road", T.ROAD, T.FOREST]]:
		var c = find_edge(pair[1], pair[2])
		if c != null:
			await shot(pair[0], c, 0.75)
	var story = Story.setup(w)
	for kind in ["barrow", "chapel", "ashen"]:
		await shot("world_" + kind, story[kind] + Vector2i(2, 2), 0.9)
	print("done")
	quit()

## A walkable cell of terrain a next to terrain b, spiralling out from the spawn.
func find_edge(a, b):
	var w = main.world
	var o = w.spawn_cell()
	for r in range(4, 250, 3):
		for i in range(0, 8 * r, 3):
			var ang = TAU * i / (8.0 * r)
			var c = o + Vector2i(roundi(cos(ang) * r), roundi(sin(ang) * r))
			if w.terrain_at(c) == a and w.terrain_at(c + Vector2i(3, 0)) == b and w.walkable(c) and not w.has_tree(c):
				return c
	return null

func shot(name: String, cell: Vector2i, zoom: float) -> void:
	main.streamer.focus_cell = cell
	main.streamer.load_all_now()
	var ms = main.party.members
	for i in ms.size():
		ms[i].place_at(main.party._free_near(cell + Vector2i(i, -i), {}))
	main.camera.position_smoothing_enabled = false
	main.camera.zoom = Vector2(zoom, zoom)
	for k in 40: await process_frame
	root.get_viewport().get_texture().get_image().save_png(out + "/" + name + ".png")
	print("shot ", name)
