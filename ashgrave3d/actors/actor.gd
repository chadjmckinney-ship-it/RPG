class_name Actor
extends Node3D
## Anything that walks the grid and fights: party members, villagers, creatures.
## Stands on cell centres at ground height, follows A* paths and runs an order queue:
##   move, attack (chase into reach, swing on cooldown), ability (move into range, cast), interact.
## Reach, range and positions for rules are in cells; the body is a CharacterModel.

signal died(actor: Actor)

static var ctx: Node   # the main scene (actors, world, pathfinder, fx)

var display_name := "?"
var faction := "party"
var max_hp := 50.0
var hp := 50.0
var max_stamina := 100.0
var stamina := 100.0
var attack := 10.0
var defense := 5.0
var speed := 140.0          # legacy units; metres/second = speed * SPEED_SCALE
var attack_range := 1.5
var attack_cooldown := 1.2
var ranged := false
var night_bonus := 0.0
var evasion := 0.0
var lifesteal := 0.0
var on_hit_status := {}
var riposte := 0.0
var ability_mods := {}
var abilities: Array[String] = []
var ability_cd := {}

var world: WorldGen
var cell := Vector2i.ZERO
var path: Array[Vector2i] = []
var orders: Array = []
var current = null
var statuses := {}
var downed := false
var body: CharacterModel
var height := 1.8           # where bars and floating text sit (metres)
var hovered := false        # enemy under the cursor
var floaters: Array = []    # {text, color, t} drawn by the world overlay
var selected := false:
	set(v):
		selected = v
		if _ring:
			_ring.visible = v

const SPEED_SCALE := 3.0 / 160.0     # 160 legacy units = 3 m/s
const RUN_SPEED := 140.0
## Which way anyone outside the party turns while standing about out of combat: toward the
## camera's default spot (RtsCamera yaw 45 puts it south-east, +X +Z), so their faces show.
const REST_FACING := Vector3(1, 0, 1)
## The direction idle folk actually face: toward the camera as it is now (main.gd updates it
## from RtsCamera.facing() every frame; REST_FACING until then).
static var rest_facing := REST_FACING
## How long someone keeps facing whoever spoke to them, and how close the speaker must stay (cells).
const ATTENTION_TIME := 8.0
const ATTENTION_RANGE := 4.0

## Whoever is talking to this actor (see attend()); they face them instead of rest_facing.
var attention: Node3D = null
var _attention_t := 0.0
var _blocked_t := 0.0

## How long a walker waits for someone in its way before squeezing past (seconds), and how far
## around itself it looks for people to step around (cells).
const WAIT_LIMIT := 1.5
const AVOID_RADIUS := 6.0

var _ring: MeshInstance3D
var _swing_cd := 0.0
var _repath := 0.0
var _combat_t := 0.0

func setup_stats(d: Dictionary) -> void:
	for k in d:
		set(k, d[k])
	hp = max_hp
	stamina = max_stamina

var body_tint := Color.WHITE
var body_size := 1.0

func set_body(model_id: String, tint := Color.WHITE, size := 1.0) -> void:
	body_tint = tint
	body_size = size
	if body:
		body.queue_free()
	body = CharacterModel.new()
	add_child(body)
	body.setup(model_id, tint, size)
	height = 1.9 * size
	if _ring == null:
		_ring = MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.42
		torus.outer_radius = 0.5
		torus.rings = 24
		_ring.mesh = torus
		_ring.scale = Vector3(1, 0.05, 1)
		_ring.position.y = 0.04
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.8, 0.35)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ring.material_override = mat
		add_child(_ring)
		_ring.visible = selected

## Only "hostile" creatures fight; party and neutral villagers never attack each other.
func is_hostile_to(other: Actor) -> bool:
	return (other.faction == "hostile") != (faction == "hostile")

func alive() -> bool:
	return not downed and is_instance_valid(self)

func log_msg(text: String) -> void:
	Events.combat_message.emit(text)

func place_at(c: Vector2i) -> void:
	cell = c
	position = world.cell_to_world(c)
	path.clear()

func cell_distance(c: Vector2i) -> float:
	return Vector2(cell - c).length()

func in_combat() -> bool:
	return _combat_t > 0.0

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

