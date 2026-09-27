class_name Shapes
extends RefCounted
## Tiny helpers for stand-in scenery built from primitives (gather nodes, landmarks).

static var _mats := {}

static func mat(c: Color, emissive := 0.0) -> StandardMaterial3D:
	var key := [c, emissive]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.9
		if emissive > 0.0:
			m.emission_enabled = true
			m.emission = c
			m.emission_energy_multiplier = emissive
		_mats[key] = m
	return _mats[key]

static func add(parent: Node3D, mesh: Mesh, pos: Vector3, c: Color, scale := Vector3.ONE, rot := Vector3.ZERO, emissive := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.scale = scale
	mi.rotation = rot
	mi.material_override = mat(c, emissive)
	parent.add_child(mi)
	return mi

static func cyl(r_top: float, r_bot: float, h: float, seg := 8) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = r_top
	m.bottom_radius = r_bot
	m.height = h
	m.radial_segments = seg
	m.rings = 1
	return m

static func sphere(r: float, seg := 10) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = seg
	m.rings = seg / 2
	return m

static func box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m

static func prism(size: Vector3) -> PrismMesh:
	var m := PrismMesh.new()
	m.size = size
	return m
