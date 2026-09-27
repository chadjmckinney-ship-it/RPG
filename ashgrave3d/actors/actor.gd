class_name Actor
extends Node3D
## Anything that walks the grid: party members, villagers, creatures.
## Stands on cell centres at ground height, follows A* paths, runs an order queue, and drives
## its CharacterModel (walk/run/idle). Combat is layered on in N2.

static var ctx: Node   # the main scene (actors list, world, pathfinder)

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
var selected := false:
	set(v):
		selected = v
		if _ring:
			_ring.visible = v

const SPEED_SCALE := 3.0 / 160.0     # 160 legacy units = 3 m/s
const RUN_SPEED := 140.0

var _ring: MeshInstance3D
var _vel := 0.0

func setup_stats(d: Dictionary) -> void:
	for k in d:
		set(k, d[k])
	hp = max_hp
	stamina = max_stamina

func set_body(model_id: String, tint := Color.WHITE, size := 1.0) -> void:
	if body:
		body.queue_free()
	body = CharacterModel.new()
	add_child(body)
	body.setup(model_id, tint, size)
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
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.75, 0.3)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_ring.material_override = mat
		add_child(_ring)
		_ring.visible = selected

func alive() -> bool:
	return not downed

func place_at(c: Vector2i) -> void:
	cell = c
	position = world.cell_to_world(c)
	path.clear()

func cell_distance(c: Vector2i) -> float:
	return Vector2(cell - c).length()

# ---------------------------------------------------------------- orders

func issue(o: Dictionary, queue := false) -> void:
	if queue and (current != null or not orders.is_empty()):
		orders.append(o)
		return
	orders.clear()
	current = null
	_begin(o)

func order_move(p: Array[Vector2i]) -> void:
	orders.clear()
	current = {"type": "move", "cell": p[p.size() - 1] if not p.is_empty() else cell}
	path = p.duplicate()
	if not path.is_empty() and path[0] == cell:
		path.remove_at(0)

func _begin(o: Dictionary) -> void:
	current = o
	match o.type:
		"move":
			path = ctx.pathfinder.find_path(cell, o.cell) if ctx else []
			if not path.is_empty() and path[0] == cell:
				path.remove_at(0)
			if path.is_empty():
				current = null

func _next_order() -> void:
	current = null
	if not orders.is_empty():
		_begin(orders.pop_front())

# ---------------------------------------------------------------- per frame

func _process(delta: float) -> void:
	if TacticalPause.paused or downed:
		return
	if current == null and orders.is_empty():
		_idle(delta)
	if not path.is_empty():
		_step_path(delta)
	elif current != null and current.type == "move":
		_next_order()
	_update_body()

func _idle(_delta: float) -> void:
	pass

func move_speed() -> float:
	var mult: float = statuses.slow.mult if statuses.has("slow") else 1.0
	return speed * SPEED_SCALE * mult

func _step_path(delta: float) -> void:
	var target := world.cell_to_world(path[0])
	var to := target - position
	to.y = 0.0
	var step := move_speed() * delta / world.cost(path[0])
	_vel = move_speed()
	if body:
		body.face(to)
	if to.length() <= step:
		position = target
		cell = path[0]
		path.remove_at(0)
	else:
		position += to.normalized() * step
		position.y = world.ground_y(position)

func _update_body() -> void:
	if body == null:
		return
	if downed:
		body.play("die")
	elif body.anim in CharacterModel.ONE_SHOT:
		return
	elif not path.is_empty():
		body.move_speed = move_speed()
		body.play("run" if speed >= RUN_SPEED else "walk")
	else:
		body.play("idle")
