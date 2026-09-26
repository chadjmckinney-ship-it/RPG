class_name TileArt
extends RefCounted
## Placeholder art painted at runtime: isometric ground diamonds and trees.
## Swap for real sprite sheets later by replacing build_ground_set/build_tree_set.

const TW := 64
const TH := 32
const VARIANTS := 3

const GROUND := {
	WorldGen.Terrain.WATER: [Color("1c2a36"), Color("24384a")],
	WorldGen.Terrain.MOOR: [Color("5d5a3c"), Color("6e6a46")],
	WorldGen.Terrain.FOREST: [Color("2c3a26"), Color("35462d")],
	WorldGen.Terrain.FEN: [Color("3a4a3a"), Color("2d3d38")],
	WorldGen.Terrain.HILLS: [Color("6b6450"), Color("7a725b")],
	WorldGen.Terrain.ROCK: [Color("4a4848"), Color("5c5a58")],
	WorldGen.Terrain.ROAD: [Color("7d6b52"), Color("8e7b60")],
	WorldGen.Terrain.ASHFIELD: [Color("4a4642"), Color("3a3634")],
}

static func _in_diamond(x: int, y: int) -> bool:
	return absf(x - TW / 2.0 + 0.5) / (TW / 2.0) + absf(y - TH / 2.0 + 0.5) / (TH / 2.0) <= 1.0

## Atlas column = terrain, row = variant.
static func build_ground_set() -> TileSet:
	var terrains := GROUND.keys()
	var img := Image.create(TW * terrains.size(), TH * VARIANTS, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	for ti in terrains.size():
		var cols: Array = GROUND[terrains[ti]]
		for v in VARIANTS:
			rng.seed = ti * 31 + v
			for y in TH:
				for x in TW:
					if not _in_diamond(x, y):
						continue
					var c: Color = cols[0]
					var r := rng.randf()
					if r < 0.18:
						c = cols[1]
					elif r < 0.24:
						c = cols[0].darkened(0.15)
					# Soft edge shading gives the diamonds some volume.
					if y > TH * 0.5 + absf(x - TW * 0.5) * 0.5 - 2:
						c = c.darkened(0.12)
					img.set_pixel(ti * TW + x, v * TH + y, c)
	var ts := TileSet.new()
	ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	ts.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	ts.tile_size = Vector2i(TW, TH)
	var src := TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(img)
	src.texture_region_size = Vector2i(TW, TH)
	for ti in terrains.size():
		for v in VARIANTS:
			src.create_tile(Vector2i(ti, v))
	ts.add_source(src, 0)
	return ts

static func ground_coords(terrain: int, variant: int) -> Vector2i:
	return Vector2i(GROUND.keys().find(terrain), variant % VARIANTS)

## Dead, leaning blackwood trees. Tile is taller than a cell; origin sits at the trunk base.
static func build_tree_set() -> TileSet:
	var w := 64
	var h := 96
	var img := Image.create(w * 2, h, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	for k in 2:
		rng.seed = 900 + k
		var ox := k * w
		# shadow
		for y in range(84, 92):
			for x in range(14, 50):
				if pow((x - 32) / 18.0, 2) + pow((y - 88) / 4.0, 2) <= 1.0:
					img.set_pixel(ox + x, y, Color(0, 0, 0, 0.35))
		# trunk
		for y in range(40, 90):
			var lean := int((90 - y) * (0.08 if k == 0 else -0.06))
			for x in range(29, 35):
				img.set_pixel(ox + x + lean, y, Color("2a2119") if x < 32 else Color("3a2e22"))
		# canopy: clustered dark blobs
		var canopy := [Color("1b2618"), Color("243320"), Color("2e3f27")]
		for i in 26:
			var cx := 32 + rng.randi_range(-18, 18)
			var cy := 30 + rng.randi_range(-22, 16)
			var r := rng.randi_range(6, 11)
			var col: Color = canopy[i % 3]
			for y in range(cy - r, cy + r):
				for x in range(cx - r, cx + r):
					if x >= 0 and x < w and y >= 0 and y < h and pow(x - cx, 2) + pow(y - cy, 2) <= r * r:
						img.set_pixel(ox + x, y, col)
	var ts := TileSet.new()
	ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	ts.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	ts.tile_size = Vector2i(TW, TH)
	var src := TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(img)
	src.texture_region_size = Vector2i(w, h)
	for k in 2:
		src.create_tile(Vector2i(k, 0))
		var data := src.get_tile_data(Vector2i(k, 0), 0)
		data.texture_origin = Vector2i(0, 32)  # lift so trunk base sits on the cell centre
		data.y_sort_origin = 0
	ts.add_source(src, 0)
	return ts
