class_name PartyController
extends Control
## Mouse and keys for the party (a full-screen overlay so it can draw the drag box):
##  left-click / drag: select   right-click: move in formation, attack the enemy under the cursor,
##  or send the leader to talk to a villager / gather from a node
##  shift: queue   Q / E / R: the first selected member's abilities   1-4 / Tab: pick members.

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
## Ability waiting for a target click: {member, id}
var targeting := {}
var _hovered: Actor = null

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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

## The actor drawn nearest a screen point; want_hostile picks creatures, else party members.
func actor_at(p: Vector2, want_hostile: bool) -> Actor:
	var best: Actor = null
	var best_d := PICK_RADIUS
	for a in (Actor.ctx.actors if Actor.ctx else []):
		if not is_instance_valid(a) or a.downed or (a.faction == "hostile") != want_hostile:
			continue
		if not want_hostile and a.faction != "party":
			continue
		if cam.camera.is_position_behind(a.global_position):
			continue
		var d := screen_pos(a).distance_to(p)
		if d < best_d:
			best_d = d
			best = a
	return best

## A villager (neutral actor) near a screen point.
func villager_at(p: Vector2) -> Actor:
	var best: Actor = null
	var best_d := PICK_RADIUS
	for a in (Actor.ctx.actors if Actor.ctx else []):
		if not is_instance_valid(a) or a.downed or a.faction != "neutral":
			continue
		if cam.camera.is_position_behind(a.global_position):
			continue
		var d := screen_pos(a).distance_to(p)
		if d < best_d:
			best_d = d
			best = a
	return best

## A gather node near a screen point.
func interactable_at(p: Vector2) -> Node3D:
	var best: Node3D = null
	var best_d := PICK_RADIUS * 0.8
	for n in (Actor.ctx.interactables if Actor.ctx else []):
		if not is_instance_valid(n) or cam.camera.is_position_behind(n.global_position):
			continue
		var d := cam.camera.unproject_position(n.global_position + Vector3(0, 0.3, 0)).distance_to(p)
		if d < best_d:
			best_d = d
			best = n
	return best

## The lead selected member walks over and interacts (talk, gather).
func order_interact(node: Node, at: Vector2i, reach: float, queue := false) -> void:
	var m := leader()
	if m.downed:
		return
	m.issue({"type": "interact", "node": node, "cell": at, "range": reach}, queue)
	marker = world.cell_to_world(at)
	_marker_t = 0.0

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
		if event.button_index == MOUSE_BUTTON_LEFT and not targeting.is_empty():
			if event.pressed:
				_resolve_targeting(event.position, event.shift_pressed)
			get_viewport().set_input_as_handled()
			return
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
			if not targeting.is_empty():
				_resolve_targeting(event.position, event.shift_pressed)
			else:
				var foe := actor_at(event.position, true)
				var folk := villager_at(event.position) if foe == null else null
				var node := interactable_at(event.position) if foe == null and folk == null else null
				if foe:
					order_attack(foe, event.shift_pressed)
				elif folk:
					order_interact(folk, folk.cell, 2.0, event.shift_pressed)
				elif node:
					order_interact(node, node.cell, 1.5, event.shift_pressed)
				else:
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
		elif event.keycode in [KEY_Q, KEY_E, KEY_R]:
			begin_ability({KEY_Q: 0, KEY_E: 1, KEY_R: 2}[event.keycode], event.shift_pressed)
		elif event.keycode == KEY_ESCAPE and not targeting.is_empty():
			targeting = {}
			get_viewport().set_input_as_handled()

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

func order_attack(foe: Actor, queue := false) -> void:
	for m in selection:
		m.issue({"type": "attack", "target": foe}, queue)
	marker = foe.global_position
	_marker_t = 0.0

## Ability slot on the first selected member; self-target fires at once, others wait for a click.
func begin_ability(slot: int, queue := false) -> void:
	var m := leader()
	if slot >= m.abilities.size():
		return
	var id: String = m.abilities[slot]
	var a := Abilities.effective(m, id)
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
	var a := Abilities.effective(m, id)
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
			var gp = cam.ground_point(p)
			if gp != null:
				ok = m.use_ability(id, null, world.world_to_cell(gp), queue)
	if ok:
		targeting = {}

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
	var mp := get_viewport().get_mouse_position()
	var foe := actor_at(mp, true) if Actor.ctx else null
	if foe == null and Actor.ctx:
		foe = villager_at(mp)
	if foe != _hovered:
		if is_instance_valid(_hovered):
			_hovered.hovered = false
		_hovered = foe
		if foe:
			foe.hovered = true
	queue_redraw()

func _draw() -> void:
	if _dragging:
		var r := Rect2(_drag_start, _drag_now - _drag_start).abs()
		draw_rect(r, Color(0.95, 0.75, 0.35, 0.12))
		draw_rect(r, Color(0.95, 0.75, 0.35, 0.8), false, 1.0)
	if not targeting.is_empty():
		var a := Abilities.effective(targeting.member, targeting.id)
		var mp := get_viewport().get_mouse_position()
		draw_arc(mp, 22, 0, TAU, 24, Color(0.5, 0.8, 1.0, 0.9), 2.0)
		if a.target == "cell" and a.has("radius"):
			var gp = cam.ground_point(mp)
			if gp != null:
				# ground ring preview: project points around the radius
				var pts := PackedVector2Array()
				for i in 33:
					var ang := TAU * i / 32.0
					var w: Vector3 = gp + Vector3(cos(ang), 0, sin(ang)) * a.radius * WorldGen.CELL
					w.y = world.ground_y(w) + 0.05
					pts.append(cam.camera.unproject_position(w))
				draw_polyline(pts, Color(0.5, 0.8, 1.0, 0.8), 2.0)
		draw_string(UiTheme.font(), mp + Vector2(-120, 38), "%s — click a target (Esc cancels)" % a.name, HORIZONTAL_ALIGNMENT_CENTER, 240, UiTheme.fs(12), Color(0.6, 0.85, 1.0))
	if _marker_t < 0.8 and not cam.camera.is_position_behind(marker):
		var p := cam.camera.unproject_position(marker)
		var k := 1.0 - _marker_t / 0.8
		draw_arc(p, 10.0 + 14.0 * _marker_t, 0, TAU, 24, Color(0.95, 0.8, 0.4, k), 2.0)