func order_move(p: Array[Vector2i]) -> void:
	if p.is_empty():
		return
	issue({"type": "move", "cell": p[p.size() - 1], "path": p})

func is_moving() -> bool:
	return not path.is_empty() or (current != null and current.type == "move")

func order_target_cell(o: Dictionary) -> Vector2i:
	if o.has("target") and is_instance_valid(o.target) and o.target is Actor:
		return o.target.cell
	return o.get("cell", cell)

# ---------------------------------------------------------------- loop

func _process(delta: float) -> void:
	if TacticalPause.paused:
		return
	for f in floaters:
		f.t += delta
	floaters = floaters.filter(func(f): return f.t < 1.1)
	if downed:
		_update_body()
		return
	_tick_statuses(delta)
	if downed:
		return
	stamina = minf(max_stamina, stamina + 8.0 * delta)
	_combat_t -= delta
	_attention_t -= delta
	_swing_cd -= delta
	for k in ability_cd:
		ability_cd[k] = maxf(0.0, ability_cd[k] - delta)
	if current == null and orders.is_empty():
		_idle(delta)
	if current == null and not orders.is_empty():
		_begin(orders.pop_front())
	if current != null:
		_run_order(delta)
	_update_body()

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
	if o.type == "interact":
		var node = o.get("node")
		if node == null or not is_instance_valid(node):
			current = null
			return
		var ncell: Vector2i = node.cell if node is Actor else o.cell
		if cell_distance(ncell) <= o.get("range", 1.6) + 0.01:
			path.clear()
			_face(node.global_position)
			current = null
			node.on_interact(self)
			return
		_chase(ncell, delta)
		return
	# attack / ability
	var tgt = o.get("target")
	# A freed object compares equal to null, so test the key, not the value.
	if o.has("target") and (not is_instance_valid(tgt) or tgt.downed):
		current = null
		path.clear()
		return
	var tcell := order_target_cell(o)
	var reach := attack_range
	if o.type == "ability":
		reach = maxf(1.0, Abilities.effective(self, o.id).get("range", 1.0))
		if Abilities.get_def(o.id).target == "self":
			reach = INF
	if cell_distance(tcell) <= reach + 0.01:
		path.clear()
		_face(world.cell_to_world(tcell))
		if o.type == "attack":
			if _swing_cd <= 0.0:
				_swing_cd = attack_cooldown
				_strike(tgt)
		else:
			_cast(o.id, tgt, tcell)
			current = null
		return
	_chase(tcell, delta)

func _chase(tcell: Vector2i, delta: float) -> void:
	_repath -= delta
	if _repath <= 0.0 or path.is_empty():
		_repath = 0.5
		path = _path_to(tcell)
		if not path.is_empty() and path[0] == cell:
			path.remove_at(0)
		# the target cell itself may be blocked (a building front): stop one short
		if not path.is_empty() and path[path.size() - 1] == tcell and not world.walkable(tcell):
			path.remove_at(path.size() - 1)
	_follow_path(delta)

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

func move_speed() -> float:
	var mult: float = statuses.slow.mult if statuses.has("slow") else 1.0
	return speed * SPEED_SCALE * mult

func _follow_path(delta: float) -> void:
	if path.is_empty() or statuses.has("root"):
		return
	# about to leave a cell centre: step around party members and villagers in the way
	var here := world.cell_to_world(cell)
	if Vector2(position.x - here.x, position.z - here.z).length_squared() < 0.0004 and _occupied(path[0]):
		if not _step_around():
			_blocked_t += delta
			if _blocked_t < WAIT_LIMIT:
				_face(world.cell_to_world(path[0]))
				return
		if path.is_empty():
			return
	_blocked_t = 0.0
	var target := world.cell_to_world(path[0])
	var to := target - position
	to.y = 0.0
	var step := move_speed() * delta / world.cost(path[0])
	_face(target)
	if to.length() <= step:
		position = target
		cell = path[0]
		path.remove_at(0)
	else:
		position += to.normalized() * step
		position.y = world.ground_y(position)

## Party members and villagers keep out of each other's way; fights (anything hostile) don't.
func _avoids(other: Actor) -> bool:
	return faction != "hostile" and other.faction != "hostile" and not other.downed

