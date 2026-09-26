class_name PartyMember
extends Actor
## A controllable party member: placeholder figure plus auto-retaliation when idle.

const AUTO_ENGAGE_RANGE := 5.0

@export var role := ""

var look := {
	"skin": Color("d9b08c"), "hair": Color("3a2a20"), "hair_long": false,
	"coat": Color("4a4038"), "body": Color("5a5048"), "trim": Color("8a7a5a"),
	"legs": Color("2e2a26"), "slim": false, "hood": false,
}

func _init() -> void:
	faction = "party"

func _idle(_delta: float) -> void:
	# Defend yourself and your companions: engage the nearest hostile that is fighting nearby.
	var best: Actor = null
	var best_d := AUTO_ENGAGE_RANGE
	for other in (ctx.actors if ctx else []):
		if not is_instance_valid(other) or not other.alive() or not is_hostile_to(other):
			continue
		if other is Creature and not other.aggressive():
			continue
		var d := cell_distance(other.cell)
		if d <= best_d:
			best_d = d
			best = other
	if best:
		issue({"type": "attack", "target": best, "auto": true})

func _on_damaged(source: Actor) -> void:
	if current == null and orders.is_empty() and source and source.alive():
		issue({"type": "attack", "target": source, "auto": true})

func _draw_body(bob: float) -> void:
	var f := facing
	var y := -bob
	var w := 7.0 if look.slim else 8.0
	var moving := not path.is_empty()
	var stride := sin(_walk_t * 14.0) * 3.0 if moving else 0.0
	draw_rect(Rect2(-4 + stride * 0.5, y - 14, 3, 14), look.legs)
	draw_rect(Rect2(1 - stride * 0.5, y - 14, 3, 14), look.legs)
	draw_colored_polygon(PackedVector2Array([Vector2(-w, y - 26), Vector2(w, y - 26), Vector2(w + 3, y - 10), Vector2(-w - 3, y - 10)]), look.coat)
	var waist := 5.0 if look.slim else 7.0
	draw_colored_polygon(PackedVector2Array([Vector2(-w, y - 38), Vector2(w, y - 38), Vector2(waist, y - 27), Vector2(-waist, y - 27)]), look.body)
	draw_line(Vector2(-waist, y - 27), Vector2(waist, y - 27), look.trim, 2.0)
	draw_rect(Rect2(-w - 3, y - 37, 3, 13), look.coat)
	draw_rect(Rect2(w, y - 37, 3, 13), look.coat)
	# weapon: bow for ranged, blade otherwise
	if ranged:
		var a0 := -PI / 2 if f > 0 else PI / 2
		draw_arc(Vector2(f * (w + 4), y - 30), 9, a0, a0 + PI, 10, Color("6a4a2a"), 2.0)
	else:
		draw_line(Vector2(f * (w + 2), y - 26), Vector2(f * (w + 10), y - 40), Color("b8b8c0"), 2.0)
	var head := Vector2(f * 1.0, y - 45)
	if look.hair_long:
		draw_colored_polygon(PackedVector2Array([head + Vector2(-7, -3), head + Vector2(7, -3), head + Vector2(8 - f * 2, 12), head + Vector2(-8 - f * 2, 12)]), look.hair)
	draw_circle(head, 6.5, look.skin)
	if look.hood:
		draw_arc(head, 7.5, PI * 0.9, PI * 2.1, 16, look.coat, 4.0)
	else:
		draw_arc(head + Vector2(0, -1), 6.5, PI * 1.05, PI * 1.95, 12, look.hair, 4.0)
	draw_circle(head + Vector2(f * 3, 0), 1.0, Color(0.1, 0.08, 0.08))
