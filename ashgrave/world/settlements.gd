class_name Settlements
extends RefCounted
## Seeded villages: one attempt per 4x4-chunk region, on open moor or road ground.
## Each has a tavern, a forge, two houses, an owning faction and a generated name.

const REGION := 4 * WorldGen.CHUNK   # 128 cells
const CLEAR_RADIUS := 7              # no trees or camps this close to a village centre
## Building anchor offsets from the centre. Each building covers a 2x2 block of cells.
const LAYOUT := {"tavern": Vector2i(-4, -4), "forge": Vector2i(3, -4), "house_a": Vector2i(-4, 3), "house_b": Vector2i(3, 3)}
const FACTIONS := ["church", "companies", "hollow"]
const NAME_A := ["Ash", "Grey", "Barrow", "Mire", "Thorn", "Cold", "Hollow", "Rook", "Wen", "Gallow", "Sallow", "Crow"]
const NAME_B := ["ford", "wick", "stead", "mere", "holt", "cross", "fen", "moor", "dale", "hythe"]

static func generate(world: WorldGen) -> Array:
	var out: Array = []
	var regions := WorldGen.SIZE / REGION
	for ry in regions:
		for rx in regions:
			var rng := RandomNumberGenerator.new()
			rng.seed = hash([world.seed_value, rx, ry, "village"])
			for attempt in 30:
				var c := Vector2i(rx * REGION + rng.randi_range(16, REGION - 16), ry * REGION + rng.randi_range(16, REGION - 16))
				if _site_ok(world, c):
					out.append({
						"id": "v%d_%d" % [rx, ry], "center": c,
						"name": NAME_A[rng.randi() % NAME_A.size()] + NAME_B[rng.randi() % NAME_B.size()],
						"faction": FACTIONS[rng.randi() % FACTIONS.size()],
					})
					break
	return out

static func _site_ok(world: WorldGen, c: Vector2i) -> bool:
	var t := world.terrain_at(c)
	if t != WorldGen.Terrain.MOOR and t != WorldGen.Terrain.ROAD:
		return false
	for dx in range(-6, 7):
		for dy in range(-6, 7):
			var n := world.terrain_at(c + Vector2i(dx, dy))
			if n == WorldGen.Terrain.WATER or n == WorldGen.Terrain.ROCK:
				return false
	return true

## cell -> {"village": id, "kind": building}
static func structure_cells(villages: Array) -> Dictionary:
	var out := {}
	for v in villages:
		for kind in LAYOUT:
			var a: Vector2i = v.center + LAYOUT[kind]
			for dx in 2:
				for dy in 2:
					out[a + Vector2i(dx, dy)] = {"village": v.id, "kind": kind}
	return out

static func building_cell(v: Dictionary, kind: String) -> Vector2i:
	return v.center + LAYOUT[kind]

## An open cell just in front (south-east) of a building, where people stand.
static func door_cell(v: Dictionary, kind: String) -> Vector2i:
	return building_cell(v, kind) + Vector2i(1, 2)
