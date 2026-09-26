class_name GatherNode
extends Node2D
## A harvestable spot (bitterroot, iron seam, deadwood). Right-click to send someone to gather.

var data: Dictionary = {}   # {id, kind, cell}

func display_name() -> String:
	return Gathering.KINDS[data.kind].name

func ready_to_harvest() -> bool:
	return Gathering.available(data.id, TimeOfDay.day)

func on_interact(who) -> void:
	var got := Gathering.harvest(data, TimeOfDay.day)
	if got.is_empty():
		Events.combat_message.emit("%s is picked clean. It will recover in a day or two." % display_name())
	else:
		Events.combat_message.emit("%s gathers %d %s." % [who.display_name, got.count, Items.item_name(got.item)])
	queue_redraw()

func _process(_d: float) -> void:
	queue_redraw()

func _draw() -> void:
	var ok := ready_to_harvest()
	var a := 1.0 if ok else 0.35
	match data.kind:
		"herb":
			for i in 5:
				var x := -8.0 + i * 4.0
				draw_line(Vector2(x, 0), Vector2(x + (i - 2) * 1.5, -10 - (i % 2) * 4), Color(0.45, 0.6, 0.3, a), 2.0)
			if ok:
				draw_circle(Vector2(-2, -12), 2.0, Color(0.85, 0.75, 0.4))
				draw_circle(Vector2(4, -10), 2.0, Color(0.85, 0.75, 0.4))
		"ore":
			draw_colored_polygon(PackedVector2Array([Vector2(-12, 0), Vector2(-8, -12), Vector2(4, -16), Vector2(12, -4), Vector2(8, 2)]), Color(0.35, 0.33, 0.32, 1))
			if ok:
				draw_line(Vector2(-6, -8), Vector2(2, -12), Color(0.75, 0.5, 0.35), 2.0)
				draw_line(Vector2(0, -4), Vector2(7, -7), Color(0.75, 0.5, 0.35), 2.0)
		"ash":
			for i in 3:
				draw_line(Vector2(-6 + i * 6, 0), Vector2(-6 + i * 6, -9 - i), Color(0.3, 0.28, 0.26, a), 2.0)
			if ok:
				draw_circle(Vector2(0, -12), 3.0, Color(0.85, 0.35, 0.2))
				draw_circle(Vector2(-6, -9), 2.0, Color(0.9, 0.5, 0.25))
		"wood":
			draw_line(Vector2(-14, 0), Vector2(12, -6), Color(0.3, 0.22, 0.15, a), 6.0)
			draw_line(Vector2(-8, 2), Vector2(14, 0), Color(0.25, 0.18, 0.12, a), 5.0)
