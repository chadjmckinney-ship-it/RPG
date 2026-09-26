class_name Hud
extends CanvasLayer
## Party portraits, clock, pause banner and a controls hint. Plain Controls for now.

var main: Node
var clock: Label
var info: Label
var banner: Label
var roster: VBoxContainer

func setup(m: Node) -> void:
	main = m
	var font_col := Color("e8dfc8")
	roster = VBoxContainer.new()
	roster.position = Vector2(16, 16)
	add_child(roster)
	clock = _label(Vector2(0, 16), 22, font_col)
	clock.anchor_left = 1.0
	clock.anchor_right = 1.0
	clock.offset_left = -220
	clock.offset_right = -16
	clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info = _label(Vector2(16, 0), 14, Color("a8a090"))
	info.anchor_top = 1.0
	info.anchor_bottom = 1.0
	info.offset_top = -28
	info.text = "Left-click / drag: select   Right-click: move   1-3 / Tab: pick   Space: tactical pause   WASD: pan   Wheel: zoom"
	banner = _label(Vector2.ZERO, 30, Color("f0b04a"))
	banner.anchor_left = 0.5
	banner.anchor_right = 0.5
	banner.offset_left = -200
	banner.offset_right = 200
	banner.offset_top = 70
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.text = "— PAUSED —"
	banner.visible = false
	Events.paused_changed.connect(func(p): banner.visible = p)
	Events.selection_changed.connect(func(_s): _refresh_roster())
	_refresh_roster()

func _label(pos: Vector2, size: int, col: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	add_child(l)
	return l

func _refresh_roster() -> void:
	for c in roster.get_children():
		c.queue_free()
	for i in main.party.members.size():
		var m: PartyMember = main.party.members[i]
		var l := Label.new()
		l.text = "%d  %s — %s" % [i + 1, m.display_name, m.role]
		var sel: bool = main.party.selection.has(m)
		l.add_theme_color_override("font_color", Color("f0b04a") if sel else Color("c8c0ac"))
		l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		l.add_theme_constant_override("shadow_offset_x", 1)
		l.add_theme_constant_override("shadow_offset_y", 1)
		roster.add_child(l)

func _process(_d: float) -> void:
	clock.text = "Day · %s\n%s" % [TimeOfDay.clock_text(), main.terrain_under_mouse()]
