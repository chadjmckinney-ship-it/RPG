class_name Landmark
extends Node2D
## Story locations: the Drowned Barrow, the Chapel of Ash and the burnt watchtower
## (art from tools/import_world.py). The tower keeps a few procedural embers.

const SCALE := 2.0

var kind := "barrow"
var fade: ShaderMaterial
var _height := 0.0

func _ready() -> void:
	var s := Sprite2D.new()
	s.texture = load("res://art/world/landmarks/%s.png" % kind)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.centered = false
	s.scale = Vector2(SCALE, SCALE)
	s.offset = Vector2(-s.texture.get_width() / 2.0, -s.texture.get_height() + 12.0)
	s.material = fade
	s.show_behind_parent = true   # embers draw on top
	add_child(s)
	_height = s.texture.get_height() * SCALE

func _process(_d: float) -> void:
	if kind == "ashen":
		queue_redraw()

func _draw() -> void:
	if kind != "ashen":
		return
	var t := Time.get_ticks_msec() / 1000.0
	for i in 7:
		var phase := fmod(t * 0.35 + i * 0.37, 1.0)
		var p := Vector2(-40 + i * 13 + sin(t + i) * 6.0, -_height + 70 - phase * 70.0)
		draw_rect(Rect2(p.round(), Vector2(4, 4)), Color(1.0, 0.45 + 0.2 * (i % 2), 0.15, 0.9 * (1.0 - phase)))
