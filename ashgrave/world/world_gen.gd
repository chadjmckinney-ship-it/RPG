class_name WorldGen
extends RefCounted
## Seeded, pure-function world. Any cell's terrain depends only on (seed, cell),
## so chunks can be generated in any order and always agree at their borders.

enum Terrain { WATER, MOOR, FOREST, FEN, HILLS, ROCK, ROAD }

const CHUNK := 32
const WORLD_CHUNKS := 16
const SIZE := CHUNK * WORLD_CHUNKS  # 512 x 512 cells

const NAMES := {
	Terrain.WATER: "Black water", Terrain.MOOR: "Moor", Terrain.FOREST: "Blackwood",
	Terrain.FEN: "Fen", Terrain.HILLS: "Barrow hills", Terrain.ROCK: "Crag", Terrain.ROAD: "Old road",
}

var seed_value: int
var _height := FastNoiseLite.new()
var _moist := FastNoiseLite.new()
var _detail := FastNoiseLite.new()
var _roads := FastNoiseLite.new()

func _init(s: int) -> void:
	seed_value = s
	for n in [_height, _moist, _detail, _roads]:
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_height.seed = s
	_height.frequency = 0.012
	_height.fractal_octaves = 4
	_moist.seed = s + 101
	_moist.frequency = 0.02
	_detail.seed = s + 202
	_detail.frequency = 0.15
	_roads.seed = s + 303
	_roads.frequency = 0.006
	_roads.fractal_octaves = 1

func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < SIZE and c.y < SIZE

func terrain_at(c: Vector2i) -> int:
	if not in_bounds(c):
		return Terrain.WATER
	# Fall off toward the map edge so the province is ringed by water.
	var cx := (c.x - SIZE * 0.5) / (SIZE * 0.5)
	var cy := (c.y - SIZE * 0.5) / (SIZE * 0.5)
	var edge := clampf(maxf(absf(cx), absf(cy)), 0.0, 1.0)
	var h := _height.get_noise_2d(c.x, c.y) + 0.25 - pow(edge, 3.0) * 1.3
	if h < -0.28:
		return Terrain.WATER
	# Old imperial roads: thin bands along a zero-crossing of low-frequency noise.
	if absf(_roads.get_noise_2d(c.x, c.y)) < 0.012 and h < 0.5:
		return Terrain.ROAD
	if h > 0.62:
		return Terrain.ROCK if _detail.get_noise_2d(c.x, c.y) > 0.1 else Terrain.HILLS
	if h > 0.42:
		return Terrain.HILLS
	var m := _moist.get_noise_2d(c.x, c.y)
	if m > 0.28 and h < 0.05:
		return Terrain.FEN
	if m > 0.0:
		return Terrain.FOREST
	return Terrain.MOOR

func walkable(c: Vector2i) -> bool:
	var t := terrain_at(c)
	return t != Terrain.WATER and t != Terrain.ROCK

## Movement cost multiplier for pathing.
func cost(c: Vector2i) -> float:
	match terrain_at(c):
		Terrain.ROAD: return 0.7
		Terrain.FEN: return 2.0
		Terrain.FOREST: return 1.3
		Terrain.HILLS: return 1.5
	return 1.0

## Decorative trees, deterministic per cell.
func has_tree(c: Vector2i) -> bool:
	var t := terrain_at(c)
	if t != Terrain.FOREST and t != Terrain.FEN:
		return false
	var r := _hash01(c)
	return r < (0.28 if t == Terrain.FOREST else 0.06)

func spawn_cell() -> Vector2i:
	var center := Vector2i(SIZE / 2, SIZE / 2)
	for radius in range(0, SIZE / 2):
		for dx in range(-radius, radius + 1):
			for dy in [-radius, radius]:
				var c := center + Vector2i(dx, dy)
				if walkable(c) and walkable(c + Vector2i(1, 0)) and walkable(c + Vector2i(0, 1)):
					return c
	return center

func _hash01(c: Vector2i) -> float:
	var h := (c.x * 374761393 + c.y * 668265263 + seed_value * 2246822519) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float(h ^ (h >> 16)) / float(0x7fffffff)
