extends Control
## Title screen: continue, new game (with a seed), settings, quit.
## The backdrop is the actual map of the seed you're about to play.

var seed_edit: LineEdit
var backdrop: Control
var preview: WorldGen
var status: Label

func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop = Control.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.draw.connect(_draw_backdrop)
	add_child(backdrop)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_TOP_LEFT)
	col.position = Vector2(80, 110)
	col.custom_minimum_size = Vector2(380, 0)
	col.add_theme_constant_override("separation", 10)
	add_child(col)
	col.add_child(UiTheme.title_label("Ashgrave", 84))
	var sub := Label.new()
	sub.text = "The dead stopped staying buried.\nMaren Vey, deserter, is going to find out why."
	sub.add_theme_color_override("font_color", UiTheme.MUTED)
	col.add_child(sub)
	col.add_child(HSeparator.new())

	var save := GameState.read_save()
	var cont := Button.new()
	cont.text = "Continue" + ("" if save.is_empty() else "  (day %d)" % int(save.get("day", 1)))
	cont.disabled = save.is_empty()
	cont.pressed.connect(_continue)
	col.add_child(cont)

	var row := HBoxContainer.new()
	seed_edit = LineEdit.new()
	seed_edit.placeholder_text = "world seed"
	seed_edit.text = str(randi() % 1_000_000)
	seed_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_edit.text_changed.connect(func(_t): _refresh_preview())
	row.add_child(seed_edit)
	var dice := Button.new()
	dice.text = "Reroll"
	dice.pressed.connect(func(): seed_edit.text = str(randi() % 1_000_000); _refresh_preview())
	row.add_child(dice)
	col.add_child(row)
	var new_game := Button.new()
	new_game.text = "New game in this world"
	new_game.pressed.connect(_new_game)
	col.add_child(new_game)
	var quit := Button.new()
	quit.text = "Quit"
	quit.pressed.connect(func(): get_tree().quit())
	col.add_child(quit)
	status = Label.new()
	status.add_theme_color_override("font_color", UiTheme.MUTED)
	status.add_theme_font_size_override("font_size", UiTheme.fs(13))
	col.add_child(status)
	var foot := Label.new()
	foot.text = "Settings are in the Esc menu once you're playing."
	foot.add_theme_font_size_override("font_size", UiTheme.fs(12))
	foot.add_theme_color_override("font_color", UiTheme.MUTED)
	col.add_child(foot)
	# Maren herself, large, standing over the map
	var hero: CharSprite
	var variant := ArtMap.hero_variant("maren", {})
	if variant != "":
		hero = HeroSprite.new()
		hero.setup(variant)
		hero.scale = Vector2(2.0, 2.0)
	else:
		hero = LpcSprite.new()
		hero.setup("maren", "longsword")
		hero.scale = Vector2(2.5, 2.5)
	hero.position = Vector2(1080, 640)
	hero.face(Vector2(-0.3, 1))
	hero.play("idle", true)
	add_child(hero)
	Audio.set_music("night")
	_refresh_preview()

func _seed() -> int:
	return absi(int(seed_edit.text)) if seed_edit.text.is_valid_int() else absi(hash(seed_edit.text)) % 1_000_000

func _refresh_preview() -> void:
	preview = WorldGen.new(_seed())
	status.text = "%d villages in this province." % preview.villages().size()
	backdrop.queue_redraw()

func _draw_backdrop() -> void:
	var r := Rect2(Vector2(360, 20), backdrop.size - Vector2(380, 40))
	backdrop.draw_rect(Rect2(Vector2.ZERO, backdrop.size), Color("0c0a09"))
	if preview == null:
		return
	var t := WorldMap.iso_transform(r)
	var s := float(WorldMap.SCALE)
	backdrop.draw_set_transform_matrix(t * Transform2D(0.0, Vector2(s, s), 0.0, Vector2.ZERO))
	backdrop.draw_texture(WorldMap.texture(preview), Vector2.ZERO, Color(0.8, 0.75, 0.7))
	backdrop.draw_set_transform_matrix(Transform2D.IDENTITY)
	var sp: Vector2 = t * Vector2(preview.spawn_cell())
	backdrop.draw_circle(sp, 4, Color(0.95, 0.3, 0.25))
	# left-side fade so the menu reads cleanly
	for i in 40:
		backdrop.draw_rect(Rect2(Vector2(i * 12, 0), Vector2(12, backdrop.size.y)), Color(0.05, 0.04, 0.035, 1.0 - i / 40.0))

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
