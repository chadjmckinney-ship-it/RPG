class_name Pathfinder
extends RefCounted
## A* over a window of the world centred on a point. Rebuilt when the party
## strays near the window's edge, so pathing stays cheap in a 512x512 world.

const WINDOW := 96

var world: WorldGen
var grid := AStarGrid2D.new()
var origin := Vector2i.ZERO

func _init(w: WorldGen) -> void:
	world = w
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE

func ensure_covers(center: Vector2i) -> void:
	var local := center - origin
	var margin := WINDOW / 4
	if grid.region.size != Vector2i.ZERO and local.x > margin and local.y > margin and local.x < WINDOW - margin and local.y < WINDOW - margin:
		return
	origin = center - Vector2i(WINDOW / 2, WINDOW / 2)
	grid.region = Rect2i(origin, Vector2i(WINDOW, WINDOW))
	grid.update()
	for x in range(origin.x, origin.x + WINDOW):
		for y in range(origin.y, origin.y + WINDOW):
			var c := Vector2i(x, y)
			if not world.walkable(c) or world.has_tree(c):
				grid.set_point_solid(c, true)
			else:
				grid.set_point_weight_scale(c, world.cost(c))

## Paths only inside the current window (kept centred on the party leader by main.gd).
## Callers far outside it fall back to greedy steering.
func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	if grid.region.size == Vector2i.ZERO:
		ensure_covers(from)
	if not grid.region.has_point(from) or not grid.region.has_point(to) or grid.is_point_solid(to):
		return []
	return grid.get_id_path(from, to)

## Like find_path, but treats the given cells as solid for this one search (people standing
## in the way). Returns [] if the goal itself is one of them.
func find_path_avoiding(from: Vector2i, to: Vector2i, blocked: Array) -> Array[Vector2i]:
	if blocked.has(to):
		return []
	if grid.region.size == Vector2i.ZERO:
		ensure_covers(from)
	var marked: Array[Vector2i] = []
	for c in blocked:
		if c != from and grid.region.has_point(c) and not grid.is_point_solid(c):
			grid.set_point_solid(c, true)
			marked.append(c)
	var p := find_path(from, to)
	for c in marked:
		grid.set_point_solid(c, false)
	return p
