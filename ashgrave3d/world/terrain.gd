class_name Terrain
extends Node3D
## Streams the seeded world around a focus cell as 3D chunks: a ground mesh (vertex colours per
## biome, heights from WorldGen.elevation), stand-in trees and rocks (MultiMesh), stand-in houses.
## One vertex per cell centre; neighbouring chunks share their edge row, so there are no seams.

signal chunk_loaded(ch: Vector2i)
signal chunk_unloaded(ch: Vector2i)

const RADIUS := 2
const LOADS_PER_FRAME := 1

const COLORS := {
	WorldGen.Terrain.WATER: Color("2e3438"), WorldGen.Terrain.MOOR: Color("5e5a38"),
	WorldGen.Terrain.FOREST: Color("2f3e24"), WorldGen.Terrain.FEN: Color("37432f"),
	WorldGen.Terrain.HILLS: Color("535a3c"), WorldGen.Terrain.ROCK: Color("58544f"),
	WorldGen.Terrain.ROAD: Color("5e5040"), WorldGen.Terrain.ASHFIELD: Color("3a3735"),
}

var world: WorldGen
var focus_cell := Vector2i.ZERO
var loaded := {}          # chunk -> Node3D
var _ground_mat: ShaderMaterial
var _meshes := {}         # prop kind -> Mesh
## Shared by every stand-in prop; main.gd feeds it the party's positions (see prop.gdshader).
var prop_material := ShaderMaterial.new()

func setup(w: WorldGen) -> void:
	world = w
	var noise := FastNoiseLite.new()
	noise.seed = w.seed_value
	noise.frequency = 0.03
	noise.fractal_octaves = 3
	var ntex := ImageTexture.create_from_image(noise.get_seamless_image(256, 256))
	_ground_mat = ShaderMaterial.new()
	_ground_mat.shader = preload("res://world/terrain.gdshader")
	_ground_mat.set_shader_parameter("noise", ntex)
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	var span := WorldGen.SIZE * WorldGen.CELL
	plane.size = Vector2(span + 400.0, span + 400.0)
	water.mesh = plane
	water.position = Vector3(span / 2.0, WorldGen.SEA_Y - 0.05, span / 2.0)
	var wm := ShaderMaterial.new()
	wm.shader = preload("res://world/water.gdshader")
	wm.set_shader_parameter("noise", ntex)
	water.material_override = wm
	water.name = "Water"
	add_child(water)
	prop_material.shader = preload("res://world/prop.gdshader")
	_build_prop_meshes()

func chunk_of(c: Vector2i) -> Vector2i:
	return Vector2i(floori(c.x / float(WorldGen.CHUNK)), floori(c.y / float(WorldGen.CHUNK)))

func wanted() -> Array[Vector2i]:
	var center := chunk_of(focus_cell)
	var out: Array[Vector2i] = []
	for dy in range(-RADIUS, RADIUS + 1):
		for dx in range(-RADIUS, RADIUS + 1):
			var ch := center + Vector2i(dx, dy)
			if ch.x >= 0 and ch.y >= 0 and ch.x < WorldGen.WORLD_CHUNKS and ch.y < WorldGen.WORLD_CHUNKS:
				out.append(ch)
	out.sort_custom(func(a, b): return (a - center).length_squared() < (b - center).length_squared())
	return out

func load_all_now() -> void:
	for ch in wanted():
		if not loaded.has(ch):
			load_chunk(ch)

func _process(_d: float) -> void:
	if world == null:
		return
	var want := wanted()
	var budget := LOADS_PER_FRAME
	for ch in want:
		if budget == 0:
			break
		if not loaded.has(ch):
			load_chunk(ch)
			budget -= 1
	for ch in loaded.keys():
		if not want.has(ch):
			unload_chunk(ch)

func load_chunk(ch: Vector2i) -> void:
	var node := Node3D.new()
	node.name = "Chunk_%d_%d" % [ch.x, ch.y]
	var ground := MeshInstance3D.new()
	ground.mesh = _ground_mesh(ch)
	ground.material_override = _ground_mat
	node.add_child(ground)
	_add_props(node, ch)
	add_child(node)
	loaded[ch] = node
	chunk_loaded.emit(ch)

func unload_chunk(ch: Vector2i) -> void:
	loaded[ch].queue_free()
	loaded.erase(ch)
	chunk_unloaded.emit(ch)

