class_name PartyMember
extends Node2D
## A controllable party member. Follows a cell path; freezes during tactical pause.
## Drawn procedurally as a placeholder until real sprite sheets exist.

@export var display_name := "Wanderer"
@export var role := ""
@export var speed := 150.0  # pixels per second on flat ground

## Look: colours and silhouette hints for the placeholder figure.
var look := {
	"skin": Color("d9b08c"), "hair": Color("3a2a20"), "hair_long": false,
	"coat": Color("4a4038"), "body": Color("5a5048"), "trim": Color("8a7a5a"),
	"legs": Color("2e2a26"), "slim": false, "hood": false,
}

var map_layer: TileMapLayer
var world: WorldGen
var cell := Vector2i.ZERO
var path: Array[Vector2i] = []
var selected := false:
	set(v):
		selected = v
		queue_redraw()
var facing := 1.0
var _walk_t := 0.0

func place_at(c: Vector2i) -> void:
	cell = c
	position = map_layer.map_to_local(c)
	path.clear()

func order_move(p: Array[Vector2i]) -> void:
	path = p.duplicate()
	if not path.is_empty() and path[0] == cell:
		path.remove_at(0)

func is_moving() -> bool:
	return not path.is_empty()

func _process(delta: float) -> void:
	if TacticalPause.paused or path.is_empty():
		return
	var target := map_layer.map_to_local(path[0])
	var step := speed * delta / world.cost(path[0])
	var to := target - position
	if absf(to.x) > 1.0:
		facing = signf(to.x)
	_walk_t += delta
	if to.length() <= step:
		position = target
		cell = path[0]
		path.remove_at(0)
	else:
		position += to.normalized() * step
	queue_redraw()

func _draw() -> void:
	var bob := sin(_walk_t * 14.0) * 1.5 if is_moving() else 0.0
	# selection ring + shadow
	if selected:
		draw_arc(Vector2.ZERO, 16, 0, TAU, 32, Color(0.95, 0.75, 0.35, 0.9), 2.0)
		_ellipse(Vector2.ZERO, Vector2(17, 8.5), Color(0.95, 0.75, 0.35, 0.18))
	_ellipse(Vector2(0, 1), Vector2(11, 5), Color(0, 0, 0, 0.35))
	var f := facing
	var y := -bob
	var w := 7.0 if look.slim else 8.0
	# legs
	var stride := sin(_walk_t * 14.0) * 3.0 if is_moving() else 0.0
	draw_rect(Rect2(-4 + stride * 0.5, y - 14, 3, 14), look.legs)
	draw_rect(Rect2(1 - stride * 0.5, y - 14, 3, 14), look.legs)
	# coat skirt flares from the waist
	var coat := PackedVector2Array([Vector2(-w, y - 26), Vector2(w, y - 26), Vector2(w + 3, y - 10), Vector2(-w - 3, y - 10)])
	draw_colored_polygon(coat, look.coat)
	# torso: narrower waist for slim silhouettes
	var waist := 5.0 if look.slim else 7.0
	var torso := PackedVector2Array([Vector2(-w, y - 38), Vector2(w, y - 38), Vector2(waist, y - 27), Vector2(-waist, y - 27)])
	draw_colored_polygon(torso, look.body)
	draw_line(Vector2(-waist, y - 27), Vector2(waist, y - 27), look.trim, 2.0)
	# arms
	draw_rect(Rect2(-w - 3, y - 37, 3, 13), look.coat)
	draw_rect(Rect2(w, y - 37, 3, 13), look.coat)
	# head
	var head := Vector2(f * 1.0, y - 45)
	if look.hair_long:
		draw_colored_polygon(PackedVector2Array([head + Vector2(-7, -3), head + Vector2(7, -3), head + Vector2(8 - f * 2, 12), head + Vector2(-8 - f * 2, 12)]), look.hair)
	draw_circle(head, 6.5, look.skin)
	if look.hood:
		draw_arc(head, 7.5, PI * 0.9, PI * 2.1, 16, look.coat, 4.0)
	else:
		draw_arc(head + Vector2(0, -1), 6.5, PI * 1.05, PI * 1.95, 12, look.hair, 4.0)
	draw_circle(head + Vector2(f * 3, 0), 1.0, Color(0.1, 0.08, 0.08))

func _ellipse(c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_colored_polygon(pts, col)
