class_name Gathering
extends RefCounted
## Deterministic resource nodes per chunk. Harvested nodes regrow after REGROW_DAYS.

const REGROW_DAYS := 2
const KINDS := {
	"herb": {"item": "bitterroot", "amount": [1, 3], "name": "Bitterroot patch"},
	"ore": {"item": "iron-ore", "amount": [1, 2], "name": "Iron seam"},
	"wood": {"item": "deadwood", "amount": [2, 3], "name": "Fallen deadwood"},
}

static func nodes_for_chunk(world: WorldGen, ch: Vector2i) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world.seed_value, ch.x, ch.y, "gather"])
	var out: Array = []
	for i in rng.randi_range(3, 6):
		var c := ch * WorldGen.CHUNK + Vector2i(rng.randi_range(1, WorldGen.CHUNK - 2), rng.randi_range(1, WorldGen.CHUNK - 2))
		if not world.walkable(c) or world.has_tree(c):
			continue
		var kind := ""
		match world.terrain_at(c):
			WorldGen.Terrain.HILLS: kind = "ore"
			WorldGen.Terrain.FOREST: kind = "wood"
			WorldGen.Terrain.FEN, WorldGen.Terrain.MOOR: kind = "herb"
		if kind != "":
			out.append({"id": "g%d:%d:%d" % [ch.x, ch.y, i], "kind": kind, "cell": c})
	return out

static func available(id: String, today: int) -> bool:
	var got = GameState.harvested.get(id)
	return got == null or today - int(got) >= REGROW_DAYS

## Harvest: adds items, records the day. Returns what was gathered ({} if not ready).
static func harvest(node: Dictionary, today: int, rng: RandomNumberGenerator = null) -> Dictionary:
	if not available(node.id, today):
		return {}
	var k: Dictionary = KINDS[node.kind]
	var n: int = rng.randi_range(k.amount[0], k.amount[1]) if rng else randi_range(k.amount[0], k.amount[1])
	GameState.inventory.add(k.item, n)
	GameState.harvested[node.id] = today
	return {"item": k.item, "count": n}