# ---------------------------------------------------------------- ground

func _ground_mesh(ch: Vector2i) -> ArrayMesh:
	var n := WorldGen.CHUNK + 1
	var base := ch * WorldGen.CHUNK
	var heights := PackedFloat32Array()
	heights.resize((n + 2) * (n + 2))
	# one extra ring for normals
	for j in n + 2:
		for i in n + 2:
			heights[j * (n + 2) + i] = world.elevation(base.x + i - 1, base.y + j - 1)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var cs := WorldGen.CELL
	for j in n:
		for i in n:
			var h := heights[(j + 1) * (n + 2) + (i + 1)]
			var hl := heights[(j + 1) * (n + 2) + i]
			var hr := heights[(j + 1) * (n + 2) + i + 2]
			var hu := heights[j * (n + 2) + i + 1]
			var hd := heights[(j + 2) * (n + 2) + i + 1]
			var c := base + Vector2i(i, j)
			verts.append(Vector3((c.x + 0.5) * cs, h, (c.y + 0.5) * cs))
			norms.append(Vector3(hl - hr, 2.0 * cs, hu - hd).normalized())
			cols.append(COLORS[world.terrain_at(c)])
	var idx := PackedInt32Array()
	for j in n - 1:
		for i in n - 1:
			var a := j * n + i
			idx.append_array([a, a + 1, a + n, a + 1, a + n + 1, a + n])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

# ---------------------------------------------------------------- stand-in props

## Stand-in shape for each prop name WorldGen.prop_at can return.
static func prop_kind(name: String) -> String:
	if name.begins_with("pine"):
		return "pine"
	if name.begins_with("oak"):
		return "oak"
	if name == "dead_tree":
		return "dead"
	if name.begins_with("boulder"):
		return "boulder"
	if name.begins_with("rock") or name == "pebbles":
		return "rock"
	if name in ["bush", "shrub", "leafy", "leafy_b", "fern", "fern_big"]:
		return "bush"
	if name.contains("stump"):
		return "stump"
	if name.begins_with("reeds") or name == "cattail" or name.begins_with("grass_tuft"):
		return "reeds"
	if name in ["barrel", "barrels", "crate", "crate_b", "trough", "anvil", "coal", "sawhorse", "lamp", "cauldron"]:
		return "crate"
	return ""

func _build_prop_meshes() -> void:
	_meshes.pine = _combine([[_cyl(0.12, 0.16, 1.4), Vector3(0, 0.7, 0), Color("4a3626")], [_cone(1.0, 3.2), Vector3(0, 2.8, 0), Color("22361f")], [_cone(0.8, 2.2), Vector3(0, 3.9, 0), Color("27402a")]])
	_meshes.oak = _combine([[_cyl(0.16, 0.22, 2.0), Vector3(0, 1.0, 0), Color("4a3828")], [_sphere(1.5), Vector3(0, 3.0, 0), Color("33492a")], [_sphere(1.0), Vector3(0.6, 3.6, 0.3), Color("3b5430")]])
	_meshes.dead = _combine([[_cyl(0.1, 0.18, 3.2), Vector3(0, 1.6, 0), Color("3a3129")], [_cyl(0.05, 0.07, 1.4), Vector3(0.45, 2.6, 0), Color("3a3129")]])
	_meshes.boulder = _combine([[_sphere(1.1), Vector3(0, 0.5, 0), Color("6a6660")]])
	_meshes.rock = _combine([[_sphere(0.35), Vector3(0, 0.12, 0), Color("6e6a64")]])
	_meshes.bush = _combine([[_sphere(0.5), Vector3(0, 0.35, 0), Color("34472b")]])
	_meshes.stump = _combine([[_cyl(0.28, 0.32, 0.45), Vector3(0, 0.22, 0), Color("3d3027")]])
	_meshes.reeds = _combine([[_cone(0.25, 0.9), Vector3(0, 0.45, 0), Color("6e6a3c")]])
	_meshes.crate = _combine([[_box(Vector3(0.6, 0.6, 0.6)), Vector3(0, 0.3, 0), Color("6a4c30")]])
	_meshes.house_wall = _combine([[_box(Vector3(1, 1, 1)), Vector3(0, 0.5, 0), Color("8a8074")]])
	_meshes.house_roof = _combine([[_prism(), Vector3(0, 0, 0), Color("3a3432")]])

