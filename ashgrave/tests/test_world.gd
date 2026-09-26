extends TestCase

func test_same_seed_same_world() -> void:
	var a := WorldGen.new(42)
	var b := WorldGen.new(42)
	var c := WorldGen.new(43)
	var diff := 0
	for i in 2000:
		var cell := Vector2i((i * 37) % WorldGen.SIZE, (i * 91) % WorldGen.SIZE)
		check(a.terrain_at(cell) == b.terrain_at(cell), "same seed disagreed at %s" % cell)
		check(a.has_tree(cell) == b.has_tree(cell), "trees disagreed at %s" % cell)
		if a.terrain_at(cell) != c.terrain_at(cell):
			diff += 1
	check(diff > 200, "different seeds produced near-identical worlds (%d diffs)" % diff)

func test_edges_are_water() -> void:
	var w := WorldGen.new(7)
	for i in WorldGen.SIZE:
		check(w.terrain_at(Vector2i(i, 0)) == WorldGen.Terrain.WATER, "north edge not water at %d" % i)
		check(w.terrain_at(Vector2i(0, i)) == WorldGen.Terrain.WATER, "west edge not water at %d" % i)
	check(not w.walkable(Vector2i(-1, 5)), "out of bounds should not be walkable")

func test_biome_variety() -> void:
	for s in [1, 99, 2024]:
		var w := WorldGen.new(s)
		var seen := {}
		for y in range(0, WorldGen.SIZE, 4):
			for x in range(0, WorldGen.SIZE, 4):
				seen[w.terrain_at(Vector2i(x, y))] = true
		check(seen.size() >= 6, "seed %d only has %d terrain types" % [s, seen.size()])

func test_spawn_is_walkable_and_open() -> void:
	for s in [1, 5, 77, 1337, 90210]:
		var w := WorldGen.new(s)
		var sp := w.spawn_cell()
		check(w.walkable(sp), "seed %d spawn not walkable" % s)
		# BFS: the spawn should open onto a sizeable region, not a pocket.
		var seen := {sp: true}
		var q: Array[Vector2i] = [sp]
		while not q.is_empty() and seen.size() < 3000:
			var c: Vector2i = q.pop_front()
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var n: Vector2i = c + d
				if not seen.has(n) and w.walkable(n) and not w.has_tree(n):
					seen[n] = true
					q.append(n)
		check(seen.size() >= 3000, "seed %d spawn region only %d cells" % [s, seen.size()])

func test_pathfinder_routes_around_obstacles() -> void:
	var w := WorldGen.new(1337)
	var pf := Pathfinder.new(w)
	var sp := w.spawn_cell()
	pf.ensure_covers(sp)
	var target := Vector2i(-1, -1)
	for r in range(12, 30):
		var c := sp + Vector2i(r, r / 2)
		if w.walkable(c) and not w.has_tree(c):
			target = c
			break
	check(target.x >= 0, "no walkable target near spawn")
	var p := pf.find_path(sp, target)
	check(not p.is_empty(), "no path from %s to %s" % [sp, target])
	for c in p:
		check(w.walkable(c) and not w.has_tree(c), "path crosses blocked cell %s" % c)
	check(pf.find_path(sp, Vector2i(0, 0)).is_empty(), "path into water should fail")
