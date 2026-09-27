class_name HeroSprite
extends CharSprite
## Maren, pre-rendered from her 3D model by tools/render_hero.py: one atlas per weapon
## (art/hero/maren_<variant>.png + .json) holding eight facings of every animation. Frames are
## trimmed and packed, each stored as [x, y, w, h, ox, oy] with (ox, oy) its corner relative to
## the feet. Her art is drawn 1:1 (twice the LPC cast's pixel density), so the outline is 2 texels.
## Logical animations as CharSprite: idle, ready, walk, run, attack, cast, hit, die.

const OUTLINE := preload("res://actors/sprites/outline.gdshader")
const DIRECTIONS := 8
const PORTRAIT := "res://art/hero/maren_portrait.png"

static var _meta := {}

var variant := ""
## Rim glow: transparent for none, gold when selected, red when targeted.
var rim := Color(0, 0, 0, 0):
	set(v):
		rim = v
		_material.set_shader_parameter("rim", v)
var _sprite := Sprite2D.new()
var _material := ShaderMaterial.new()
var _attack_src := ""
var _attack_n := 0

## Metadata for a weapon variant ({} when that atlas hasn't been rendered).
static func meta(v: String) -> Dictionary:
	if not _meta.has(v):
		var path := "res://art/hero/maren_%s.json" % v
		var d = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
		_meta[v] = d if d is Dictionary else {}
	return _meta[v]

static func has_art(v: String) -> bool:
	return v != "" and not meta(v).is_empty()

## Facing index for a screen-space direction: undo the 2:1 squash, then the nearest of eight
## ground directions (0 = east, counter-clockwise, 2 = north/away, 6 = south/towards the viewer).
static func facing(v: Vector2) -> int:
	return posmod(roundi(atan2(-v.y * 2.0, v.x) / (PI / 4.0)), DIRECTIONS)

func _init() -> void:
	_material.shader = OUTLINE
	_material.set_shader_parameter("width", 2.0)
	_sprite.centered = false
	_sprite.region_enabled = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.material = _material
	add_child(_sprite)

func setup(v: String) -> void:
	variant = v
	_sprite.texture = LpcSprite.tex("res://art/hero/maren_%s.png" % v)
	_apply()

## Attacks rotate through the weapon's moves (slash, backhand, thrust for the longsword).
func play(name: String, restart := false) -> void:
	if name == "attack" and (restart or anim != "attack"):
		var moves: Array = meta(variant).get("attacks", ["thrust"])
		_attack_src = moves[_attack_n % moves.size()]
		_attack_n += 1
	super.play(name, restart)

## The atlas animation used for a logical one.
func source(name: String) -> String:
	match name:
		"attack": return _attack_src if _attack_src != "" else meta(variant).get("attacks", ["thrust"])[0]
		"walk", "run", "ready", "die": return name
		"cast", "hit": return "ready"
	return "idle"

func duration(name: String) -> float:
	var a: Dictionary = meta(variant).get("anims", {}).get(source(name), {})
	return a.frames.size() / float(a.fps) if not a.is_empty() else 0.5

## [x, y, w, h, ox, oy] of the frame showing now.
func current_frame() -> Array:
	var a: Dictionary = meta(variant).get("anims", {}).get(source(anim), {})
	if a.is_empty():
		return []
	var frames: Array = a.frames
	var i := int(t * float(a.fps))
	i = i % frames.size() if a.loop else mini(i, frames.size() - 1)
	return frames[i][facing(dir)]

func _apply() -> void:
	var r := current_frame()
	if r.is_empty():
		return
	_sprite.region_rect = Rect2(r[0], r[1], r[2], r[3])
	_sprite.position = Vector2(r[4], r[5])
