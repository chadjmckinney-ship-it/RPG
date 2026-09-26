class_name Structure
extends Node2D
## A village building (art from tools/import_world.py). The node sits on the footprint's
## front cell, lifted a little so people standing beside the walls sort in front of them.

const SORT_LIFT := 8.0
const SCALE := 2.0

var kind := "house_a"
var village: Dictionary = {}
var fade: ShaderMaterial
var _glow: Sprite2D
var _smoke: CPUParticles2D

func _ready() -> void:
	var body := _sprite("res://art/world/buildings/%s.png" % kind)
	body.material = fade
	_glow = _sprite("res://art/world/buildings/%s_glow.png" % kind)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_glow.material = add
	if kind == "forge":
		_smoke = CPUParticles2D.new()
		_smoke.amount = 14
		_smoke.lifetime = 2.2
		_smoke.position = Vector2(0, -body.texture.get_height() * SCALE + 24 + SORT_LIFT)   # roof ridge
		_smoke.direction = Vector2(0.2, -1)
		_smoke.spread = 12.0
		_smoke.gravity = Vector2(6, -14)
		_smoke.initial_velocity_min = 14.0
		_smoke.initial_velocity_max = 24.0
		_smoke.scale_amount_min = 5.0
		_smoke.scale_amount_max = 9.0
		_smoke.color = Color(0.3, 0.29, 0.28, 0.5)
		var fade_out := Gradient.new()
		fade_out.set_color(0, Color(1, 1, 1, 0.8))
		fade_out.set_color(1, Color(1, 1, 1, 0))
		_smoke.color_ramp = fade_out
		add_child(_smoke)

func _sprite(path: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(path)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.centered = false
	s.scale = Vector2(SCALE, SCALE)
	# bottom-centre of the art on the front cell's centre
	s.offset = Vector2(-s.texture.get_width() / 2.0, -s.texture.get_height() + SORT_LIFT / SCALE)
	add_child(s)
	return s

func _process(_d: float) -> void:
	var night := 1.0 - TimeOfDay.daylight()
	_glow.modulate = Color(1, 1, 1, clampf(night * 1.3, 0.0, 1.0))
