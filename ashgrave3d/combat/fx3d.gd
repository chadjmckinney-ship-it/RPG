class_name Fx3D
extends Node3D
## Short-lived combat effects: arrow/bolt tracers, ground rings, heal glows, a volley of arrows.
## Everything fades itself out; all of it pauses with the tactical pause.

var _items: Array = []     # {node, t, life, kind, data}

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = c
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

## A thin streak from a to b that fades (arrows, bolts, spell shots).
func tracer(a: Vector3, b: Vector3, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.025
	cyl.bottom_radius = 0.025
	cyl.height = 1.0
	cyl.radial_segments = 4
	mi.mesh = cyl
	mi.material_override = _mat(c)
	add_child(mi)
	var mid := (a + b) / 2.0
	var dir := b - a
	mi.global_position = mid
	if dir.length() > 0.01:
		mi.look_at(b, Vector3.UP if absf(dir.normalized().y) < 0.99 else Vector3.RIGHT)
		mi.rotate_object_local(Vector3.RIGHT, PI / 2.0)
	mi.scale = Vector3(1, dir.length(), 1)
	_items.append({"node": mi, "t": 0.0, "life": 0.25})

## A flat ring on the ground that expands and fades (snares, cleaves, area spells).
func ring(at: Vector3, radius: float, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.9
	t.outer_radius = 1.0
	t.rings = 32
	mi.mesh = t
	mi.material_override = _mat(c)
	add_child(mi)
	mi.global_position = at + Vector3(0, 0.08, 0)
	_items.append({"node": mi, "t": 0.0, "life": 0.6, "kind": "ring", "r": radius})

## A soft column of light (heals, guard, Sanctuary).
func glow(at: Vector3, c: Color, radius := 0.6) -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = 2.4 if radius < 1.0 else 1.0
	cyl.cap_top = false
	cyl.cap_bottom = false
	mi.mesh = cyl
	mi.material_override = _mat(Color(c.r, c.g, c.b, 0.35))
	add_child(mi)
	mi.global_position = at + Vector3(0, cyl.height / 2.0, 0)
	_items.append({"node": mi, "t": 0.0, "life": 0.7, "kind": "glow"})

## Several arrows falling on an area.
func volley(from: Vector3, at: Vector3, radius: float) -> void:
	for i in 7:
		var off := Vector3(randf_range(-radius, radius), 0, randf_range(-radius, radius)) * 0.8
		tracer(at + off + Vector3(randf_range(-0.6, 0.6), 4.0, randf_range(-0.6, 0.6)), at + off, Color(0.9, 0.85, 0.7))

func _process(delta: float) -> void:
	if TacticalPause.paused:
		return
	for it in _items:
		it.t += delta
		var k: float = it.t / it.life
		var n: MeshInstance3D = it.node
		var m: StandardMaterial3D = n.material_override
		m.albedo_color.a = (1.0 - k) * (0.22 if it.get("kind") == "glow" else 0.9)
		if it.get("kind") == "ring":
			var r: float = it.r * (0.4 + 0.6 * k)
			n.scale = Vector3(r, 0.04, r)
		if it.t >= it.life:
			n.queue_free()
	_items = _items.filter(func(it): return it.t < it.life)
