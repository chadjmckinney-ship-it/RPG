extends TestCase
## World art: the ground shader's cell maths, prop placement and the baked art files.

## GDScript mirror of terrain() in world/ground.gdshader.
static func shader_cell(p: Vector2) -> Vector2i:
	var u := (p.x - 64.0) / 64.0
	var v := (p.y - 32.0) / 32.0
	return Vector2i(roundi((u + v) * 0.5), roundi((v - u) * 0.5))

func test_shader_cell_maths_match_the_tilemap() -> void:
	var layer := TileMapLayer.new()
	layer.tile_set = TileArt.build_ground_set()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 300:
		var c := Vector2i(rng.randi_range(0, 511), rng.randi_range(0, 511))
		var centre := layer.map_to_local(c)
		check(shader_cell(centre) == c, "shader puts the centre of %s in %s" % [c, shader_cell(centre)])
		# points well inside the diamond agree with local_to_map too
		var p := centre + Vector2(rng.randf_range(-30, 30), rng.randf_range(-12, 12))
		check(shader_cell(p) == layer.local_to_map(p), "shader and tilemap disagree at %s" % p)
	layer.free()

func test_ground_fills_cover_every_terrain() -> void:
	var tex: Texture2D = load("res://art/world/ground.png")
	check(tex != null, "ground.png missing")
	if tex:
		check(tex.get_width() == 128 * WorldGen.Terrain.size() and tex.get_height() == 128, "ground.png has the wrong layout")
	var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://art/world/ground.json"))
	check(meta.order == ["water", "moor", "forest", "fen", "hills", "rock", "road", "ashfield"], "ground fills out of Terrain order")
	check(meta.order.size() == WorldGen.Terrain.size(), "fill count != terrain count")

func test_props_resolve_and_fit_the_atlas() -> void:
	var p := TileArt.props()
	var tex: Texture2D = load("res://art/world/props.png")
	check(tex != null, "props.png missing")
	var used := {}
	for list in WorldGen.TREES.values():
		for n in list: used[n] = true
	for d in WorldGen.DECOR.values():
		for n in d[1]: used[n] = true
	for kind in Settlements.CLUTTER:
		for e in Settlements.CLUTTER[kind]: used[e[1]] = true
	for n in GatherNode.ART.values():
		used[n] = true
	for n in used:
		check(p.props.has(n), "prop %s is placed but not baked" % n)
	for n in p.props:
		var r: Array = p.props[n]
		check(int(r[0]) % int(p.grid) == 0 and int(r[1]) % int(p.grid) == 0, "%s is off the atlas grid" % n)
		check(r[0] + r[2] <= tex.get_width() and r[1] + r[3] <= tex.get_height(), "%s runs past the atlas" % n)
		check(r[4] >= 0 and r[4] <= r[2] and r[5] >= 0 and r[5] <= r[3], "%s foot lies outside its sprite" % n)
	var ts := TileArt.build_prop_set()
	var src: TileSetAtlasSource = ts.get_source(0)
	for n in used:
		if p.props.has(n):
			check(src.has_tile(TileArt.prop_coords(n)), "no tile for %s" % n)
			check(src.get_alternative_tiles_count(TileArt.prop_coords(n)) == TileArt.JITTER.size(), "%s lacks jitter variants" % n)

func test_buildings_and_landmarks_have_art() -> void:
	for kind in Settlements.LAYOUT:
		check(ResourceLoader.exists("res://art/world/buildings/%s.png" % kind), "no art for %s" % kind)
		check(ResourceLoader.exists("res://art/world/buildings/%s_glow.png" % kind), "no window glow for %s" % kind)
	for kind in ["barrow", "chapel", "ashen"]:
		check(ResourceLoader.exists("res://art/world/landmarks/%s.png" % kind), "no art for landmark %s" % kind)

func test_prop_placement_is_deterministic_and_clear() -> void:
	var a := WorldGen.new(4242)
	var b := WorldGen.new(4242)
	var spawn := a.spawn_cell()
	check(a.prop_at(spawn) == "" or a.terrain_at(spawn) == WorldGen.Terrain.ROCK, "decor on the spawn cell")
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var seen := {}
	for i in 4000:
		var c := Vector2i(rng.randi_range(0, 511), rng.randi_range(0, 511))
		var p := a.prop_at(c)
		check(p == b.prop_at(c), "props disagree at %s" % c)
		if p != "":
			seen[p] = true
			check(a.structure_at(c).is_empty(), "prop %s inside a building at %s" % [p, c])
			if not a.has_tree(c):
				check(a.terrain_at(c) != WorldGen.Terrain.ROAD, "decor on the road at %s" % c)
	check(seen.size() > 10, "only %d kinds of prop appeared" % seen.size())
	for v in a.villages():
		for kind in Settlements.CLUTTER:
			for e in Settlements.CLUTTER[kind]:
				var c: Vector2i = v.center + Settlements.LAYOUT[kind] + e[0]
				check(a.prop_at(c) == e[1], "village clutter missing at %s" % c)
				check(a.structure_at(c).is_empty(), "clutter inside a building at %s" % c)
		for kind in Settlements.LAYOUT:
			check(a.walkable(Settlements.door_cell(v, kind)), "%s door blocked in %s" % [kind, v.name])

func test_terrain_map_matches_the_world() -> void:
	var w := WorldGen.new(77)
	var g := GroundRenderer.new()
	g.setup(w)
	var s := ChunkStreamer.new()
	var ground := TileMapLayer.new()
	var trees := TileMapLayer.new()
	s.setup(w, ground, trees, g)
	s.load_chunk(Vector2i(3, 4))
	for i in 200:
		var c := Vector2i(3 * 32 + (i * 7) % 32, 4 * 32 + (i * 13) % 32)
		check(g.stored(c) == w.terrain_at(c), "terrain map wrong at %s" % c)
		check((trees.get_cell_source_id(c) != -1) == (w.prop_at(c) != ""), "prop layer disagrees at %s" % c)
	for n in [g, s, ground, trees]:
		n.free()

func test_world_credits_cover_the_art() -> void:
	var txt := FileAccess.get_file_as_string("res://art/world/CREDITS_WORLD.txt")
	check(txt.contains("Eliza Wyatt"), "world credits missing")
	for folder in ["Terrain", "Structure/Structures", "Structure/Walls", "Structure/Pillars", "Objects/Furniture"]:
		check(txt.contains(folder), "credits missing folder %s" % folder)
	check(FileAccess.get_file_as_string("res://art/CREDITS.md").contains("ElizaWy/LPC"), "CREDITS.md doesn't mention the world art")
