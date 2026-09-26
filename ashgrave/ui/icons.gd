class_name Icons
extends RefCounted
## Item icons baked by tools/import_ui.py into one atlas of 32x32 cells.

static var _meta: Dictionary = {}
static var _cache := {}

static func meta() -> Dictionary:
	if _meta.is_empty():
		_meta = JSON.parse_string(FileAccess.get_file_as_string("res://art/ui/icons.json"))
	return _meta

static func has(id: String) -> bool:
	return meta().icons.has(id)

## The icon for an item id, or null if it has none.
static func texture(id: String) -> AtlasTexture:
	if not has(id):
		return null
	if not _cache.has(id):
		var cell: int = meta().cell
		var p: Array = meta().icons[id]
		var t := AtlasTexture.new()
		t.atlas = load("res://art/ui/icons.png")
		t.region = Rect2(p[0], p[1], cell, cell)
		_cache[id] = t
	return _cache[id]

## A fixed-size TextureRect for lists (empty space when the item has no icon).
static func rect(id: String, size := 32) -> TextureRect:
	var r := TextureRect.new()
	r.texture = texture(id)
	r.custom_minimum_size = Vector2(size, size)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return r
