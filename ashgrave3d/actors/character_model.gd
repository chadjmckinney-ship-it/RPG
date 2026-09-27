class_name CharacterModel
extends Node3D
## A character's 3D body. Loads res://characters/<id>/<id>.glb (your Blender/Meshy export) and
## maps the game's logical animations to its clips; falls back to a code-built mannequin.
##
## Extra clips: any other .glb in the same folder with the same skeleton donates its animations
## (e.g. maren_idle.glb, maren_attack.glb), so clips can be exported one at a time.
## Optional res://characters/<id>/anims.json:
##   {"yaw": 180, "scale": 1.0, "walk_speed": 1.4, "clips": {"walk": "Walking_Woman", "attack": ["Slash", "Stab"]}}
## Logical animations: idle, ready, walk, run, attack, cast, shoot, hit, die.
## Missing clips are covered: idle/ready hold a walk pose and breathe, run speeds up walk,
## attack/cast/shoot lunge, hit flinches, die falls over.

signal finished(anim: String)

const LOGICAL := ["idle", "ready", "walk", "run", "attack", "cast", "shoot", "hit", "die"]
const ONE_SHOT := ["attack", "cast", "shoot", "hit", "die"]
## Clip-name keywords tried when anims.json doesn't name a clip.
const KEYWORDS := {
	"idle": ["idle", "stand", "breath"], "ready": ["combat_idle", "combatidle", "ready", "stance"],
	"walk": ["walk"], "run": ["run", "sprint", "jog"], "attack": ["attack", "slash", "swing", "stab", "punch", "strike"],
	"cast": ["cast", "spell"], "shoot": ["shoot", "bow", "aim"], "hit": ["hit", "hurt", "damage"], "die": ["death", "die", "dying"],
}

var id := ""
var model: Node3D
var ap: AnimationPlayer
var clips := {}             # logical -> Array of clip names
var yaw_offset := 0.0       # radians added so the model faces -Z (Godot forward)
var walk_speed := 1.4       # metres per second at which the walk clip looks right
var anim := "idle"
var move_speed := 0.0       # set by the actor; scales walk/run playback
var _t := 0.0
var _attack_n := 0
var _procedural := ""       # fallback motion in progress: lunge, flinch, fall
var _body: Node3D           # rotates for procedural motion
var _pose_pending := false
var _held := false
var _meshes: Array[MeshInstance3D] = []
var _flash_t := 0.0
var _highlight := Color(0, 0, 0, 0)
static var _overlay_cache := {}          # a held pose (paused player) standing in for a missing clip

func setup(char_id: String, tint := Color.WHITE, size := 1.0) -> void:
	id = char_id
	_body = Node3D.new()
	add_child(_body)
	var dir := "res://characters/%s/" % char_id
	var cfg := {}
	if FileAccess.file_exists(dir + "anims.json"):
		cfg = JSON.parse_string(FileAccess.get_file_as_string(dir + "anims.json"))
	var path := dir + char_id + ".glb"
	if ResourceLoader.exists(path):
		model = (load(path) as PackedScene).instantiate()
		yaw_offset = deg_to_rad(float(cfg.get("yaw", 180.0)))
	else:
		model = Mannequin.build(tint)
		yaw_offset = 0.0
	walk_speed = float(cfg.get("walk_speed", walk_speed))
	hand_bone = String(cfg.get("hand", hand_bone))
	model.scale = Vector3.ONE * float(cfg.get("scale", 1.0)) * size
	model.rotation.y = yaw_offset
	_body.add_child(model)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		_meshes.append(mi)
	ap = model.find_child("AnimationPlayer", true, false)
	if ap:
		_donate_clips(dir, char_id)
		_map_clips(cfg.get("clips", {}))
	play("idle", true)

## Clips from the other .glb files in the folder, added to this model's player.
func _donate_clips(dir: String, char_id: String) -> void:
	var da := DirAccess.open(dir)
	if da == null:
		return
	var lib: AnimationLibrary = ap.get_animation_library("")
	for f in da.get_files():
		f = f.trim_suffix(".remap").trim_suffix(".import")
		if not f.ends_with(".glb") or f == char_id + ".glb":
			continue
		var other: Node = (load(dir + f) as PackedScene).instantiate()
		var oap: AnimationPlayer = other.find_child("AnimationPlayer", true, false)
		if oap:
			for n in oap.get_animation_list():
				if not lib.has_animation(n):
					lib.add_animation(n, oap.get_animation(n))
		other.free()

func _map_clips(named: Dictionary) -> void:
	var names: Array = ap.get_animation_list()
	# Very short clips are usually export leftovers (a pose, not a motion).
	names = names.filter(func(n): return ap.get_animation(n).length > 0.2)
	for logical in LOGICAL:
		var want = named.get(logical, null)
		if want != null:
			clips[logical] = (want if want is Array else [want]).filter(func(n): return ap.has_animation(n))
			continue
		var found: Array = []
		for n in names:
			var low: String = n.to_lower()
			if KEYWORDS[logical].any(func(k): return low.contains(k)):
				if logical == "idle" and low.contains("combat"):
					continue
				found.append(n)
		clips[logical] = found
	for n in names:
		var a := ap.get_animation(n)
		if clips.get("walk", []).has(n) or clips.get("run", []).has(n) or clips.get("idle", []).has(n) or clips.get("ready", []).has(n):
			a.loop_mode = Animation.LOOP_LINEAR

