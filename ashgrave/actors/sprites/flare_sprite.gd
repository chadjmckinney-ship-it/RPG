class_name FlareSprite
extends CharSprite
## Flare creature atlas (tools/import_flare.py): 8 directions, per-frame offsets.
## Direction order in screen terms: 0=W 1=NW 2=N 3=NE 4=E 5=SE 6=S 7=SW.

static var _cache := {}

var key := ""
var data: Dictionary = {}
var _sprite := Sprite2D.new()

func _init() -> void:
	_sprite.centered = false
	_sprite.region_enabled = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_sprite)

func setup(k: String, tint := Color.WHITE, size := 1.0) -> void:
	key = k
	if not _cache.has(k):
		_cache[k] = {
			"tex": load("res://art/flare/creatures/%s.png" % k),
			"data": JSON.parse_string(FileAccess.get_file_as_string("res://art/flare/creatures/%s.json" % k)),
		}
	_sprite.texture = _cache[k].tex
	data = _cache[k].data
	_sprite.self_modulate = tint
	scale = Vector2(size, size)
	_apply()

func _src(name: String) -> String:
	var anims: Dictionary = data.get("anims", {})
	if anims.has(name):
		return name
	if name == "cast" and anims.has("attack"):
		return "attack"
	return "idle"

func duration(name: String) -> float:
	var a: Dictionary = data.get("anims", {}).get(_src(name), {})
	return a.get("ms", 500) / 1000.0 * (2.0 if a.get("type") == "back_forth" else 1.0)

static func dir_index(v: Vector2) -> int:
	return posmod(roundi(v.angle() / (PI / 4.0)) + 4, 8)

func _apply() -> void:
	if data.is_empty():
		return
	var a: Dictionary = data.anims[_src(anim)]
	var frames: Array = a.dirs[dir_index(dir)]
	if frames.is_empty():
		return
	var n := frames.size()
	var dur: float = a.ms / 1000.0
	var i := 0
	match a.type:
		"back_forth":
			var k := int(t / dur * n) % maxi(1, 2 * n - 2)
			i = k if k < n else 2 * n - 2 - k
		"play_once":
			i = mini(int(t / dur * n), n - 1)
		_:
			i = int(t / dur * n) % n
	var f: Array = frames[clampi(i, 0, n - 1)]
	_sprite.region_rect = Rect2(f[0], f[1], f[2], f[3])
	_sprite.position = Vector2(-f[4], -f[5])
