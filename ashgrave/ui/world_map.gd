class_name WorldMap
extends RefCounted
## Renders a terrain overview image for a seed (cached), drawn isometrically to match the view.

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
			img.set_pixel(x, y, col)
	for v in world.villages():
		for dx in range(-2, 3):
			for dy in range(-2, 3):
				img.set_pixel(clampi(v.center.x / SCALE + dx, 0, n - 1), clampi(v.center.y / SCALE + dy, 0, n - 1), Color("d8b060"))
	var tex := ImageTexture.create_from_image(img)
	_cache[world.seed_value] = tex
	return tex

## Transform that draws cell-space content isometrically inside rect r.
static func iso_transform(r: Rect2) -> Transform2D:
	var size := float(WorldGen.SIZE)
	var k := minf(r.size.x / (2.0 * size), r.size.y / size) * 0.98
	# cell (x,y) -> ((x - y) * k, (x + y) * k/2), centred in r
	var t := Transform2D(Vector2(k, k * 0.5), Vector2(-k, k * 0.5), Vector2.ZERO)
	var center := t * Vector2(size / 2.0, size / 2.0)
	t.origin = r.get_center() - center
	return t
