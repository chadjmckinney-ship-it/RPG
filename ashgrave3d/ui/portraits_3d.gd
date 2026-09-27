class_name Portraits3D
extends Node
## Live portraits: each character gets a small SubViewport with its own World3D, a copy of its
## CharacterModel (the same .glb or stand-in it walks around with) and a camera framed on the head.
## Viewports re-render a few times a second rather than every frame.

const SIZE := 160
const REFRESH := 0.12      # seconds between renders

var _views := {}           # key -> {vp, model, t}

## The portrait texture for an actor (party member, villager, creature).
func texture_for(a: Actor) -> Texture2D:
	if a == null or a.body == null:
		return null
	return texture_of(a.body.id, a.body_tint, a.body_size)

func texture_of(model_id: String, tint := Color.WHITE, size := 1.0) -> Texture2D:
	var key := "%s|%s|%.2f" % [model_id, tint.to_html(), size]
	if not _views.has(key):
		_views[key] = _build(model_id, tint, size)
	return _views[key].vp.get_texture()

func _build(model_id: String, tint: Color, size: float) -> Dictionary:
	var vp := SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.52, 0.5)
	env.environment.ambient_light_energy = 0.55
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	vp.add_child(env)
	var key_light := DirectionalLight3D.new()
	key_light.light_color = Color(1.0, 0.88, 0.72)
	key_light.light_energy = 1.2
	vp.add_child(key_light)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color(0.55, 0.65, 0.95)
	rim.light_energy = 0.7
	vp.add_child(rim)
	var model := CharacterModel.new()
	vp.add_child(model)
	model.setup(model_id, tint, size)
	# frame the head: top of the body from its mesh bounds
	var top := 1.7 * size
	var found := false
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var box: AABB = mi.global_transform * mi.get_aabb()
		top = box.end.y if not found else maxf(top, box.end.y)
		found = true
	var face := Vector3(0, top - 0.14 * top / 1.7, 0)
	var cam := Camera3D.new()
	cam.fov = 30.0
	cam.near = 0.05
	vp.add_child(cam)
	var dist := 0.95 * top / 1.7
	# the model faces -Z; look at it from the front, a little to one side and above
	cam.look_at_from_position(face + Vector3(0.28 * dist, 0.06, -dist), face - Vector3(0, 0.05 * top / 1.7, 0))
	key_light.look_at_from_position(face + Vector3(1.0, 1.2, -1.2), face)
	rim.look_at_from_position(face + Vector3(-1.2, 0.6, 1.4), face)
	return {"vp": vp, "model": model, "t": 0.0}

func _process(delta: float) -> void:
	for k in _views:
		var v: Dictionary = _views[k]
		v.t -= delta
		if v.t <= 0.0:
			v.t = REFRESH
			v.vp.render_target_update_mode = SubViewport.UPDATE_ONCE

## Draw a portrait into a Control's rect (dark backing, greyed when downed).
func draw(c: CanvasItem, a: Actor, r: Rect2) -> void:
	c.draw_rect(r, Color(0.1, 0.085, 0.07))
	var tex := texture_for(a)
	if tex:
		c.draw_texture_rect(tex, r, false, Color(0.45, 0.45, 0.45) if a.downed else Color.WHITE)
