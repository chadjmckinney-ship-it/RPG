class_name PartyController
extends Node2D
## Selection and orders.
##  Left-click / drag: select.  Right-click: move, or attack a hostile.
##  Shift+right-click: queue the order.  Q / E: first selected member's abilities.
##  1-3 pick a member, Tab everyone.  Orders work while tactically paused.

const FORMATION: Array[Vector2i] = [Vector2i(0, 0), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1), Vector2i(1, 1), Vector2i(-2, 0)]
const PICK_RADIUS := 52.0

var members: Array[PartyMember] = []
var selection: Array[PartyMember] = []
var map_layer: TileMapLayer
var pathfinder: Pathfinder
var world: WorldGen

## Ability waiting for a target click: {member, id}
var targeting := {}

var _drag_start := Vector2.ZERO
var _dragging := false
var _drag_now := Vector2.ZERO
var marker_cell := Vector2i(-9999, -9999)
var _marker_t := 9.0

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

func mouse_cell() -> Vector2i:
	return map_layer.local_to_map(map_layer.to_local(get_global_mouse_position()))

## The actor drawn under a screen point (bodies extend upward from the feet).
## want_hostile: true = creatures, false = party members; neutral villagers use villager_at().
func actor_at(p: Vector2, want_hostile: bool) -> Actor:
	return _actor_of(p, "hostile" if want_hostile else "party")

func villager_at(p: Vector2) -> Actor:
	return _actor_of(p, "neutral")

func gather_node_at(p: Vector2) -> Node2D:
	var best: Node2D = null
	var best_d := 44.0
	for n in (Actor.ctx.gather_nodes if Actor.ctx else []):
		if is_instance_valid(n):
			var d: float = (n.global_position + Vector2(0, -12)).distance_to(p)
			if d < best_d:
				best_d = d
				best = n
	return best

func _actor_of(p: Vector2, faction: String) -> Actor:
	var best: Actor = null
	var best_d := PICK_RADIUS
	for a in (Actor.ctx.actors if Actor.ctx else members):
		if not is_instance_valid(a) or a.downed:
			continue
		if a.faction != faction:
			continue
		var d: float = (a.global_position + Vector2(0, -48)).distance_to(p)
		if d < best_d:
			best_d = d
			best = a
	return best

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and not targeting.is_empty():
				_resolve_targeting(get_global_mouse_position(), mb.shift_pressed)
				get_viewport().set_input_as_handled()
				return
			if mb.pressed:
				_drag_start = get_global_mouse_position()
				_drag_now = _drag_start
				_dragging = true
			elif _dragging:
				_dragging = false
				_finish_selection(mb.shift_pressed)
				queue_redraw()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if not targeting.is_empty():
				targeting = {}
				return
			var mp := get_global_mouse_position()
			var foe := actor_at(mp, true)
			var folk := villager_at(mp) if foe == null else null
			var node := gather_node_at(mp) if foe == null and folk == null else null
			if foe:
				order_attack(foe, mb.shift_pressed)
			elif folk:
				order_interact(folk, folk.cell, 2.0, mb.shift_pressed)
			elif node:
				order_interact(node, node.data.cell, 1.5, mb.shift_pressed)
			else:
				order_move_to(mouse_cell(), mb.shift_pressed)
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
		elif k == KEY_Q or k == KEY_E:
			begin_ability(0 if k == KEY_Q else 1, (event as InputEventKey).shift_pressed)
		elif k == KEY_ESCAPE:
			targeting = {}

func _finish_selection(additive: bool) -> void:
	var rect := Rect2(_drag_start, _drag_now - _drag_start).abs()
	var picked: Array = []
	if rect.size.length() < 6.0:
		var m := actor_at(_drag_start, false)
		if m:
			picked = [m]
	else:
		for m in members:
			if rect.has_point(m.global_position + Vector2(0, -40)):
				picked.append(m)
	if picked.is_empty():
		return
	if additive:
		for m in selection:
			if not picked.has(m):
				picked.append(m)
	select(picked)

