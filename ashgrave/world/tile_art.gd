class_name TileArt
extends RefCounted
## World art from tools/import_world.py (Eliza Wyatt's revised LPC set).
## The ground is painted by GroundRenderer; this builds the prop tile set (trees, rocks,
## plants, village clutter) and a transparent ground set that only serves map maths.

const SCALE := 2          # art is authored at 1x and drawn at 2x with nearest filtering
const JITTER := [Vector2i(0, 0), Vector2i(-18, 4), Vector2i(16, -6)]   # screen px, per alternative

static var _props: Dictionary = {}

static func props() -> Dictionary:
	if _props.is_empty():
		_props = JSON.parse_string(FileAccess.get_file_as_string("res://art/world/props.json"))
	return _props

static var _upscaled := {}

## The texture at SCALE x (cached: get_image() can hand back the texture's own image, so copy it).
static func upscaled(path: String) -> ImageTexture:
	if not _upscaled.has(path):
		var img: Image = load(path).get_image().duplicate()
		img.decompress()
		img.resize(img.get_width() * SCALE, img.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
		_upscaled[path] = ImageTexture.create_from_image(img)
	return _upscaled[path]

## Invisible 1-tile set: the Ground layer stays for map_to_local / local_to_map and tests.
static func build_ground_set() -> TileSet:
	var ts := _iso_set()
	var src := TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(Image.create(WorldGen.TILE_W, WorldGen.TILE_H, false, Image.FORMAT_RGBA8))
	src.texture_region_size = Vector2i(WorldGen.TILE_W, WorldGen.TILE_H)
	src.create_tile(Vector2i.ZERO)
	ts.add_source(src, 0)
	return ts

static func ground_coords(_terrain: int, _variant: int) -> Vector2i:
	return Vector2i.ZERO

## Every prop becomes one atlas tile anchored at its foot, plus jittered alternatives.
static func build_prop_set() -> TileSet:
	var ts := _iso_set()
	var src := TileSetAtlasSource.new()
	var grid: int = props().grid
	src.texture = upscaled("res://art/world/props.png")
	src.texture_region_size = Vector2i(grid * SCALE, grid * SCALE)
	var items: Dictionary = props().props
	for name in items:
		var r: Array = items[name]
		var coords := Vector2i(int(r[0]) / grid, int(r[1]) / grid)
		src.create_tile(coords, Vector2i(int(r[2]) / grid, int(r[3]) / grid))
		# The tile's centre is drawn on the cell centre; shift so the foot lands there instead.
		var origin := Vector2i((int(r[4]) - int(r[2]) / 2) * SCALE, (int(r[5]) - int(r[3]) / 2) * SCALE)
		for i in JITTER.size():
			var alt := 0 if i == 0 else src.create_alternative_tile(coords)
			var data := src.get_tile_data(coords, alt)
			data.texture_origin = origin - JITTER[i]
			data.y_sort_origin = JITTER[i].y
	ts.add_source(src, 0)
	return ts

static func prop_coords(name: String) -> Vector2i:
	var r: Array = props().props[name]
	var grid: int = props().grid
	return Vector2i(int(r[0]) / grid, int(r[1]) / grid)

## An AtlasTexture for one prop at 1x (for Sprite2D users such as gather nodes).
static func prop_texture(name: String) -> AtlasTexture:
	var r: Array = props().props[name]
	var t := AtlasTexture.new()
	t.atlas = load("res://art/world/props.png")
	t.region = Rect2(r[0], r[1], r[2], r[3])
	return t

## Foot position inside prop_texture(name), at 1x.
static func prop_foot(name: String) -> Vector2:
	var r: Array = props().props[name]
	return Vector2(r[4], r[5])

static func _iso_set() -> TileSet:
	var ts := TileSet.new()
	ts.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	ts.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	ts.tile_size = Vector2i(WorldGen.TILE_W, WorldGen.TILE_H)
	return ts
