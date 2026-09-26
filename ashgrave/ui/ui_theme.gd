class_name UiTheme
extends RefCounted
## One dark, brass-trimmed look for every panel and button.

const INK := Color("e8dfc8")
const MUTED := Color("a8a090")
const GOLD := Color("f0b04a")
const BG := Color(0.07, 0.065, 0.06, 0.96)
const EDGE := Color("6a5a3a")

static var _theme: Theme

static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.set_stylebox("panel", "PanelContainer", _box(BG, EDGE, 2, 14))
	t.set_stylebox("normal", "Button", _box(Color(0.14, 0.12, 0.1), Color("4a4030"), 1, 6))
	t.set_stylebox("hover", "Button", _box(Color(0.2, 0.17, 0.12), GOLD, 1, 6))
	t.set_stylebox("pressed", "Button", _box(Color(0.28, 0.2, 0.1), GOLD, 1, 6))
	t.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), GOLD, 1, 6))
	t.set_stylebox("disabled", "Button", _box(Color(0.1, 0.09, 0.08), Color("2e2a24"), 1, 6))
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", GOLD)
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", Color(0.45, 0.43, 0.4))
	t.set_color("font_color", "Label", INK)
	t.set_color("font_color", "CheckBox", INK)
	t.set_stylebox("normal", "LineEdit", _box(Color(0.04, 0.035, 0.03), Color("4a4030"), 1, 6))
	t.set_color("font_color", "LineEdit", INK)
	t.set_stylebox("slider", "HSlider", _box(Color(0.2, 0.18, 0.15), Color(0, 0, 0, 0), 0, 2))
	t.set_stylebox("grabber_area", "HSlider", _box(GOLD.darkened(0.3), Color(0, 0, 0, 0), 0, 2))
	t.set_stylebox("grabber_area_highlight", "HSlider", _box(GOLD, Color(0, 0, 0, 0), 0, 2))
	_theme = t
	return t

static func _box(bg: Color, border: Color, bw: int, margin: int) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(bw)
	b.set_content_margin_all(margin)
	b.set_corner_radius_all(2)
	return b
