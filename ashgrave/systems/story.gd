class_name Story
extends RefCounted
## Where the hand-written story happens in a generated world. Pure function of the seed.
##  start    – village nearest the spawn: Warden Maud (quest giver) and Brother Oswin
##  hollow   – nearest other Hollow Folk village: Old Nessa and Ketta
##  company  – nearest Free Companies village: Captain Harl
##  barrow   – the Drowned Barrow, in far hills
##  chapel   – the Chapel of Ash, a ruin on the moor (Oswin's quest)

static var _cache := {}

static func setup(world: WorldGen) -> Dictionary:
	if _cache.has(world.seed_value):
		return _cache[world.seed_value]
	var sp := world.spawn_cell()
	var vs: Array = world.villages().duplicate()
	vs.sort_custom(func(a, b): return Vector2(a.center - sp).length() < Vector2(b.center - sp).length())
	var start: Dictionary = vs[0]
	var hollow := _nearest_other(vs, start, "hollow")
	var company := _nearest_other(vs, start, "companies")
	var s := {
		"start": start.id, "hollow": hollow.id, "company": company.id,
		"barrow": _find_site(world, start.center, 50, 140, [WorldGen.Terrain.HILLS]),
		"chapel": _find_site(world, start.center, 28, 80, [WorldGen.Terrain.MOOR, WorldGen.Terrain.ROAD]),
	}
	_cache[world.seed_value] = s
	return s

static func village(world: WorldGen, id: String) -> Dictionary:
	for v in world.villages():
		if v.id == id:
			return v
	return {}

## Special NPCs: npc id -> {village, job, name}
static func special_npcs(world: WorldGen) -> Dictionary:
	var s := setup(world)
	return {
		"maud": {"village": s.start, "job": "elder", "name": "Warden Maud"},
		"oswin": {"village": s.start, "job": "companion", "name": "Brother Oswin"},
		"nessa": {"village": s.hollow, "job": "wisewoman", "name": "Old Nessa"},
		"ketta": {"village": s.hollow, "job": "companion", "name": "Ketta"},
		"harl": {"village": s.company, "job": "captain", "name": "Captain Harl"},
	}

static func _nearest_other(vs: Array, start: Dictionary, faction: String) -> Dictionary:
	for v in vs:
		if v.id != start.id and v.faction == faction:
			return v
	return vs[1] if vs.size() > 1 else start

static func _find_site(world: WorldGen, from: Vector2i, rmin: int, rmax: int, terrains: Array) -> Vector2i:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world.seed_value, from, rmin, "site"])
	for attempt in 4000:
		var a := rng.randf() * TAU
		var r := rng.randf_range(rmin, rmax)
		var c := from + Vector2i(roundi(cos(a) * r), roundi(sin(a) * r))
		if not terrains.has(world.terrain_at(c)):
			continue
		if not world.village_near(c, 24.0).is_empty():
			continue
		var ok := true
		for dx in range(-2, 3):
			for dy in range(-2, 3):
				if not world.walkable(c + Vector2i(dx, dy)) or world.has_tree(c + Vector2i(dx, dy)):
					ok = false
		if ok:
			return c
	return from + Vector2i(rmin, 0)
