extends Node3D
## Title screen: continue, new game (with a seed), settings, quit. The backdrop is the world you
## are about to play, seen from a slowly circling camera, with Maren standing at the camp.

var seed_edit: LineEdit
var status: Label
var preview: WorldGen
var terrain: Terrain
var cam: Camera3D
var sun: DirectionalLight3D
var env: WorldEnvironment
var hero: CharacterModel
var menu: VBoxContainer
var settings_box: VBoxContainer
var _t := 0.0
var _focus := Vector3.ZERO
var _rebuild_in := -1.0

func _ready() -> void:
	Actor.ctx = null
	env = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.36, 0.38, 0.42)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.5, 0.5, 0.58)
	env.environment.ambient_light_energy = 0.4
	env.environment.fog_enabled = true
	env.environment.fog_light_color = Color(0.36, 0.38, 0.42)
	env.environment.fog_density = 0.012
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(env)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-24, 200, 0)
	sun.light_color = Color(1.0, 0.78, 0.6)
	sun.light_energy = 0.9
	add_child(sun)
	Settings.apply_graphics(env.environment, sun, get_viewport())
	cam = Camera3D.new()
	cam.fov = 45.0
	cam.far = 400.0
	add_child(cam)
	_build_ui()
	Audio.set_music("night")
	_refresh_preview()

func _build_ui() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	var root := Control.new()
	root.theme = UiTheme.get_theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)
	# left-side shade so the menu reads over the scenery
	var shade := TextureRect.new()
	var grad := GradientTexture2D.new()
	grad.gradient = Gradient.new()
	grad.gradient.set_color(0, Color(0.04, 0.035, 0.03, 0.92))
	grad.gradient.set_color(1, Color(0.04, 0.035, 0.03, 0.0))
	grad.fill_to = Vector2(1, 0)
	shade.texture = grad
	shade.anchor_bottom = 1.0
	shade.offset_right = 620
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	var col := VBoxContainer.new()
	col.position = Vector2(80, 110)
	col.custom_minimum_size = Vector2(380, 0)
	col.add_theme_constant_override("separation", 10)
	root.add_child(col)
	col.add_child(UiTheme.title_label("Ashgrave", 84))
	var sub := Label.new()
	sub.text = "The dead stopped staying buried.\nMaren Vey, deserter, is going to find out why."
	sub.add_theme_color_override("font_color", UiTheme.MUTED)
	col.add_child(sub)
	col.add_child(HSeparator.new())
	menu = VBoxContainer.new()
	menu.add_theme_constant_override("separation", 10)
	col.add_child(menu)
	var save := GameState.read_save()
	var cont := Button.new()
	cont.text = "Continue" + ("" if save.is_empty() else "  (day %d)" % int(save.get("day", 1)))
	cont.disabled = save.is_empty()
	cont.pressed.connect(_continue)
	menu.add_child(cont)
	var row := HBoxContainer.new()
	seed_edit = LineEdit.new()
	seed_edit.placeholder_text = "world seed"
	seed_edit.text = str(randi() % 1_000_000)
	seed_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_edit.text_changed.connect(func(_t): _rebuild_in = 0.6)
	row.add_child(seed_edit)
	var dice := Button.new()
	dice.text = "Reroll"
	dice.pressed.connect(func(): seed_edit.text = str(randi() % 1_000_000); _refresh_preview())
	row.add_child(dice)
	menu.add_child(row)
	var new_game := Button.new()
	new_game.text = "New game in this world"
	new_game.pressed.connect(_new_game)
	menu.add_child(new_game)
	var set_b := Button.new()
	set_b.text = "Settings"
	set_b.pressed.connect(func(): menu.visible = false; settings_box.visible = true)
	menu.add_child(set_b)
	var quit := Button.new()
	quit.text = "Quit"
	quit.pressed.connect(func(): get_tree().quit())
	menu.add_child(quit)
	status = Label.new()
	status.add_theme_color_override("font_color", UiTheme.MUTED)
	status.add_theme_font_size_override("font_size", UiTheme.fs(13))
	menu.add_child(status)
	settings_box = _settings_box()
	settings_box.visible = false
	col.add_child(settings_box)

