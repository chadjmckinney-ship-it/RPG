class_name Actor
extends Node2D
## Base for everything that fights: stats, an order queue, timed statuses,
## movement along cell paths, and floating combat text. Frozen by tactical pause.

signal died(actor: Actor)

## The main scene: world, ground, pathfinder, actors, log(), fx. Set by main.gd.
static var ctx = null

var display_name := "?"
var faction := "party"
var max_hp := 50.0
var hp := 50.0
var max_stamina := 100.0
var stamina := 100.0
var attack := 10.0
var defense := 5.0
var speed := 140.0
var attack_range := 1.5
var attack_cooldown := 1.2
var ranged := false
var night_bonus := 0.0
var on_hit_status := {}
var abilities: Array[String] = []
var ability_cd := {}

var map_layer: TileMapLayer
var world: WorldGen
var cell := Vector2i.ZERO
var path: Array[Vector2i] = []
var orders: Array = []
var current = null          # order Dictionary in progress
var statuses := {}          # id -> Dictionary with at least "time"
var downed := false
var facing := 1.0
var selected := false:
	set(v):
		selected = v
		queue_redraw()

var _floaters: Array = []
var _walk_t := 0.0
var _swing_cd := 0.0
var _repath := 0.0
var _flash := 0.0
var _lunge := 0.0

func setup_stats(d: Dictionary) -> void:
	for k in d:
		set(k, d[k])
	hp = max_hp
	stamina = max_stamina

func place_at(c: Vector2i) -> void:
	cell = c
	position = map_layer.map_to_local(c)
	path.clear()

func is_hostile_to(other: Actor) -> bool:
	return other.faction != faction

func alive() -> bool:
	return not downed and is_instance_valid(self)

func log_msg(text: String) -> void:
	Events.combat_message.emit(text)

# ---------------------------------------------------------------- orders

func issue(order: Dictionary, queue := false) -> void:
	if downed:
		return
	if queue and (current != null or not orders.is_empty()):
		orders.append(order)
		return
	orders = [order]
	current = null
	path.clear()

## Compatibility with M1: move along a precomputed path.
func order_move(p: Array[Vector2i]) -> void:
	if p.is_empty():
		return
	issue({"type": "move", "cell": p[p.size() - 1], "path": p})

func is_moving() -> bool:
	return not path.is_empty() or (current != null and current.type == "move")

func order_target_cell(o: Dictionary) -> Vector2i:
	if o.has("target") and o.target is Actor and is_instance_valid(o.target):
		return o.target.cell
	return o.get("cell", cell)

# ---------------------------------------------------------------- loop

func _process(delta: float) -> void:
	if TacticalPause.paused:
		return
	_tick_floaters(delta)
	if downed:
		queue_redraw()
		return
	_tick_statuses(delta)
	if downed:
		return
	stamina = minf(max_stamina, stamina + 8.0 * delta)
	_swing_cd -= delta
	_flash = maxf(0.0, _flash - delta)
	_lunge = maxf(0.0, _lunge - delta)
	for k in ability_cd:
		ability_cd[k] = maxf(0.0, ability_cd[k] - delta)
	if current == null and orders.is_empty():
		_idle(delta)
	if current == null and not orders.is_empty():
		_begin(orders.pop_front())
	if current != null:
		_run_order(delta)
	queue_redraw()

## Override: what to do with no orders.
func _idle(_delta: float) -> void:
	pass

func _begin(o: Dictionary) -> void:
	current = o
	path.clear()
	if o.type == "move":
		var p: Array[Vector2i] = []
		if o.has("path"):
			p.assign(o.path)
		else:
			p = _path_to(o.cell)
		if not p.is_empty() and p[0] == cell:
			p.remove_at(0)
		path = p
		if path.is_empty() and o.cell != cell:
			current = null

func _run_order(delta: float) -> void:
	var o: Dictionary = current
	if o.type == "move":
		_follow_path(delta)
		if path.is_empty():
			current = null
		return
	# attack / ability
	var tgt = o.get("target")
	if tgt != null and (not is_instance_valid(tgt) or tgt.downed):
		current = null
		path.clear()
		return
	var tcell := order_target_cell(o)
	var reach := attack_range
	if o.type == "ability":
		reach = maxf(1.0, Abilities.get_def(o.id).get("range", 1.0))
		if Abilities.get_def(o.id).target == "self":
			reach = INF
	if cell_distance(tcell) <= reach + 0.01:
		path.clear()
		_face(map_layer.map_to_local(tcell))
		if o.type == "attack":
			if _swing_cd <= 0.0:
				_swing_cd = attack_cooldown
				_strike(tgt)
		else:
			_cast(o.id, tgt, tcell)
			current = null
		return
	_repath -= delta
	if _repath <= 0.0 or path.is_empty():
		_repath = 0.5
		path = _path_to(tcell)
		if not path.is_empty() and path[0] == cell:
			path.remove_at(0)
	_follow_path(delta)