## Sends the selection to a cell in formation around it. Returns how many got a path.
func order_move_to(target: Vector2i, queue := false) -> int:
	if selection.is_empty():
		return 0
	marker_cell = target
	_marker_t = 0.0
	var ok := 0
	var taken := {}
	for i in selection.size():
		var m := selection[i]
		if m.downed:
			continue
		var dest := _free_near(target + FORMATION[i % FORMATION.size()], taken)
		taken[dest] = true
		if queue:
			m.issue({"type": "move", "cell": dest}, true)
			ok += 1
			continue
		var p := pathfinder.find_path(m.cell, dest)
		if p.is_empty() and i > 0:
			p = pathfinder.find_path(m.cell, _free_near(target, taken))
		if not p.is_empty():
			m.order_move(p)
			ok += 1
	queue_redraw()
	return ok

## The lead selected member walks over and interacts (talk, gather).
func order_interact(node: Node, at: Vector2i, reach: float, queue := false) -> void:
	var m := leader()
	if m.downed:
		return
	m.issue({"type": "interact", "node": node, "cell": at, "range": reach}, queue)
	marker_cell = at
	_marker_t = 0.0

func order_attack(foe: Actor, queue := false) -> void:
	for m in selection:
		m.issue({"type": "attack", "target": foe}, queue)
	marker_cell = foe.cell
	_marker_t = 0.0

## Ability slot on the first selected member; self-target fires at once, others wait for a click.
func begin_ability(slot: int, queue := false) -> void:
	var m := leader()
	if slot >= m.abilities.size():
		return
	var id: String = m.abilities[slot]
	var a := Abilities.get_def(id)
	if not m.can_use(id):
		Events.combat_message.emit("%s: %s isn't ready." % [m.display_name, a.name])
		return
	if a.target == "self":
		m.use_ability(id, m, m.cell, queue)
	else:
		targeting = {"member": m, "id": id}

func _resolve_targeting(p: Vector2, queue: bool) -> void:
	var m: PartyMember = targeting.member
	var id: String = targeting.id
	var a := Abilities.get_def(id)
	var ok := false
	match a.target:
		"enemy":
			var foe := actor_at(p, true)
			if foe:
				ok = m.use_ability(id, foe, foe.cell, queue)
		"ally":
			var friend := actor_at(p, false)
			if friend:
				ok = m.use_ability(id, friend, friend.cell, queue)
		"cell":
			ok = m.use_ability(id, null, map_layer.local_to_map(map_layer.to_local(p)), queue)
	if ok:
		targeting = {}

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
	queue_redraw()

func _draw() -> void:
	if _dragging:
		var r := Rect2(_drag_start, _drag_now - _drag_start).abs()
		draw_rect(r, Color(0.95, 0.75, 0.35, 0.12))
		draw_rect(r, Color(0.95, 0.75, 0.35, 0.8), false, 1.0)
	if _marker_t < 1.2:
		var p := map_layer.map_to_local(marker_cell)
		var s := 1.0 - _marker_t / 1.2
		draw_arc(p, 20 + 16 * (1 - s), 0, TAU, 32, Color(0.95, 0.75, 0.35, s), 3.0)
	# Order queues for the selection: dashed legs, gold for moves, red for attacks.
	var alpha := 0.9 if TacticalPause.paused else 0.35
	for m in selection:
		if m.downed:
			continue
		var from := m.position
		var list: Array = []
		if m.current != null:
			list.append(m.current)
		list.append_array(m.orders)
		for o in list:
			var to := map_layer.map_to_local(m.order_target_cell(o))
			var col := Color(0.95, 0.75, 0.35, alpha) if o.type == "move" else (Color(0.9, 0.35, 0.3, alpha) if o.type == "attack" else Color(0.5, 0.8, 1.0, alpha))
			draw_dashed_line(from, to, col, 3.0, 12.0)
			draw_circle(to, 6.0, col)
			from = to
	if not targeting.is_empty():
		var a := Abilities.get_def(targeting.id)
		var mp := get_global_mouse_position()
		draw_arc(mp, 24, 0, TAU, 24, Color(0.5, 0.8, 1.0, 0.9), 3.0)
		if a.target == "cell":
			var pts := PackedVector2Array()
			var r: float = a.radius
			for i in 25:
				var ang := TAU * i / 24.0
				pts.append(mp + Vector2(cos(ang) * r * WorldGen.TILE_W / 2.0, sin(ang) * r * WorldGen.TILE_H / 2.0))
			draw_polyline(pts, Color(0.5, 0.9, 0.5, 0.8), 1.5)