func _settings_box() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	for k in ["master", "music", "sfx"]:
		var h := HBoxContainer.new()
		var l := Label.new()
		l.text = k.capitalize() + " volume"
		l.custom_minimum_size.x = 170
		h.add_child(l)
		var sl := HSlider.new()
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.05
		sl.value = Audio.volume[k]
		sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sl.value_changed.connect(func(v): Audio.volume[k] = v; Settings.save())
		h.add_child(sl)
		box.add_child(h)
	var gh := HBoxContainer.new()
	var gl := Label.new()
	gl.text = "Graphics"
	gl.custom_minimum_size.x = 170
	gh.add_child(gl)
	var opt := OptionButton.new()
	for q in Settings.QUALITY:
		opt.add_item(q.capitalize())
	opt.selected = Settings.QUALITY.find(Settings.graphics)
	opt.item_selected.connect(func(i):
		Settings.graphics = Settings.QUALITY[i]
		Settings.save()
		Settings.apply_graphics(env.environment, sun, get_viewport()))
	gh.add_child(opt)
	box.add_child(gh)
	for k in TacticalPause.settings:
		var cb := CheckBox.new()
		cb.text = {"on_enemy_spotted": "Pause when enemies spot the party", "on_low_health": "Pause when someone is badly hurt"}.get(k, k)
		cb.button_pressed = TacticalPause.settings[k]
		cb.toggled.connect(func(v): TacticalPause.settings[k] = v; Settings.save())
		box.add_child(cb)
	var back := Button.new()
	back.text = "Back"
	back.pressed.connect(func(): settings_box.visible = false; menu.visible = true)
	box.add_child(back)
	return box

func _seed() -> int:
	return absi(int(seed_edit.text)) if seed_edit.text.is_valid_int() else absi(hash(seed_edit.text)) % 1_000_000

## Rebuild the backdrop for the seed in the box: terrain around the spawn and Maren at camp.
func _refresh_preview() -> void:
	_rebuild_in = -1.0
	preview = WorldGen.new(_seed())
	status.text = "%d villages in this province." % preview.villages().size()
	if terrain:
		terrain.queue_free()
	terrain = Terrain.new()
	add_child(terrain)
	terrain.setup(preview)
	var spawn := preview.spawn_cell()
	terrain.focus_cell = spawn
	terrain.load_all_now()
	_focus = preview.cell_to_world(spawn)
	if hero == null:
		hero = CharacterModel.new()
		add_child(hero)
		hero.setup("maren", Color("7a3a2a"))
	hero.position = _focus
	_place_camera()

func _place_camera() -> void:
	var a := _t * 0.05 + 0.6
	var eye := _focus + Vector3(cos(a) * 9.0, 0.0, sin(a) * 9.0)
	eye.y = maxf(preview.ground_y(eye), WorldGen.SEA_Y) + 3.2
	cam.look_at_from_position(eye, _focus + Vector3(0, 1.1, 0))
	hero.face(eye - _focus)

func _process(delta: float) -> void:
	_t += delta
	if _rebuild_in > 0.0:
		_rebuild_in -= delta
		if _rebuild_in <= 0.0:
			_refresh_preview()
	if preview:
		_place_camera()

func _new_game() -> void:
	GameState.reset()
	GameState.new_world(_seed())
	TimeOfDay.time = 8.0 / 24.0
	TimeOfDay.day = 1
	get_tree().change_scene_to_file("res://main.tscn")

func _continue() -> void:
	var data := GameState.read_save()
	if data.is_empty():
		return
	GameState.pending_load = data
	get_tree().change_scene_to_file("res://main.tscn")
