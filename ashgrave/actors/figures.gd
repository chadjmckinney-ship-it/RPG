class_name Figures
extends RefCounted
## Shared placeholder drawing for people (party members and companion NPCs).

static func draw_person(ci: CanvasItem, look: Dictionary, f: float, bob: float, walk_t: float, moving: bool, ranged: bool) -> void:
	var y := -bob
	var w := 7.0 if look.get("slim", false) else 8.0
	var stride := sin(walk_t * 14.0) * 3.0 if moving else 0.0
	ci.draw_rect(Rect2(-4 + stride * 0.5, y - 14, 3, 14), look.legs)
	ci.draw_rect(Rect2(1 - stride * 0.5, y - 14, 3, 14), look.legs)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-w, y - 26), Vector2(w, y - 26), Vector2(w + 3, y - 10), Vector2(-w - 3, y - 10)]), look.coat)
	var waist := 5.0 if look.get("slim", false) else 7.0
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-w, y - 38), Vector2(w, y - 38), Vector2(waist, y - 27), Vector2(-waist, y - 27)]), look.body)
	ci.draw_line(Vector2(-waist, y - 27), Vector2(waist, y - 27), look.trim, 2.0)
	ci.draw_rect(Rect2(-w - 3, y - 37, 3, 13), look.coat)
	ci.draw_rect(Rect2(w, y - 37, 3, 13), look.coat)
	if ranged:
		var a0 := -PI / 2 if f > 0 else PI / 2
		ci.draw_arc(Vector2(f * (w + 4), y - 30), 9, a0, a0 + PI, 10, Color("6a4a2a"), 2.0)
	else:
		ci.draw_line(Vector2(f * (w + 2), y - 26), Vector2(f * (w + 10), y - 40), Color("b8b8c0"), 2.0)
	var head := Vector2(f * 1.0, y - 45)
	if look.get("hair_long", false):
		ci.draw_colored_polygon(PackedVector2Array([head + Vector2(-7, -3), head + Vector2(7, -3), head + Vector2(8 - f * 2, 12), head + Vector2(-8 - f * 2, 12)]), look.hair)
	ci.draw_circle(head, 6.5, look.skin)
	if look.get("hood", false):
		ci.draw_arc(head, 7.5, PI * 0.9, PI * 2.1, 16, look.coat, 4.0)
	else:
		ci.draw_arc(head + Vector2(0, -1), 6.5, PI * 1.05, PI * 1.95, 12, look.hair, 4.0)
	ci.draw_circle(head + Vector2(f * 3, 0), 1.0, Color(0.1, 0.08, 0.08))