var _weapon: Node3D

## Put equipment/<id>.glb in the right hand (hand.R bone); removes the old one. Silent if the
## model has no skeleton or the weapon has no model yet.
func attach_weapon(item_id: String) -> void:
	if _weapon:
		_weapon.queue_free()
		_weapon = null
	var path := "res://equipment/%s.glb" % item_id
	if item_id == "" or not ResourceLoader.exists(path):
		return
	var sk: Skeleton3D = model.find_child("Skeleton3D", true, false) if model else null
	if sk == null or sk.find_bone(hand_bone) < 0:
		return
	var att := BoneAttachment3D.new()
	sk.add_child(att)
	att.bone_name = hand_bone
	att.add_child((load(path) as PackedScene).instantiate())
	_weapon = att

var hand_bone := "hand.R"

## White pulse when hit.
func flash() -> void:
	_flash_t = 0.12
	_apply_overlay()

## Soft coloured tint (e.g. red for the enemy under the cursor); transparent clears it.
func highlight(c: Color) -> void:
	if c != _highlight:
		_highlight = c
		_apply_overlay()

func _apply_overlay() -> void:
	var c := Color(1, 1, 1, 0.55) if _flash_t > 0.0 else _highlight
	var mat: Material = null
	if c.a > 0.0:
		if not _overlay_cache.has(c):
			var m := StandardMaterial3D.new()
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.albedo_color = c
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			_overlay_cache[c] = m
		mat = _overlay_cache[c]
	for mi in _meshes:
		mi.material_overlay = mat

func has_clip(logical: String) -> bool:
	return not clips.get(logical, []).is_empty()

## Seconds a one-shot animation takes.
func duration(name: String) -> float:
	if has_clip(name):
		return ap.get_animation(clips[name][0]).length
	return {"attack": 0.45, "cast": 0.6, "shoot": 0.5, "hit": 0.25, "die": 0.8}.get(name, 0.5)

func play(name: String, restart := false) -> void:
	if name == anim and not restart:
		return
	anim = name
	_t = 0.0
	_procedural = ""
	_held = false
	_body.rotation = Vector3.ZERO
	_body.position = Vector3.ZERO
	var clip := _clip_for(name)
	if clip != "":
		ap.play(clip, 0.15)
		ap.speed_scale = 1.0
		if name == "die":
			ap.get_animation(clip).loop_mode = Animation.LOOP_NONE
		return
	# Fallbacks
	match name:
		"idle", "ready":
			# hold the walk's first frame (a near-standing pose); no blend, or a paused
			# player would freeze halfway from the bind pose
			if ap and has_clip("walk"):
				ap.play(clips.walk[0], 0.0)
				ap.seek(0.0, true)
				ap.pause()
				_held = true
				_pose_pending = true   # re-applied next frame: seeking before entering the tree doesn't stick
		"run":
			if ap and has_clip("walk"):
				ap.play(clips.walk[0], 0.15)
		"attack", "cast", "shoot":
			_procedural = "lunge"
		"hit":
			_procedural = "flinch"
		"die":
			_procedural = "fall"
			if ap:
				ap.speed_scale = 0.0

func _clip_for(name: String) -> String:
	if not has_clip(name):
		return ""
	var list: Array = clips[name]
	if name == "attack":
		_attack_n += 1
		return list[_attack_n % list.size()]
	return list[0]

func face(dir: Vector3) -> void:
	if Vector2(dir.x, dir.z).length_squared() > 0.0001:
		var target := atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, target, 0.35)

func _process(delta: float) -> void:
	if TacticalPause.paused:
		if ap:
			ap.pause()
		return
	if ap and not _held and not ap.is_playing() and ap.assigned_animation != "" and anim not in ["die"]:
		ap.play()
	_t += delta
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			_apply_overlay()
	if _pose_pending and ap:
		ap.seek(0.0, true)
		ap.pause()
		_pose_pending = false
	# walk/run playback follows ground speed so feet don't slide
	if ap and anim in ["walk", "run"] and has_clip("walk") and _clip_for_loop(anim) == clips.walk[0]:
		ap.speed_scale = clampf(move_speed / walk_speed, 0.4, 2.4)
	if anim in ["idle", "ready"] and not has_clip(anim):
		_body.scale = Vector3(1.0, 1.0 + sin(_t * 2.2) * 0.008, 1.0)   # breathing
	elif anim in ["walk", "run"] and not has_clip("walk"):
		_body.position.y = absf(sin(_t * (9.0 if anim == "walk" else 13.0))) * 0.06   # mannequin bob
	match _procedural:
		"lunge":
			var k := sin(clampf(_t / 0.45, 0.0, 1.0) * PI)
			_body.position = Vector3(0, 0, -0.35 * k)
			_body.rotation.x = -0.25 * k
		"flinch":
			var k := sin(clampf(_t / 0.25, 0.0, 1.0) * PI)
			_body.rotation.x = 0.18 * k
		"fall":
			var k := clampf(_t / 0.8, 0.0, 1.0)
			_body.rotation.x = lerpf(0.0, PI / 2.0, k * k)
			_body.position.y = -0.05 * k
	if anim in ONE_SHOT and _t >= duration(anim):
		if anim == "die":
			return
		var done := anim
		play("idle")
		finished.emit(done)

func _clip_for_loop(name: String) -> String:
	return clips[name][0] if has_clip(name) else (clips.walk[0] if has_clip("walk") else "")
