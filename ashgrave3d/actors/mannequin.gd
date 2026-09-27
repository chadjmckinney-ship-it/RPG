class_name Mannequin
extends RefCounted
## Code-built stand-in body (about 1.7 m) for characters whose .glb hasn't arrived yet:
## capsule torso and legs, a head, a hood-like cap. Tinted per character or creature.

static func build(tint: Color) -> Node3D:
	var root := Node3D.new()
	root.name = "Mannequin"
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.78, 0.62, 0.5)
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = tint
	cloth.roughness = 0.9
	var dark := StandardMaterial3D.new()
	dark.albedo_color = tint.darkened(0.45)
	_part(root, _capsule(0.13, 0.85), Vector3(-0.1, 0.43, 0), dark)     # legs
	_part(root, _capsule(0.13, 0.85), Vector3(0.1, 0.43, 0), dark)
	_part(root, _capsule(0.24, 0.72), Vector3(0, 1.12, 0), cloth)       # torso
	_part(root, _capsule(0.07, 0.62), Vector3(-0.3, 1.1, 0), cloth)     # arms
	_part(root, _capsule(0.07, 0.62), Vector3(0.3, 1.1, 0), cloth)
	var head := SphereMesh.new()
	head.radius = 0.13
	head.height = 0.28
	_part(root, head, Vector3(0, 1.6, 0), skin)
	var nose := BoxMesh.new()             # shows which way it faces (-Z)
	nose.size = Vector3(0.05, 0.05, 0.08)
	_part(root, nose, Vector3(0, 1.6, -0.14), skin)
	return root

static func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	return c

static func _part(root: Node3D, mesh: Mesh, at: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = at
	root.add_child(mi)
