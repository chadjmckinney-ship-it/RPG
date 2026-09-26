extends TestCase
## Title flow, settings persistence, menus and the world map.

func test_world_map_texture() -> void:
	var w := WorldGen.new(4242)
	var tex := WorldMap.texture(w)
	check(tex.get_width() == WorldGen.SIZE / WorldMap.SCALE, "map texture wrong size")
	check(WorldMap.texture(w) == tex, "map texture not cached")
	var r := Rect2(0, 0, 600, 400)
	var t := WorldMap.iso_transform(r)
	for corner in [Vector2(0, 0), Vector2(WorldGen.SIZE, 0), Vector2(0, WorldGen.SIZE), Vector2(WorldGen.SIZE, WorldGen.SIZE)]:
		check(r.grow(1).has_point(t * corner), "map corner %s falls outside the panel" % corner)
	# North on screen (smaller y) should be cell-space (-1,-1), as in the game view.
	check((t * Vector2(100, 100)).y < (t * Vector2(200, 200)).y, "map is not oriented like the game view")

func test_settings_round_trip() -> void:
	var before: Dictionary = Audio.volume.duplicate()
	var pause_before: Dictionary = TacticalPause.settings.duplicate()
	Audio.volume.music = 0.25
	TacticalPause.settings.on_low_health = false
	Settings.save()
	Audio.volume.music = 0.9
	TacticalPause.settings.on_low_health = true
	Settings.load_and_apply()
	check(is_equal_approx(Audio.volume.music, 0.25), "music volume not persisted")
	check(TacticalPause.settings.on_low_health == false, "pause setting not persisted")
	Audio.volume = before
	TacticalPause.settings = pause_before
	Settings.save()

func test_title_starts_a_new_game() -> void:
	var title: Control = load("res://title.tscn").instantiate()
	tree.root.add_child(title)
	tree.current_scene = title
	await tree.process_frame
	title.seed_edit.text = "777"
	title._refresh_preview()
	check(title.preview.seed_value == 777, "preview doesn't follow the seed box")
	title._new_game()
	for i in 20:
		await tree.process_frame
		if tree.current_scene and tree.current_scene.name == "Main":
			break
	var main: Node = tree.current_scene
	check(main != null and main.name == "Main", "new game didn't open the world")
	check(GameState.world.seed_value == 777, "world seed not applied")
	check(main.party.members.size() == 1 and main.party.members[0].display_name == "Maren Vey", "new game should start with Maren alone")
	# Esc menu and map open over the world and restore pause state on close
	main.panels.open_menu()
	check(TacticalPause.paused and main.panels.mode == "menu", "menu didn't open paused")
	main.panels.close_all()
	check(not TacticalPause.paused, "closing the menu left the game paused")
	main.panels.open_map()
	check(main.panels.mode == "map", "map didn't open")
	main.panels.close_all()
	main.queue_free()
	tree.current_scene = null
	await tree.process_frame
	GameState.reset()