func cell_distance(c: Vector2i) -> float:
	return Vector2(c - cell).length()

func _path_to(c: Vector2i) -> Array[Vector2i]:
	var p: Array[Vector2i] = []
	if ctx and ctx.pathfinder:
		p = ctx.pathfinder.find_path(cell, c)
	if p.is_empty() and c != cell:
		# Greedy fallback outside the path window: one step that closes distance.
		var best := cell
		var best_d := cell_distance(c)
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
			var n: Vector2i = cell + d
			var dd := Vector2(c - n).length()
			if dd < best_d and world.walkable(n) and not world.has_tree(n):
				best = n
				best_d = dd
		if best != cell:
			p = [best]
	return p

func _follow_path(delta: float) -> void:
	if path.is_empty() or statuses.has("root"):
		return
	var target := map_layer.map_to_local(path[0])
	var mult: float = statuses.slow.mult if statuses.has("slow") else 1.0
	var step := speed * mult * delta / world.cost(path[0])
	var to := target - position
	_face(target)
	_walk_t += delta
	if to.length() <= step:
		position = target
		cell = path[0]
		path.remove_at(0)
	else:
		position += to.normalized() * step

func _face(p: Vector2) -> void:
	if absf(p.x - position.x) > 1.0:
		facing = signf(p.x - position.x)

# ---------------------------------------------------------------- combat

func _strike(tgt: Actor) -> void:
	_lunge = 0.18
	if ranged and ctx and ctx.fx:
		ctx.fx.tracer(global_position + Vector2(0, -26), tgt.global_position + Vector2(0, -20), Color(0.9, 0.85, 0.7))
	var r := Effect.damage(self, tgt)
	tgt.take_damage(r.amount, self, r.crit)
	if not on_hit_status.is_empty() and tgt.alive():
		tgt.add_status(on_hit_status.duplicate())

func can_use(id: String) -> bool:
	var a := Abilities.get_def(id)
	return not a.is_empty() and not downed and ability_cd.get(id, 0.0) <= 0.0 and stamina >= a.cost

func use_ability(id: String, target = null, target_cell := Vector2i.ZERO, queue := false) -> bool:
	if not can_use(id):
		return false
	var o := {"type": "ability", "id": id, "cell": target_cell}
	if target is Actor:
		o.target = target
	elif Abilities.get_def(id).target == "self":
		o.target = self
	issue(o, queue)
	return true

func _cast(id: String, tgt, tcell: Vector2i) -> void:
	var a := Abilities.get_def(id)
	if not can_use(id):
		return
	stamina -= a.cost
	ability_cd[id] = a.cd
	_lunge = 0.2
	log_msg("%s: %s" % [display_name, a.name])
	match a.kind:
		"damage":
			if a.get("ranged", false) and ctx and ctx.fx:
				ctx.fx.tracer(global_position + Vector2(0, -26), tgt.global_position + Vector2(0, -20), Color(1.0, 0.8, 0.4))
			var r := Effect.damage(self, tgt, a.power)
			tgt.take_damage(r.amount, self, r.crit)
			if a.has("status") and tgt.alive():
				tgt.add_status(a.status.duplicate())
		"heal":
			tgt.heal(a.heal)
		"self_status":
			add_status(a.status.duplicate())
		"area_status":
			if ctx and ctx.fx:
				ctx.fx.ring(map_layer.map_to_local(tcell), a.radius * 32.0, Color(0.6, 0.9, 0.5))
			for other in (ctx.actors if ctx else []):
				if is_instance_valid(other) and other.alive() and is_hostile_to(other) and Vector2(other.cell - tcell).length() <= a.radius:
					other.add_status(a.status.duplicate())

