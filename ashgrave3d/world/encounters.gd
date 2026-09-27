class_name Encounters
extends RefCounted
## Deterministic creature camps per chunk: same seed, same camps, same place.

const SAFE_RADIUS := 18.0   # no camps this close to the starting point
const VILLAGE_RADIUS := 16.0 # nor this close to a village
## Regional danger: camps get a rank (0..3) by distance from the starting point.
const RANK_START := 30.0
const RANK_BAND := 55.0

static func rank_at(world: WorldGen, c: Vector2i) -> int:
	var d := Vector2(c - world.spawn_cell()).length()
	return clampi(int((d - RANK_START) / RANK_BAND), 0, 3)

static func camps_for_chunk(world: WorldGen, ch: Vector2i) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world.seed_value, ch.x, ch.y, "camps"])
	var roll := rng.randf()
	var n := 0 if roll < 0.4 else (1 if roll < 0.82 else 2)
	var out: Array = []
	var spawn := world.spawn_cell()
	for i in n:
		var c := ch * WorldGen.CHUNK + Vector2i(rng.randi_range(3, WorldGen.CHUNK - 4), rng.randi_range(3, WorldGen.CHUNK - 4))
		if not _open(world, c) or Vector2(c - spawn).length() < SAFE_RADIUS:
			continue
		if not world.village_near(c, VILLAGE_RADIUS).is_empty():
			continue
		var type := _type_for(world.terrain_at(c), rng)
		var count := rng.randi_range(1, 2) if type in ["risen", "boar", "revenant"] else rng.randi_range(1, 3)
		var cells: Array[Vector2i] = []
		for k in count * 4:
			var m := c + Vector2i(rng.randi_range(-2, 2), rng.randi_range(-2, 2))
			if cells.size() < count and _open(world, m) and not cells.has(m) and Vector2(m - spawn).length() >= SAFE_RADIUS:
				cells.append(m)
		if not cells.is_empty():
			# Some camps mix types: bandits bring crossbows, cultists raise the dead.
			var types: Array = []
			for k in cells.size():
				types.append(MIXES[type][k % MIXES[type].size()] if MIXES.has(type) and k > 0 else type)
			out.append({"id": "%d:%d:%d" % [ch.x, ch.y, i], "type": type, "cells": cells, "types": types, "rank": rank_at(world, c)})
	return out

static func _open(world: WorldGen, c: Vector2i) -> bool:
	return world.walkable(c) and not world.has_tree(c)

const MIXES := {"bandit": ["crossbow", "bandit"], "cultist": ["cultist", "risen"]}
const BY_TERRAIN := {
	WorldGen.Terrain.HILLS: [["risen", 0.6], ["revenant", 0.4]],
	WorldGen.Terrain.FEN: [["lurker", 0.5], ["wight", 0.5]],
	WorldGen.Terrain.FOREST: [["hound", 0.45], ["boar", 0.3], ["risen", 0.25]],
	WorldGen.Terrain.ROAD: [["bandit", 0.6], ["cultist", 0.4]],
	WorldGen.Terrain.MOOR: [["hound", 0.35], ["crows", 0.3], ["cultist", 0.35]],
	WorldGen.Terrain.ASHFIELD: [["ghoul", 0.6], ["crows", 0.4]],
}

static func _type_for(t: int, rng: RandomNumberGenerator) -> String:
	var table: Array = BY_TERRAIN.get(t, BY_TERRAIN[WorldGen.Terrain.MOOR])
	var r := rng.randf()
	for e in table:
		r -= e[1]
		if r <= 0.0:
			return e[0]
	return table[table.size() - 1][0]
