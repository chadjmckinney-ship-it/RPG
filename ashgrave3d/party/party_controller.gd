class_name PartyController
extends Control
## Mouse and keys for the party (a full-screen overlay so it can draw the drag box):
##  left-click / drag: select   right-click: move in formation   shift: queue   1-4 / Tab: pick members.

const FORMATION: Array[Vector2i] = [Vector2i(0, 0), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1), Vector2i(1, 1), Vector2i(-2, 0)]
const PICK_RADIUS := 44.0

var members: Array[PartyMember] = []
var selection: Array[PartyMember] = []
var cam: RtsCamera
var world: WorldGen
var pathfinder: Pathfinder
var marker := Vector3.ZERO
var _marker_t := 99.0
var _drag_start := Vector2.ZERO
var _drag_now := Vector2.ZERO
var _dragging := false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func leader() -> PartyMember:
	for m in selection:
		if m.alive():
			return m
	for m in members:
		if m.alive():
			return m
	return members[0]

func select(list: Array) -> void:
	for m in members:
		m.selected = list.has(m)
	selection.assign(list)
	Events.selection_changed.emit(selection)

func screen_pos(a: Node3D) -> Vector2:
	return cam.camera.unproject_position(a.global_position + Vector3(0, 0.9, 0))

func member_at(p: Vector2) -> PartyMember:
	var best: PartyMember = null
	var best_d := PICK_RADIUS
	for m in members:
		if cam.camera.is_position_behind(m.global_position):
			continue
		var d := screen_pos(m).distance_to(p)
		if d < best_d:
			best_d = d
			best = m
	return best

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_drag_start = event.position
				_drag_now = event.position
				_dragging = true
			elif _dragging:
				_dragging = false
				_finish_select(event.shift_pressed)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			var gp = cam.ground_point(event.position)
			if gp != null:
				order_move_to(world.world_to_cell(gp), event.shift_pressed)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging:
		_drag_now = event.position
		queue_redraw()
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode >= KEY_1 and event.keycode <= KEY_4 and event.keycode - KEY_1 < members.size():
			select([members[event.keycode - KEY_1]])
		elif event.keycode == KEY_TAB:
			select(members.duplicate())
		elif event.keycode == KEY_F:
			cam.follow = leader()

func _finish_select(add: bool) -> void:
	var r := Rect2(_drag_start, _drag_now - _drag_start).abs()
	var picked: Array = []
	if r.size.length() < 6.0:
		var m := member_at(_drag_start)
		if m:
			picked = [m]
	else:
		for m in members:
			if r.has_point(screen_pos(m)):
				picked.append(m)
	if add:
		for m in selection:
			if not picked.has(m):
				picked.append(m)
	if not picked.is_empty() or not add:
		select(picked if not picked.is_empty() else selection)
	queue_redraw()

func order_move_to(target: Vector2i, queue := false) -> int:
	if selection.is_empty():
		return 0
	marker = world.cell_to_world(target)
	_marker_t = 0.0
	var ok := 0
	var taken := {}
	for i in selection.size():
		var m := selection[i]
		if m.downed:
			continue
		var dest := free_near(target + FORMATION[i % FORMATION.size()], taken)
		taken[dest] = true
		if queue:
			m.issue({"type": "move", "cell": dest}, true)
			ok += 1
			continue
		var p := pathfinder.find_path(m.cell, dest)
		if p.is_empty() and i > 0:
			p = pathfinder.find_path(m.cell, free_near(target, taken))
		if not p.is_empty():
			m.order_move(p)
			ok += 1
	return ok

func free_near(c: Vector2i, taken: Dictionary) -> Vector2i:
	for r in 4:
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				var n := c + Vector2i(dx, dy)
				if not taken.has(n) and world.walkable(n) and not world.has_tree(n):
					return n
	return c

func _process(delta: float) -> void:
	_marker_t += delta
	queue_redraw()

func _draw() -> void:
	if _dragging:
		var r := Rect2(_drag_start, _drag_now - _drag_start).abs()
		draw_rect(r, Color(0.95, 0.75, 0.35, 0.12))
		draw_rect(r, Color(0.95, 0.75, 0.35, 0.8), false, 1.0)
	if _marker_t < 0.8 and not cam.camera.is_position_behind(marker):
		var p := cam.camera.unproject_position(marker)
		var k := 1.0 - _marker_t / 0.8
		draw_arc(p, 10.0 + 14.0 * _marker_t, 0, TAU, 24, Color(0.95, 0.8, 0.4, k), 2.0)
