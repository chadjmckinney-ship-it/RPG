class_name Creature
extends Actor

## Hostile AI: wander near home, chase what it notices, keep a threat table,
## give up past its leash, and (for some) flee when badly hurt.

const AGGRO_RADIUS := 7.0
const LEASH := 14.0

var type_id := "hound"
var home := Vector2i.ZERO
var camp_id := ""
var flee_at := 0.0
var loot := {}
var threat := {}          # Actor -> float
var returning := false
var fled := false
var _wander_t := 0.0
var _spotted := false

func _init() -> void:
	faction = "hostile"

func setup(type: String, at: Vector2i) -> void:
	type_id = type
	var d: Dictionary = CreatureDefs.DEFS[type]
	var stats := d.duplicate(true)
	loot = stats.get("loot", {})
	stats.erase("loot")
	flee_at = stats.get("flee_at", 0.0)
	stats.erase("flee_at")
	setup_stats(stats)
	place_at(at)
	home = at
	set_sprite(ArtMap.make_creature(type))
	bar_height = {"crows": 104.0, "boar": 128.0, "barrow_lord": 150.0, "ash_knight": 140.0}.get(type, 118.0)
	_wander_t = randf_range(1.0, 4.0)

## True while fighting (used by party auto-engage and auto-pause).
func aggressive() -> bool:
	return current != null and current.type == "attack" and not returning

func _process(delta: float) -> void:
	if not TacticalPause.paused and not downed:
		# Leash: never chase too far from home.
		if not returning and cell_distance(home) > LEASH:
			_give_up()
	super._process(delta)

func _give_up() -> void:
	returning = true
	threat.clear()
	issue({"type": "move", "cell": home})
	_spotted = false

func _idle(delta: float) -> void:
	if returning:
		if cell_distance(home) <= 1.5:
			returning = false
			hp = max_hp
		else:
			issue({"type": "move", "cell": home})
		return
	var tgt := _pick_target()
	if tgt:
		if not _spotted:
			_spotted = true
			Events.enemy_spotted.emit(self)
		issue({"type": "attack", "target": tgt})
		return
	_spotted = false
	_wander_t -= delta
	if _wander_t <= 0.0:
		_wander_t = randf_range(3.0, 6.0)
		var c := home + Vector2i(randi_range(-3, 3), randi_range(-3, 3))
		if world.walkable(c) and not world.has_tree(c):
			issue({"type": "move", "cell": c})

func _pick_target() -> Actor:
	var best: Actor = null
	var best_score := -INF
	for a in threat.keys():
		if is_instance_valid(a) and a.alive() and threat[a] > best_score:
			best = a
			best_score = threat[a]
	if best:
		return best
	var best_d := AGGRO_RADIUS
	for other in (ctx.actors if ctx else []):
		if is_instance_valid(other) and other.alive() and other.faction == "party":
			var d := cell_distance(other.cell)
			if d <= best_d:
				best_d = d
				best = other
	return best

func _run_order(delta: float) -> void:
	# Switch to whoever is hurting us most.
	if current != null and current.type == "attack" and not threat.is_empty():
		var t := _pick_target()
		if t and t != current.target:
			current.target = t
	# Fight whoever is already in reach instead of walking off after someone else.
	if current != null and current.type == "attack" and is_instance_valid(current.get("target")) \
			and cell_distance(current.target.cell) > attack_range + 0.01 and ctx:
		for other in ctx.actors:
			if is_instance_valid(other) and other.alive() and other.faction == "party" and cell_distance(other.cell) <= attack_range + 0.01:
				current.target = other
				break
	super._run_order(delta)

func _on_damaged(source: Actor) -> void:
	if source == null or returning:
		return
	threat[source] = threat.get(source, 0.0) + 1.0
	if flee_at > 0.0 and not fled and hp < max_hp * flee_at:
		fled = true
		var away := cell + Vector2i(signi(cell.x - source.cell.x) * 6, signi(cell.y - source.cell.y) * 6)
		log_msg("%s flees!" % display_name)
		issue({"type": "move", "cell": away})
		return
	if current == null or current.get("type") != "attack":
		issue({"type": "attack", "target": source})

func _go_down(source: Actor) -> void:
	super._go_down(source)
	_drop_loot()
	# Linger briefly as a corpse, then vanish.
	var t := get_tree().create_timer(5.0, false)
	t.timeout.connect(queue_free)

func _drop_loot() -> void:
	var got: Array[String] = []
	for k in loot:
		var v = loot[k]
		if v is Array:
			var n := randi_range(v[0], v[1])
			if n > 0:
				GameState.inventory.add(k, n)
				got.append("%d %s" % [n, Items.item_name(k)])
		elif randf() < v:
			GameState.inventory.add(k)
			got.append(Items.item_name(k))
	if not got.is_empty():
		log_msg("Looted: " + ", ".join(got))
