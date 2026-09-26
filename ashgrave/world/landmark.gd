class_name Landmark
extends Node2D
## Story locations: the Drowned Barrow (standing stones) and the Chapel of Ash (ruin).

var kind := "barrow"

func _draw() -> void:
	if kind == "barrow":
		# low mound ringed by salt-crusted standing stones
		var pts := PackedVector2Array()
		for i in 24:
			var a := TAU * i / 24.0
			pts.append(Vector2(cos(a) * 70, sin(a) * 35 - 6))
		draw_colored_polygon(pts, Color("4a4a3e"))
		for i in 7:
			var a := TAU * i / 7.0 + 0.3
			var p := Vector2(cos(a) * 58, sin(a) * 29)
			draw_colored_polygon(PackedVector2Array([p + Vector2(-5, 0), p + Vector2(5, 0), p + Vector2(4, -26), p + Vector2(-4, -30)]), Color("6a6a60"))
			draw_line(p + Vector2(-4, -28), p + Vector2(4, -24), Color("d8d8cc"), 2.0)  # salt crust
		draw_colored_polygon(PackedVector2Array([Vector2(-14, -4), Vector2(14, -4), Vector2(10, -16), Vector2(-10, -16)]), Color("1a1a18"))
	elif kind == "ashen":
		# a burnt watchtower stump on scorched ground
		var pts := PackedVector2Array()
		for i in 24:
			var a := TAU * i / 24.0
			pts.append(Vector2(cos(a) * 80, sin(a) * 40))
		draw_colored_polygon(pts, Color(0.12, 0.1, 0.09, 0.8))
		draw_colored_polygon(PackedVector2Array([Vector2(-30, 0), Vector2(30, 0), Vector2(24, -80), Vector2(8, -96), Vector2(-4, -72), Vector2(-24, -84)]), Color("3a3430"))
		draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(30, 0), Vector2(24, -80), Vector2(8, -96)]), Color("2a2522"))
		draw_rect(Rect2(-8, -40, 10, 14), Color("140f0c"))
		for i in 5:
			draw_circle(Vector2(-20 + i * 11, -86 - (i % 3) * 8), 2.0, Color(1.0, 0.5, 0.2, 0.6))  # embers
	else:
		# broken chapel walls and a blackened arch
		var stone := Color("5a5650")
		draw_colored_polygon(PackedVector2Array([Vector2(-60, -10), Vector2(-20, 10), Vector2(-20, -30), Vector2(-60, -50)]), stone)
		draw_colored_polygon(PackedVector2Array([Vector2(20, 10), Vector2(60, -10), Vector2(60, -40), Vector2(20, -20)]), stone.darkened(0.2))
		draw_arc(Vector2(0, -40), 16, PI, TAU, 12, Color("2a2622"), 5.0)
		draw_line(Vector2(-16, -40), Vector2(-16, -4), Color("2a2622"), 5.0)
		draw_line(Vector2(16, -40), Vector2(16, -4), Color("2a2622"), 5.0)
		for i in 6:
			draw_circle(Vector2(-30 + i * 12, 4 - (i % 2) * 6), 5, Color(0.12, 0.11, 0.1, 0.8))  # ash
