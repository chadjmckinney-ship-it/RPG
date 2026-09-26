class_name LpcSprite
extends CharSprite
## Layered LPC character: weapon-behind, body (baked outfit), weapon-front, sharing one frame.
## Atlases come from tools/import_lpc.py; rows are N, W, S, E.

const SCALE := 2.0
const FPS := {"idle": 3.0, "walk": 10.0, "slash": 12.0, "slash_big": 12.0, "thrust": 12.0, "shoot": 16.0, "cast": 12.0, "hurt": 8.0}

static var _meta: Dictionary = {}
static var _textures := {}

var character := ""
var weapon := ""
var body := "female"
var _layers: Array[Sprite2D] = []

static func meta() -> Dictionary:
	if _meta.is_empty():
		_meta = JSON.parse_string(FileAccess.get_file_as_string("res://art/lpc/layout.json"))
	return _meta

static func tex(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load(path) if ResourceLoader.exists(path) else null
	return _textures[path]

func _init() -> void:
	for i in 3:
		var s := Sprite2D.new()
		s.centered = false
		s.region_enabled = true
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.scale = Vector2(SCALE, SCALE)
		add_child(s)
		_layers.append(s)

func setup(char_id: String, weapon_id: String) -> void:
	character = char_id
	weapon = weapon_id
	body = meta().characters.get(char_id, {}).get("body", "female")
	_layers[1].texture = tex("res://art/lpc/chars/%s.png" % char_id)
	_layers[0].texture = tex("res://art/lpc/weapons/%s_%s_behind.png" % [weapon_id, body]) if weapon_id != "" else null
	_layers[2].texture = tex("res://art/lpc/weapons/%s_%s_front.png" % [weapon_id, body]) if weapon_id != "" else null
	_apply()

## The LPC animation used for a logical one.
func source(name: String) -> String:
	match name:
		"attack":
			return meta().weapons.get(weapon, {}).get("attack", "slash") if weapon != "" else "slash"
		"cast": return "cast"
		"die": return "hurt"
		"hit": return "idle"
		"walk": return "walk"
	return "idle"

func duration(name: String) -> float:
	var src := source(name)
	var m: Dictionary = meta().layout[src]
	var frames: int = m.frames
	if src == "walk":
		frames -= 1
	return frames / FPS[src]

func _apply() -> void:
	if character == "":
		return
	var src := source(anim)
	var m: Dictionary = meta().layout[src]
	var size: float = m.size
	var frames: int = m.frames
	var col := 0
	if src == "walk":
		col = 1 + int(t * FPS.walk) % (frames - 1)   # frame 0 is the standing pose
	elif src == "idle":
		col = int(t * FPS.idle) % frames
	else:
		col = mini(int(t * FPS[src]), frames - 1)
	var row := 0
	if m.rows == 4:
		# N, W, S, E by nearest screen direction
		if absf(dir.x) > absf(dir.y):
			row = 3 if dir.x > 0 else 1
		else:
			row = 2 if dir.y > 0 else 0
	var region := Rect2(col * size, m.y + row * size, size, size)
	# feet sit about 30 px below the frame centre in LPC art
	var pos := Vector2(-size / 2.0, -(size / 2.0 + 30.0)) * SCALE
	for s in _layers:
		s.region_rect = region
		s.position = pos