func _add_props(node: Node3D, ch: Vector2i) -> void:
	var per_kind := {}
	var base := ch * WorldGen.CHUNK
	for y in WorldGen.CHUNK:
		for x in WorldGen.CHUNK:
			var c := base + Vector2i(x, y)
			var p := world.prop_at(c)
			if p == "":
				continue
			var kind := prop_kind(p)
			if kind == "":
				continue
			var h := world._hash01(c + Vector2i(31, 7))
			var t := Transform3D(Basis(Vector3.UP, h * TAU).scaled(Vector3.ONE * (0.8 + 0.45 * h)),
				world.cell_to_world(c) + Vector3((h - 0.5) * 0.6, 0, (world._hash01(c) - 0.5) * 0.6))
			if not per_kind.has(kind):
				per_kind[kind] = []
			per_kind[kind].append(t)
	for kind in per_kind:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _meshes[kind]
		mm.instance_count = per_kind[kind].size()
		for i in per_kind[kind].size():
			mm.set_instance_transform(i, per_kind[kind][i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.name = kind
		node.add_child(mmi)
	# village houses: a box with a gable roof over each building footprint
	for v in world.villages():
		if chunk_of(v.center) != ch:
			continue
		for kind in Settlements.LAYOUT:
			var a: Vector2i = Settlements.building_cell(v, kind)
			var f: int = Settlements.FOOT[kind]
			var c0 := world.cell_to_world(a)
			var c1 := world.cell_to_world(a + Vector2i(f - 1, f - 1))
			var centre := (c0 + c1) / 2.0
			var size := Vector3(f * WorldGen.CELL * 0.95, 2.6 if kind != "tavern" else 3.2, f * WorldGen.CELL * 0.95)
			var y0 := minf(c0.y, c1.y) - 0.3
			var wall := MeshInstance3D.new()
			wall.mesh = _meshes.house_wall
			wall.material_override = prop_material
			wall.transform = Transform3D(Basis.from_scale(size + Vector3(0, 0.3, 0)), Vector3(centre.x, y0, centre.z))
			wall.name = kind
			node.add_child(wall)
			var roof := MeshInstance3D.new()
			roof.mesh = _meshes.house_roof
			roof.transform = Transform3D(Basis.from_scale(Vector3(size.x * 1.15, size.y * 0.6, size.z * 1.1)), Vector3(centre.x, y0 + size.y + 0.3, centre.z))
			node.add_child(roof)

# ---------------------------------------------------------------- mesh helpers

func _cyl(r_top: float, r_bot: float, h: float) -> Mesh:
	var m := CylinderMesh.new()
	m.top_radius = r_top
	m.bottom_radius = r_bot
	m.height = h
	m.radial_segments = 8
	m.rings = 1
	return m

func _cone(r: float, h: float) -> Mesh:
	return _cyl(0.0, r, h)

func _sphere(r: float) -> Mesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 1.7
	m.radial_segments = 10
	m.rings = 6
	return m

func _box(size: Vector3) -> Mesh:
	var m := BoxMesh.new()
	m.size = size
	return m

## Unit gable roof: ridge along X, from y 0 to 1, spanning -0.5..0.5.
func _prism() -> Mesh:
	var m := PrismMesh.new()
	m.size = Vector3(1, 1, 1)
	var st := SurfaceTool.new()
	st.create_from(m, 0)
	var arr := st.commit_to_arrays()
	# PrismMesh points along +Y with its ridge on X already; shift so the base is at y 0.
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	for i in v.size():
		v[i] += Vector3(0, 0.5, 0)
	arr[Mesh.ARRAY_VERTEX] = v
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return out

## Merge [mesh, offset, colour] parts into one vertex-coloured mesh with a shared material.
func _combine(parts: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in parts:
		var src := SurfaceTool.new()
		src.create_from(p[0], 0)
		var arr := src.commit_to_arrays()
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var order := idx if idx.size() > 0 else PackedInt32Array(range(v.size()))
		for i in order:
			st.set_color(p[2])
			st.set_normal(nrm[i])
			st.add_vertex(v[i] + p[1])
	st.set_material(prop_material)
	return st.commit()
