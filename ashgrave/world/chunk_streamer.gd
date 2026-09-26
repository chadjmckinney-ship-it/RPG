class_name ChunkStreamer
extends Node2D

signal chunk_loaded(ch: Vector2i)
signal chunk_unloaded(ch: Vector2i)
## Streams 32x32-cell chunks of ground and trees around a focus point.
## Loads a few chunks per frame to avoid hitches; unloads chunks out of range.

const RADIUS := 2          # chunks kept loaded around the focus
const LOADS_PER_FRAME := 2

var world: WorldGen
var ground: TileMapLayer
var trees: TileMapLayer
var loaded := {}           # Vector2i chunk -> true
var focus_cell := Vector2i.ZERO

func setup(w: WorldGen, ground_layer: TileMapLayer, tree_layer: TileMapLayer) -> void:
	world = w
	ground = ground_layer
	trees = tree_layer
	ground.tile_set = TileArt.build_ground_set()
	trees.tile_set = TileArt.build_tree_set()

func chunk_of(cell: Vector2i) -> Vector2i:
	return Vector2i(floori(cell.x / float(WorldGen.CHUNK)), floori(cell.y / float(WorldGen.CHUNK)))

func wanted() -> Array[Vector2i]:
	var center := chunk_of(focus_cell)
	var out: Array[Vector2i] = []
	for dy in range(-RADIUS, RADIUS + 1):
		for dx in range(-RADIUS, RADIUS + 1):
			var ch := center + Vector2i(dx, dy)
			if ch.x >= 0 and ch.y >= 0 and ch.x < WorldGen.WORLD_CHUNKS and ch.y < WorldGen.WORLD_CHUNKS:
				out.append(ch)
	# nearest first
	out.sort_custom(func(a, b): return (a - center).length_squared() < (b - center).length_squared())
	return out

## Loads everything needed immediately (used on spawn and in tests).
func load_all_now() -> void:
	for ch in wanted():
		if not loaded.has(ch):
			load_chunk(ch)

func _process(_delta: float) -> void:
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
	var base := ch * WorldGen.CHUNK
	for y in WorldGen.CHUNK:
		for x in WorldGen.CHUNK:
			var c := base + Vector2i(x, y)
			var t := world.terrain_at(c)
			ground.set_cell(c, 0, TileArt.ground_coords(t, (c.x * 7 + c.y * 13) & 0xff))
			if world.has_tree(c):
				trees.set_cell(c, 0, Vector2i((c.x + c.y) & 1, 0))
	loaded[ch] = true
	chunk_loaded.emit(ch)

func unload_chunk(ch: Vector2i) -> void:
	var base := ch * WorldGen.CHUNK
	for y in WorldGen.CHUNK:
		for x in WorldGen.CHUNK:
			var c := base + Vector2i(x, y)
			ground.erase_cell(c)
			trees.erase_cell(c)
	loaded.erase(ch)
	chunk_unloaded.emit(ch)
