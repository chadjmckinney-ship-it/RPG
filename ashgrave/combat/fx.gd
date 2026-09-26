class_name Fx
extends Node2D
## Short-lived world effects: projectile tracers and area rings.

var items: Array = []

func tracer(from: Vector2, to: Vector2, col: Color) -> void:
	items.append({"kind": "line", "a": from, "b": to, "c": col, "t": 0.0, "life": 0.25})

func ring(at: Vector2, radius: float, col: Color) -> void:
	items.append({"kind": "ring", "a": at, "r": radius, "c": col, "t": 0.0, "life": 0.6})

func _process(delta: float) -> void:
	if TacticalPause.paused:
		return
	for it in items:
		it.t += delta
	items = items.filter(func(it): return it.t < it.life)
	queue_redraw()

func _draw() -> void:
	for it in items:
		var k: float = 1.0 - it.t / it.life
		var c: Color = it.c
		c.a = k
		if it.kind == "line":
			var head: Vector2 = it.a.lerp(it.b, minf(1.0, it.t / (it.life * 0.6)))
			draw_line(head.lerp(it.a, 0.25), head, c, 2.0)
		else:
			draw_arc(it.a, it.r * (1.2 - k * 0.2), 0, TAU, 32, c, 2.0)
