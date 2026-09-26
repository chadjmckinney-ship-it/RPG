class_name UiTheme
extends RefCounted
## One dark, iron-and-brass pixel look for every panel and button (art from tools/import_ui.py).
## Body text is the pixel face Jersey 10; titles use the blackletter UnifrakturCook (both SIL OFL).
## Jersey 10 runs small, so callers pass sizes through fs().

const INK := Color("e8dfc8")
const MUTED := Color("a8a090")
const GOLD := Color("f0b04a")
const BG := Color(0.07, 0.065, 0.06, 0.96)
const EDGE := Color("6a5a3a")

static var _theme: Theme
static var _font: Font
static var _title_font: Font

## Body font size for a size written for an ordinary sans face.
static func fs(size: int) -> int:
	return roundi(size * 1.35)

static func font() -> Font:
	if _font == null:
		_font = load("res://art/ui/fonts/Jersey10.ttf")
	return _font

static func title_font() -> Font:
	if _title_font == null:
		_title_font = load("res://art/ui/fonts/UnifrakturCook-Bold.ttf")
	return _title_font

## A label in the title face.
static func title_label(text: String, size: int, col := GOLD) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", title_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("shadow_offset_x", 2)
	l.add_theme_constant_override("shadow_offset_y", 2)
	return l

static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = fs(16)
	t.set_stylebox("panel", "PanelContainer", pixel_box("frame", 16))
	t.set_stylebox("normal", "Button", pixel_box("button", 7))
	t.set_stylebox("hover", "Button", pixel_box("button_hover", 7))
	t.set_stylebox("pressed", "Button", pixel_box("button_pressed", 7))
	t.set_stylebox("hover_pressed", "Button", pixel_box("button_pressed", 7))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_stylebox("disabled", "Button", pixel_box("button_disabled", 7))
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", GOLD)
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", Color(0.45, 0.43, 0.4))
	t.set_color("font_color", "Label", INK)
	t.set_color("font_color", "CheckBox", INK)
	t.set_stylebox("normal", "LineEdit", pixel_box("slot", 7))
	t.set_stylebox("focus", "LineEdit", StyleBoxEmpty.new())
	t.set_color("font_color", "LineEdit", INK)
	t.set_stylebox("slider", "HSlider", _box(Color(0.2, 0.18, 0.15), Color(0, 0, 0, 0), 0, 2))
	t.set_stylebox("grabber_area", "HSlider", _box(GOLD.darkened(0.3), Color(0, 0, 0, 0), 0, 2))
	t.set_stylebox("grabber_area_highlight", "HSlider", _box(GOLD, Color(0, 0, 0, 0), 0, 2))
	_theme = t
	return t

## 9-slice pixel frame from art/ui/<name>.png (pixels are already doubled; 6 px corners).
static func pixel_box(name: String, margin: int) -> StyleBoxTexture:
	var b := StyleBoxTexture.new()
	b.texture = load("res://art/ui/%s.png" % name)
	b.set_texture_margin_all(6)
	b.set_content_margin_all(margin)
	return b

static func _box(bg: Color, border: Color, bw: int, margin: int) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(bw)
	b.set_content_margin_all(margin)
	b.set_corner_radius_all(2)
	return b