## Someone we avoid stands on c, or is stepping into it.
func _occupied(c: Vector2i) -> bool:
	return _people_cells().has(c)

func _people_cells() -> Array:
	var out: Array = []
	if faction == "hostile" or ctx == null or not is_instance_valid(ctx):
		return out
	for a in ctx.actors:
		if a == self or not is_instance_valid(a) or not _avoids(a):
			continue
		var c: Vector2i = a.cell if a.path.is_empty() else a.path[0]
		if Vector2(c - cell).length() <= AVOID_RADIUS:
			out.append(c)
	return out

## Re-plan around the people in the way. If the goal itself is taken, head for the nearest free
## cell instead. False when there's no way through right now (the caller waits).
func _step_around() -> bool:
	if ctx == null or not is_instance_valid(ctx) or ctx.pathfinder == null:
		return false
	var blocked := _people_cells()
	var goal: Vector2i = path[path.size() - 1]
	if blocked.has(goal):
		goal = _free_cell_near(goal, blocked)
		if goal == cell:
			path.clear()
			return true
		_goal_moved(goal)
	var p: Array[Vector2i] = ctx.pathfinder.find_path_avoiding(cell, goal, blocked)
	if not p.is_empty() and p[0] == cell:
		p.remove_at(0)
	if p.is_empty():
		return false
	path = p
	return true

func _free_cell_near(c: Vector2i, blocked: Array) -> Vector2i:
	for r in range(1, 4):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var n := c + Vector2i(dx, dy)
				if n == cell or (world.walkable(n) and not world.has_tree(n) and not blocked.has(n)):
					return n
	return cell

## Override: the goal was taken and replaced by a nearby cell (villagers remember it as their spot).
func _goal_moved(_c: Vector2i) -> void:
	pass

func _face(p: Vector3) -> void:
	if body:
		body.face(p - position)

func _update_body() -> void:
	if body == null:
		return
	if downed:
		body.play("die")
	elif body.anim in CharacterModel.ONE_SHOT:
		return
	elif not path.is_empty() and not statuses.has("root"):
		body.move_speed = move_speed()
		body.play("run" if speed * (statuses.slow.mult if statuses.has("slow") else 1.0) >= RUN_SPEED else "walk")
	else:
		body.play("ready" if in_combat() else "idle")
		if faction != "party" and not in_combat():
			body.face(attention.global_position - global_position if is_attending() else rest_facing)

## Stop and turn to someone who is talking to us; the turn is instant, since dialogue pauses the game.
func attend(who: Node3D) -> void:
	attention = who
	_attention_t = ATTENTION_TIME
	orders.clear()
	current = null
	path.clear()
	if body:
		var d := who.global_position - global_position
		if Vector2(d.x, d.z).length_squared() > 0.0001:
			body.rotation.y = atan2(-d.x, -d.z)

func is_attending() -> bool:
	if _attention_t <= 0.0 or attention == null or not is_instance_valid(attention):
		return false
	return world.world_to_cell(attention.global_position).distance_to(cell) <= ATTENTION_RANGE

# ---------------------------------------------------------------- combat

func _strike(tgt: Actor) -> void:
	_combat_t = 4.0
	if body:
		body.play("shoot" if ranged else "attack", true)
	Audio.play("bow" if ranged else "swing")
	if ranged and ctx and ctx.fx:
		ctx.fx.tracer(global_position + Vector3(0, 1.3, 0), tgt.global_position + Vector3(0, 1.1, 0), Color(0.9, 0.85, 0.7))
	if tgt.evasion > 0.0 and randf() < tgt.evasion:
		tgt.floaters.append({"text": "miss", "color": Color(0.7, 0.7, 0.75), "t": 0.0})
		return
	var r := Effect.damage(self, tgt)
	tgt.take_damage(r.amount, self, r.crit)
	if lifesteal > 0.0:
		heal(r.amount * lifesteal)
	if not on_hit_status.is_empty() and tgt.alive():
		tgt.add_status(on_hit_status.duplicate())

