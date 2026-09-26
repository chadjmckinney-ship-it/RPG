class_name PartyController
extends Node2D
## Selection and orders: click or drag-box to select, right-click to move,
## 1-4 to pick members, Tab for all. Orders can be given while paused.

const FORMATION: Array[Vector2i] = [Vector2i(0, 0), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1), Vector2i(1, 1), Vector2i(-2, 0)]

var members: Array[PartyMember] = []
var selection: Array[PartyMember] = []
var map_layer: TileMapLayer
var pathfinder: Pathfinder
var world: WorldGen

var _drag_start := Vector2.ZERO
var _dragging := false
var _drag_now := Vector2.ZERO
var marker_cell := Vector2i(-9999, -9999)
var _marker_t := 0.0

func leader() -> PartyMember:
	return selection[0] if not selection.is_empty() else members[0]

func select(list: Array) -> void:
	for m in members:
		m.selected = list.has(m)
	selection.assign(list)
	Events.selection_changed.emit(selection)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_drag_start = get_global_mouse_position()
				_drag_now = _drag_start
				_dragging = true
			else:
				_dragging = false
				_finish_selection(mb.shift_pressed)
				queue_redraw()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			order_move_to(map_layer.local_to_map(map_layer.to_local(get_global_mouse_position())))
	elif event is InputEventMouseMotion and _dragging:
		_drag_now = get_global_mouse_position()
		queue_redraw()
	elif event is InputEventKey and event.pressed and not event.echo:
		var k := (event as InputEventKey).keycode
		if k >= KEY_1 and k <= KEY_4 and k - KEY_1 < members.size():
			select([members[k - KEY_1]])
		elif k == KEY_TAB:
			select(members.duplicate())
			get_viewport().set_input_as_handled()

func _finish_selection(additive: bool) -> void:
	var rect := Rect2(_drag_start, _drag_now - _drag_start).abs()
	var picked: Array = []
	if rect.size.length() < 6.0:
		# simple click: nearest member under the cursor
		var best: PartyMember = null
		var best_d := 28.0
		for m in members:
			var d := (m.global_position + Vector2(0, -22)).distance_to(_drag_start)
			if d < best_d:
				best_d = d
				best = m
		if best:
			picked = [best]
	else:
		for m in members:
			if rect.has_point(m.global_position + Vector2(0, -18)):
				picked.append(m)
	if picked.is_empty():
		return
	if additive:
		for m in selection:
			if not picked.has(m):
				picked.append(m)
	select(picked)

## Sends the selection to a cell in formation around it. Returns how many got a path.
func order_move_to(target: Vector2i) -> int:
	if selection.is_empty():
		return 0
	marker_cell = target
	_marker_t = 0.0
	var ok := 0
	var taken := {}
	for i in selection.size():
		var m := selection[i]
		var dest := _free_near(target + FORMATION[i % FORMATION.size()], taken)
		taken[dest] = true
		var p := pathfinder.find_path(m.cell, dest)
		if p.is_empty() and i > 0:
			p = pathfinder.find_path(m.cell, _free_near(target, taken))
		if not p.is_empty():
			m.order_move(p)
			ok += 1
	queue_redraw()
	return ok

func _free_near(c: Vector2i, taken: Dictionary) -> Vector2i:
	for r in 4:
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				var n := c + Vector2i(dx, dy)
				if not taken.has(n) and world.walkable(n) and not world.has_tree(n):
					return n
	return c

func _process(delta: float) -> void:
	_marker_t += delta
	if _marker_t < 1.2:
		queue_redraw()

func _draw() -> void:
	if _dragging:
		var r := Rect2(_drag_start, _drag_now - _drag_start).abs()
		draw_rect(r, Color(0.95, 0.75, 0.35, 0.12))
		draw_rect(r, Color(0.95, 0.75, 0.35, 0.8), false, 1.0)
	if _marker_t < 1.2:
		var p := map_layer.map_to_local(marker_cell)
		var s := 1.0 - _marker_t / 1.2
		draw_arc(p, 10 + 8 * (1 - s), 0, TAU, 24, Color(0.95, 0.75, 0.35, s), 2.0)