func take_damage(amount: float, source: Actor = null, crit := false) -> void:
	if downed:
		return
	if statuses.has("guard"):
		amount = maxf(1.0, roundf(amount * (1.0 - statuses.guard.dr)))
	hp -= amount
	_flash = 0.15
	_floaters.append({"text": ("%d!" if crit else "%d") % int(amount), "color": Color(1, 0.85, 0.3) if crit else (Color(1, 0.45, 0.4) if faction == "party" else Color(1, 1, 1)), "t": 0.0})
	if source:
		_on_damaged(source)
	if hp <= 0.0:
		hp = 0.0
		_go_down(source)

func heal(amount: float) -> void:
	if downed:
		return
	var before := hp
	hp = minf(max_hp, hp + amount)
	if hp > before:
		_floaters.append({"text": "+%d" % int(hp - before), "color": Color(0.5, 1, 0.55), "t": 0.0})

func revive(fraction: float) -> void:
	downed = false
	hp = maxf(1.0, max_hp * fraction)
	statuses.clear()
	queue_redraw()

func add_status(s: Dictionary) -> void:
	s.acc = 0.0
	statuses[s.id] = s

func _tick_statuses(delta: float) -> void:
	for id in statuses.keys():
		var s: Dictionary = statuses[id]
		s.time -= delta
		if s.has("dps"):
			s.acc += delta
			if s.acc >= 1.0:
				s.acc -= 1.0
				take_damage(s.dps)
				if downed:
					return
		if s.time <= 0.0:
			statuses.erase(id)

func _on_damaged(_source: Actor) -> void:
	pass

func _go_down(source: Actor) -> void:
	downed = true
	orders.clear()
	current = null
	path.clear()
	statuses.clear()
	log_msg("%s %s%s" % [display_name, "falls" if faction == "party" else "is slain", (" to " + source.display_name) if source else ""])
	died.emit(self)
	queue_redraw()

# ---------------------------------------------------------------- drawing

func _tick_floaters(delta: float) -> void:
	for f in _floaters:
		f.t += delta
	_floaters = _floaters.filter(func(f): return f.t < 1.0)

func _draw() -> void:
	if selected:
		draw_arc(Vector2.ZERO, 16, 0, TAU, 32, Color(0.95, 0.75, 0.35, 0.9), 2.0)
		_ellipse(Vector2.ZERO, Vector2(17, 8.5), Color(0.95, 0.75, 0.35, 0.18))
	_ellipse(Vector2(0, 1), Vector2(11, 5), Color(0, 0, 0, 0.35))
	if downed:
		draw_set_transform(Vector2(0, -4), -PI / 2 * facing, Vector2(0.9, 0.9))
		_draw_body(0.0)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	else:
		var bob := sin(_walk_t * 14.0) * 1.5 if not path.is_empty() else 0.0
		draw_set_transform(Vector2(facing * _lunge * 30.0, 0), 0, Vector2.ONE)
		_draw_body(bob)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		if _flash > 0.0:
			draw_circle(Vector2(0, -26), 14, Color(1, 1, 1, _flash * 2.5))
		_draw_bars()
	for f in _floaters:
		var y: float = -58.0 - f.t * 26.0
		var c: Color = f.color
		c.a = 1.0 - maxf(0.0, f.t - 0.6) / 0.4
		draw_string(ThemeDB.fallback_font, Vector2(-12, y + 1), f.text, HORIZONTAL_ALIGNMENT_CENTER, 24, 15, Color(0, 0, 0, c.a))
		draw_string(ThemeDB.fallback_font, Vector2(-13, y), f.text, HORIZONTAL_ALIGNMENT_CENTER, 24, 15, c)

func _draw_bars() -> void:
	if faction == "party" and hp >= max_hp and statuses.is_empty():
		return
	var w := 28.0
	var y := -56.0
	draw_rect(Rect2(-w / 2 - 1, y - 1, w + 2, 5), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(-w / 2, y, w * hp / max_hp, 3), Color(0.85, 0.25, 0.2) if faction != "party" else Color(0.4, 0.8, 0.4))
	var x := -w / 2
	for id in statuses:
		var col: Color = {"poison": Color(0.6, 0.9, 0.3), "slow": Color(0.4, 0.6, 1), "root": Color(0.6, 0.9, 0.5), "guard": Color(0.9, 0.85, 0.5)}.get(id, Color.WHITE)
		draw_rect(Rect2(x, y - 6, 4, 4), col)
		x += 6

## Override to draw the figure; origin is the feet.
func _draw_body(_bob: float) -> void:
	draw_rect(Rect2(-6, -30, 12, 30), Color.GRAY)

func _ellipse(c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_colored_polygon(pts, col)