func can_use(id: String) -> bool:
	var a := Abilities.effective(self, id)
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
	var a := Abilities.effective(self, id)
	if not can_use(id):
		return
	stamina -= a.cost
	ability_cd[id] = a.cd
	_combat_t = 4.0
	if body:
		body.play("attack" if a.kind in ["damage", "area_damage"] and not a.get("ranged", false) else ("shoot" if a.get("ranged", false) else "cast"), true)
	log_msg("%s: %s" % [display_name, a.name])
	var fx = ctx.fx if ctx else null
	match a.kind:
		"damage":
			if a.get("ranged", false) and fx:
				fx.tracer(global_position + Vector3(0, 1.3, 0), tgt.global_position + Vector3(0, 1.1, 0), Color(1.0, 0.8, 0.4))
			var r := Effect.damage(self, tgt, a.power)
			tgt.take_damage(r.amount, self, r.crit)
			if a.has("status") and tgt.alive():
				tgt.add_status(a.status.duplicate())
		"heal":
			tgt.heal(a.heal)
			if fx:
				fx.glow(tgt.global_position, Color(0.5, 1.0, 0.6))
		"self_status":
			add_status(a.status.duplicate())
			if fx:
				fx.glow(global_position, Color(0.95, 0.85, 0.5))
		"area_status":
			if fx:
				fx.ring(world.cell_to_world(tcell), a.radius * WorldGen.CELL, Color(0.6, 0.9, 0.5))
			for other in (ctx.actors if ctx else []):
				if is_instance_valid(other) and other.alive() and is_hostile_to(other) and Vector2(other.cell - tcell).length() <= a.radius:
					other.add_status(a.status.duplicate())
		"area_damage", "area_heal":
			var centre := cell if a.target == "self" else tcell
			var healing: bool = a.kind == "area_heal"
			if fx:
				fx.ring(world.cell_to_world(centre), a.radius * WorldGen.CELL, Color(0.5, 1.0, 0.6) if healing else Color(1.0, 0.6, 0.3))
				if healing:
					fx.glow(world.cell_to_world(centre), Color(0.5, 1.0, 0.6), a.radius * WorldGen.CELL)
				elif a.get("ranged", false):
					fx.volley(global_position + Vector3(0, 1.3, 0), world.cell_to_world(centre), a.radius * WorldGen.CELL)
			for other in (ctx.actors if ctx else []):
				if not is_instance_valid(other) or not other.alive() or Vector2(other.cell - centre).length() > a.radius:
					continue
				if healing and not is_hostile_to(other):
					other.heal(a.heal)
				elif not healing and is_hostile_to(other):
					var r := Effect.damage(self, other, a.power)
					other.take_damage(r.amount, self, r.crit)

func take_damage(amount: float, source: Actor = null, crit := false) -> void:
	if downed:
		return
	if statuses.has("guard"):
		amount = maxf(1.0, roundf(amount * (1.0 - statuses.guard.dr)))
	hp -= amount
	_combat_t = 4.0
	if body:
		body.flash()
	Audio.play("hit")
	floaters.append({"text": ("%d!" if crit else "%d") % int(amount), "color": Color(1, 0.85, 0.3) if crit else (Color(1, 0.45, 0.4) if faction == "party" else Color(1, 1, 1)), "t": 0.0})
	if source:
		_on_damaged(source)
	if hp <= 0.0:
		hp = 0.0
		_go_down(source)

func _on_damaged(_source: Actor) -> void:
	pass

func heal(amount: float) -> void:
	if downed:
		return
	var before := hp
	hp = minf(max_hp, hp + amount)
	if hp > before and amount >= 5.0:
		Audio.play("heal")
	if hp > before:
		floaters.append({"text": "+%d" % int(hp - before), "color": Color(0.5, 1, 0.55), "t": 0.0})

func revive(fraction: float) -> void:
	downed = false
	if body:
		body.play("idle", true)
	hp = maxf(1.0, max_hp * fraction)
	statuses.clear()

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

func _go_down(source: Actor) -> void:
	downed = true
	Audio.play("death", 0.15)
	orders.clear()
	current = null
	path.clear()
	statuses.clear()
	log_msg("%s %s%s" % [display_name, "falls" if faction == "party" else "is slain", (" to " + source.display_name) if source else ""])
	died.emit(self)
