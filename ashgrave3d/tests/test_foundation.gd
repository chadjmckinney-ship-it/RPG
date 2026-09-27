extends TestCase
## N1: world height and coordinates, terrain chunks, character models, party movement.

func test_coordinates_round_trip() -> void:
	var w := WorldGen.new(4242)
	for c in [Vector2i(0, 0), Vector2i(17, 300), Vector2i(511, 511), w.spawn_cell()]:
		var p := w.cell_to_world(c)
		check(w.world_to_cell(p) == c, "cell %s -> %s -> %s" % [c, p, w.world_to_cell(p)])
		check(absf(p.y - maxf(w.elevation(c.x, c.y), WorldGen.SEA_Y)) < 0.001, "cell height mismatch at %s" % c)

func test_water_lies_below_sea_level() -> void:
	var w := WorldGen.new(77)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 2000:
		var c := Vector2i(rng.randi_range(0, 511), rng.randi_range(0, 511))
		var t := w.terrain_at(c)
		if t == WorldGen.Terrain.WATER:
			check(w.elevation(c.x, c.y) < 0.0, "water above sea at %s" % c)
		elif w.walkable(c):
			check(w.elevation(c.x, c.y) >= -0.01, "walkable land under water at %s" % c)

func test_terrain_chunks_share_edges() -> void:
	var w := WorldGen.new(5)
	var t := Terrain.new()
	t.setup(w)
	var a: ArrayMesh = t._ground_mesh(Vector2i(4, 4))
	var b: ArrayMesh = t._ground_mesh(Vector2i(5, 4))
	var va: PackedVector3Array = a.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var vb: PackedVector3Array = b.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var n := WorldGen.CHUNK + 1
	check(va.size() == n * n, "chunk should have %d vertices, has %d" % [n * n, va.size()])
	for j in n:
		check(va[j * n + n - 1].is_equal_approx(vb[j * n]), "seam mismatch on row %d" % j)
	t.free()

func test_character_model_maps_clips() -> void:
	var m := CharacterModel.new()
	tree.root.add_child(m)
	m.setup("maren")
	check(m.ap != null, "Maren's glb has no AnimationPlayer")
	check(m.has_clip("walk"), "walk clip not found: %s" % [m.clips])
	check(not m.clips.walk.has("Walking_Woman2"), "the 2-frame pose clip was mapped as a walk")
	m.play("attack", true)
	check(m._procedural == "lunge", "missing attack clip should fall back to a lunge")
	m.queue_free()
	var stand := CharacterModel.new()
	tree.root.add_child(stand)
	stand.setup("no_such_character", Color.RED)
	check(stand.model.name == "Mannequin" and stand.ap == null, "missing model should use the mannequin")
	stand.queue_free()

func test_party_walks_in_3d() -> void:
	GameState.reset()
	GameState.recruited = ["maren", "oswin", "ketta"]
	var main: Node = load("res://main.tscn").instantiate()
	tree.root.add_child(main)
	await tree.process_frame
	check(main.party.members.size() == 3, "expected three members")
	var lead: PartyMember = main.party.members[0]
	check(absf(lead.position.y - main.world.cell_to_world(lead.cell).y) < 0.01, "leader not standing on the ground")
	main.party.select(main.party.members.duplicate())
	var goal: Vector2i = main.party.free_near(lead.cell + Vector2i(6, 2), {})
	check(main.party.order_move_to(goal) == 3, "not everyone got a path")
	var start := lead.cell
	for i in 180:
		await tree.process_frame
	check(lead.cell != start, "leader didn't move")
	check(lead.body.anim in ["walk", "run", "idle"], "unexpected animation %s" % lead.body.anim)
	main.queue_free()
	await tree.process_frame
	GameState.reset()
