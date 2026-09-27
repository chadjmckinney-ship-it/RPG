class_name WorldOverlay
extends Control
## 2D layer over the 3D view: health bars (with "Lv N" for enemies), status pips,
## floating combat text and names of hovered enemies and villagers, projected from each actor;
## the name of a hovered gather node.

var main: Node

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_d: float) -> void:
	queue_redraw()

func _draw() -> void:
	if main == null:
		return
	var cam: Camera3D = main.cam.camera
	var font := UiTheme.font()
	var view := get_viewport_rect().size
	for a in main.actors:
		if not is_instance_valid(a):
			continue
		var head: Vector3 = a.global_position + Vector3(0, a.height, 0)
		if cam.is_position_behind(head):
			continue
		var p := cam.unproject_position(head)
		if p.x < -50 or p.y < -50 or p.x > view.x + 50 or p.y > view.y + 50:
			continue
		var show_bar: bool = not a.downed and (a.faction == "hostile" or a.hp < a.max_hp or not a.statuses.is_empty())
		if show_bar:
			var w := 52.0
			draw_rect(Rect2(p.x - w / 2 - 1, p.y - 1, w + 2, 7), Color(0, 0, 0, 0.7))
			draw_rect(Rect2(p.x - w / 2, p.y, w * a.hp / a.max_hp, 5), Color(0.85, 0.25, 0.2) if a.faction != "party" else Color(0.4, 0.8, 0.4))
			if a.has_method("level"):
				var lv: int = a.level()
				draw_string(font, Vector2(p.x + w / 2 + 4, p.y + 7), "Lv %d" % lv, HORIZONTAL_ALIGNMENT_LEFT, -1, UiTheme.fs(10),
					[Color(0.85, 0.82, 0.75), Color(1.0, 0.8, 0.4), Color(1.0, 0.55, 0.3), Color(1.0, 0.35, 0.35)][clampi((lv - 1) / 3, 0, 3)])
			var x := p.x - w / 2
			for id in a.statuses:
				var col: Color = {"poison": Color(0.6, 0.9, 0.3), "slow": Color(0.4, 0.6, 1), "root": Color(0.6, 0.9, 0.5), "guard": Color(0.9, 0.85, 0.5), "bleed": Color(0.8, 0.15, 0.15), "burn": Color(1.0, 0.5, 0.15)}.get(id, Color.WHITE)
				draw_rect(Rect2(x, p.y - 9, 7, 7), col)
				x += 10
		if a.hovered and not a.downed:
			var talk: bool = a.faction == "neutral"
			draw_string(font, Vector2(p.x - 100, p.y - 14), a.display_name + ("  (talk)" if talk else ""), HORIZONTAL_ALIGNMENT_CENTER, 200, UiTheme.fs(12), Color(1.0, 0.88, 0.55) if talk else Color(1, 0.8, 0.7))
		for f in a.floaters:
			var k: float = f.t / 1.1
			var c: Color = f.color
			c.a = 1.0 - k * k
			var fp := p + Vector2(0, -20 - 40 * k)
			draw_string(font, fp + Vector2(-60, 2), f.text, HORIZONTAL_ALIGNMENT_CENTER, 120, UiTheme.fs(18), Color(0, 0, 0, c.a))
			draw_string(font, fp + Vector2(-61, 0), f.text, HORIZONTAL_ALIGNMENT_CENTER, 120, UiTheme.fs(18), c)
	var n = main.party.interactable_at(get_viewport().get_mouse_position())
	if n != null:
		var np := cam.unproject_position(n.global_position + Vector3(0, 0.8, 0))
		var ready: bool = n.ready_to_harvest()
		draw_string(font, np + Vector2(-100, 0), n.display_name() + ("" if ready else " (picked clean)"), HORIZONTAL_ALIGNMENT_CENTER, 200, UiTheme.fs(12), Color(0.75, 0.95, 0.6) if ready else Color(0.6, 0.6, 0.6))
