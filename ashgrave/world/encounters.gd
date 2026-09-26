class_name Encounters
extends RefCounted
## Deterministic creature camps per chunk: same seed, same camps, same place.

const SAFE_RADIUS := 18.0   # no camps this close to the starting point
const VILLAGE_RADIUS := 16.0 # nor this close to a village

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
		var count := rng.randi_range(1, 2) if type == "risen" else rng.randi_range(1, 3)
		var cells: Array[Vector2i] = []
		for k in count * 4:
			var m := c + Vector2i(rng.randi_range(-2, 2), rng.randi_range(-2, 2))
			if cells.size() < count and _open(world, m) and not cells.has(m) and Vector2(m - spawn).length() >= SAFE_RADIUS:
				cells.append(m)
		if not cells.is_empty():
			out.append({"id": "%d:%d:%d" % [ch.x, ch.y, i], "type": type, "cells": cells})
	return out

static func _open(world: WorldGen, c: Vector2i) -> bool:
	return world.walkable(c) and not world.has_tree(c)

static func _type_for(t: int, rng: RandomNumberGenerator) -> String:
	match t:
		WorldGen.Terrain.HILLS: return "risen"
		WorldGen.Terrain.FEN: return "lurker"
		WorldGen.Terrain.FOREST: return "hound" if rng.randf() < 0.7 else "risen"
		WorldGen.Terrain.ROAD: return "cultist"
	return "hound" if rng.randf() < 0.5 else "cultist"
