class_name WorldMap
extends RefCounted
## Renders a terrain overview image for a seed (cached), drawn north-up.

const SCALE := 2      # one map pixel per 2x2 cells
const COLORS := {
	WorldGen.Terrain.WATER: Color("16222c"), WorldGen.Terrain.MOOR: Color("6a6545"), WorldGen.Terrain.FOREST: Color("2e3e28"),
	WorldGen.Terrain.FEN: Color("3a4c40"), WorldGen.Terrain.HILLS: Color("7a7258"), WorldGen.Terrain.ROCK: Color("55524e"),
	WorldGen.Terrain.ROAD: Color("9a8662"), WorldGen.Terrain.ASHFIELD: Color("4a4642"),
}

static var _cache := {}

static func texture(world: WorldGen) -> ImageTexture:
	if _cache.has(world.seed_value):
		return _cache[world.seed_value]
	var n := WorldGen.SIZE / SCALE
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var c := Vector2i(x * SCALE, y * SCALE)
			var col: Color = COLORS[world.terrain_at(c)]
			# hill shading from the height field: lighter on slopes facing north-west
			var e := world.elevation(c.x, c.y)
			var slope := e - world.elevation(c.x + SCALE, c.y + SCALE)
			img.set_pixel(x, y, col.lightened(clampf(slope * 0.8, 0.0, 0.25)).darkened(clampf(-slope * 0.8, 0.0, 0.25)))
	for v in world.villages():
		for dx in range(-2, 3):
			for dy in range(-2, 3):
				img.set_pixel(clampi(v.center.x / SCALE + dx, 0, n - 1), clampi(v.center.y / SCALE + dy, 0, n - 1), Color("d8b060"))
	var tex := ImageTexture.create_from_image(img)
	_cache[world.seed_value] = tex
	return tex

## Transform that draws cell-space content north-up, fitted and centred inside rect r.
static func map_transform(r: Rect2) -> Transform2D:
	var size := float(WorldGen.SIZE)
	var k := minf(r.size.x, r.size.y) / size * 0.98
	var t := Transform2D(Vector2(k, 0), Vector2(0, k), Vector2.ZERO)
	t.origin = r.get_center() - Vector2(size, size) * k / 2.0
	return t
