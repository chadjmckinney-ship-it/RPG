class_name LpcSprite
extends CharSprite
## Layered LPC character: weapon-behind, body (baked outfit), weapon-front.
## Atlases come from tools/import_lpc.py; rows are N, W, S, E. Character atlases hold 64 px
## animations; weapon atlases add oversize (192 px) swings drawn over the body's 64 px pose.
## Logical animations: idle, ready (combat stance), walk, run, attack, cast, hit, die.

const SCALE := 2.0
const FPS := {"idle": 3.0, "combat_idle": 4.0, "walk": 10.0, "run": 12.0, "slash": 12.0, "slash_big": 12.0,
	"slash_rev_big": 12.0, "thrust_big": 13.0, "thrust": 12.0, "shoot": 16.0, "cast": 12.0, "hurt": 8.0}
const OUTLINE := preload("res://actors/sprites/outline.gdshader")

static var _meta: Dictionary = {}
static var _textures := {}

var character := ""
var weapon := ""
var body := "female"
## Rim glow: transparent for none, gold when selected, red when targeted.
var rim := Color(0, 0, 0, 0):
	set(v):
		rim = v
		_material.set_shader_parameter("rim", v)
var _layers: Array[Sprite2D] = []
var _material := ShaderMaterial.new()
var _attack_src := ""
var _attack_n := 0

static func meta() -> Dictionary:
	if _meta.is_empty():
		_meta = JSON.parse_string(FileAccess.get_file_as_string("res://art/lpc/layout.json"))
	return _meta

static func tex(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load(path) if ResourceLoader.exists(path) else null
	return _textures[path]

func _init() -> void:
	_material.shader = OUTLINE
	for i in 3:
		var s := Sprite2D.new()
		s.centered = false
		s.region_enabled = true
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.scale = Vector2(SCALE, SCALE)
		s.material = _material
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

## Attacks rotate through the weapon's moves (e.g. slash, reverse slash, thrust for a longsword).
func play(name: String, restart := false) -> void:
	if name == "attack" and (restart or anim != "attack"):
		var moves: Array = meta().weapons.get(weapon, {}).get("attacks", [source("attack")]) if weapon != "" else ["slash"]
		_attack_src = moves[_attack_n % moves.size()]
		_attack_n += 1
	super.play(name, restart)

## The atlas animation used for a logical one.
func source(name: String) -> String:
	match name:
		"attack":
			if _attack_src != "":
				return _attack_src
			return meta().weapons.get(weapon, {}).get("attack", "slash") if weapon != "" else "slash"
		"cast": return "cast"
		"die": return "hurt"
		"hit": return "idle"
		"walk": return "walk"
		"run": return "run" if meta().layout.has("run") else "walk"
		"ready": return "combat_idle" if meta().layout.has("combat_idle") else "idle"
	return "idle"

func _info(src: String) -> Dictionary:
	return meta().layout.get(src, meta().get("weapon_layout", {}).get(src, {}))

func duration(name: String) -> float:
	var src := source(name)
	var frames: int = _info(src).frames
	if src == "walk":
		frames -= 1
	return frames / FPS.get(src, 10.0)

func _apply() -> void:
	if character == "":
		return
	var src := source(anim)
	var m := _info(src)
	var frames: int = m.frames
	var col := 0
	if src == "walk":
		col = 1 + int(t * FPS.walk) % (frames - 1)   # frame 0 is the standing pose
	elif src in ["idle", "combat_idle", "run"]:
		col = int(t * FPS[src]) % frames
	else:
		col = mini(int(t * FPS.get(src, 10.0)), frames - 1)
	var row := 0
	if m.rows == 4:
		# N, W, S, E by nearest screen direction
		if absf(dir.x) > absf(dir.y):
			row = 3 if dir.x > 0 else 1
		else:
			row = 2 if dir.y > 0 else 0
	# Oversize weapon swings: the body shows its own 64 px pose (reversed for a backhand).
	var body_src := src
	var body_col := col
	var big: Array = meta().get("big_body", {}).get(src, [])
	if not big.is_empty():
		body_src = big[0]
		var bf: int = meta().layout[body_src].frames
		body_col = mini(bf - 1 - col if big[1] else col, bf - 1)
	var bm: Dictionary = meta().layout[body_src]
	# feet sit about 30 px below the frame centre in LPC art
	_layers[1].region_rect = Rect2(body_col * 64.0, bm.y + mini(row, bm.rows - 1) * 64.0, 64.0, 64.0)
	_layers[1].position = Vector2(-32.0, -62.0) * SCALE
	# weapon atlases hold every row (64 px ones first, then the oversize swings)
	var wm: Dictionary = meta().get("weapon_layout", meta().layout)[src]
	var size: float = wm.size
	for i in [0, 2]:
		_layers[i].region_rect = Rect2(col * size, float(wm.y) + row * size, size, size)
		_layers[i].position = Vector2(-size / 2.0, -(size / 2.0 + 30.0)) * SCALE
