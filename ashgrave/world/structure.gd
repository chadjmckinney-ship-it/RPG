class_name Structure
extends Node2D
## A village building covering 2x2 cells. Drawn as a simple isometric box with a roof.

var kind := "house_a"
var village: Dictionary = {}

const COLORS := {
	"tavern": [Color("6a4a32"), Color("4a2a22")],
	"forge": [Color("5a5550"), Color("3a3230")],
	"house_a": [Color("6e5a44"), Color("514034")],
	"house_b": [Color("6e5a44"), Color("3e4638")],
}

func _draw() -> void:
	# Origin sits at the building's front (bottom) corner, so y-sorting works against actors.
	var wall: Color = COLORS[kind][0]
	var roof: Color = COLORS[kind][1]
	var h := 44.0
	var left := Vector2(-64, -32)
	var right := Vector2(64, -32)
	var top := Vector2(0, -64)
	var bottom := Vector2.ZERO
	# walls
	draw_colored_polygon(PackedVector2Array([left, bottom, bottom + Vector2(0, -h), left + Vector2(0, -h)]), wall)
	draw_colored_polygon(PackedVector2Array([bottom, right, right + Vector2(0, -h), bottom + Vector2(0, -h)]), wall.darkened(0.25))
	# door and window
	draw_colored_polygon(PackedVector2Array([Vector2(12, -6), Vector2(26, -13), Vector2(26, -37), Vector2(12, -30)]), Color("241a14"))
	var lit := Color(1.0, 0.75, 0.35, 0.5 + 0.5 * (1.0 - TimeOfDay.daylight()))
	draw_colored_polygon(PackedVector2Array([Vector2(-44, -30), Vector2(-30, -23), Vector2(-30, -35), Vector2(-44, -42)]), lit)
	# roof
	var rise := Vector2(0, -h - 26)
	draw_colored_polygon(PackedVector2Array([left + Vector2(-6, -h + 2), bottom + Vector2(0, -h + 6), top + rise + Vector2(0, 32), left + rise + Vector2(10, 5)]), roof)
	draw_colored_polygon(PackedVector2Array([bottom + Vector2(0, -h + 6), right + Vector2(6, -h + 2), right + rise + Vector2(-10, 5), top + rise + Vector2(0, 32)]), roof.darkened(0.2))
	match kind:
		"forge":
			draw_rect(Rect2(34, -h - 40, 10, 22), Color("3a3230"))
			draw_circle(Vector2(52, -8), 7, Color(1.0, 0.45, 0.15, 0.85))
			draw_circle(Vector2(52, -8), 12, Color(1.0, 0.5, 0.2, 0.25))
		"tavern":
			draw_line(Vector2(34, -30), Vector2(48, -37), Color("3a2a1a"), 2.0)
			draw_rect(Rect2(40, -34, 10, 8), Color("b08a4a"))
