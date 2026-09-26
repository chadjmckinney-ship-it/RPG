class_name Creature
extends Actor

const HUMANS := {
	"bandit": {"skin": Color("c89e7c"), "hair": Color("3a2a1e"), "coat": Color("4a3a2a"), "body": Color("6a4a32"), "trim": Color("8a7040"), "legs": Color("2a2420"), "hood": true},
	"crossbow": {"skin": Color("b89070"), "hair": Color("2a2018"), "coat": Color("3e3a30"), "body": Color("5a4e3a"), "trim": Color("7a6a40"), "legs": Color("2a2420")},
	"ash_knight": {"skin": Color("2a2624"), "hair": Color("1a1614"), "coat": Color("2e2a28"), "body": Color("4a4440"), "trim": Color("c85a20"), "legs": Color("201c1a"), "hood": true},
}
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
	var t := get_tree().create_timer(2.0, false)
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

func _draw_body(bob: float) -> void:
	var f := facing
	var y := -bob
	if type_id == "barrow_lord" or type_id == "ash_knight":
		draw_set_transform(Vector2.ZERO, 0, Vector2(1.35, 1.35))
	if HUMANS.has(type_id):
		Figures.draw_person(self, HUMANS[type_id], f, bob, _walk_t, not path.is_empty(), ranged)
		if type_id == "ash_knight":
			draw_circle(Vector2(f * 2, y - 46), 2.0, Color(1.0, 0.4, 0.1))
			draw_circle(Vector2(0, y - 24), 16, Color(1.0, 0.35, 0.1, 0.12))
		return
	match type_id:
		"crows":
			for i in 4:
				var t := _walk_t * 6.0 + i * 1.7
				var p := Vector2(sin(t) * 10.0 + (i - 1.5) * 6.0, y - 22.0 - cos(t * 1.3) * 8.0 - i * 3.0)
				var wing := 5.0 + sin(t * 3.0) * 3.0
				draw_line(p + Vector2(-wing, -2), p, Color("141414"), 2.0)
				draw_line(p, p + Vector2(wing, -2), Color("141414"), 2.0)
				draw_circle(p, 2.2, Color("1c1c1e"))
		"wight", "ghoul":
			var skin := Color("7a8a6a") if type_id == "wight" else Color("6a625a")
			draw_rect(Rect2(-4, y - 12, 3, 12), skin.darkened(0.3))
			draw_rect(Rect2(2, y - 12, 3, 12), skin.darkened(0.3))
			draw_colored_polygon(PackedVector2Array([Vector2(-8, y - 30), Vector2(6, y - 34), Vector2(9, y - 12), Vector2(-8, y - 12)]), skin)
			draw_line(Vector2(f * 6, y - 30), Vector2(f * 14, y - 16), skin, 3.0)
			draw_line(Vector2(f * 14, y - 16), Vector2(f * 17, y - 13), Color("d8d0c0"), 1.5)
			draw_circle(Vector2(f * 6, y - 36), 6.0, skin.lightened(0.1))
			var eye := Color(0.6, 1.0, 0.7) if type_id == "wight" else Color(1.0, 0.45, 0.2)
			draw_circle(Vector2(f * 8, y - 37), 1.3, eye)
			if type_id == "wight":
				for i in 3:
					draw_line(Vector2(-6 + i * 5, y - 28), Vector2(-7 + i * 5, y - 10), Color(0.3, 0.4, 0.25, 0.8), 1.5)  # weeds
		"boar":
			var hide := Color("5a4030")
			draw_colored_polygon(PackedVector2Array([Vector2(-16 * f, y - 20), Vector2(10 * f, y - 24), Vector2(16 * f, y - 10), Vector2(-16 * f, y - 8)]), hide)
			for lx in [-12, -6, 6, 11]:
				draw_rect(Rect2(lx * f - 1, y - 9, 3, 9), hide.darkened(0.35))
			draw_circle(Vector2(15 * f, y - 16), 6.0, hide.lightened(0.08))
			draw_line(Vector2(18 * f, y - 13), Vector2(22 * f, y - 19), Color("e8e0cc"), 2.0)
			draw_circle(Vector2(16 * f, y - 19), 1.2, Color(1, 0.3, 0.2))
			for i in 5:
				draw_line(Vector2((-12 + i * 5) * f, y - 22), Vector2((-13 + i * 5) * f, y - 27), Color("2a1e16"), 1.5)
		"risen", "barrow_lord", "revenant":
			var bone := Color("c8c0a8") if type_id != "revenant" else Color("dfe6ea")
			draw_rect(Rect2(-4, y - 14, 3, 14), bone.darkened(0.3))
			draw_rect(Rect2(1, y - 14, 3, 14), bone.darkened(0.3))
			draw_colored_polygon(PackedVector2Array([Vector2(-9, y - 40), Vector2(9, y - 40), Vector2(7, y - 14), Vector2(-7, y - 14)]), Color("3a3a34"))
			for i in 3:
				draw_line(Vector2(-6, y - 34 + i * 6), Vector2(6, y - 34 + i * 6), bone, 2.0)
			draw_line(Vector2(f * 8, y - 36), Vector2(f * 14, y - 22), bone, 3.0)
			draw_circle(Vector2(f, y - 46), 7.0, bone)
			draw_circle(Vector2(f * 3 - 2, y - 47), 1.5, Color(0.4, 0.9, 0.7))
			draw_circle(Vector2(f * 3 + 2, y - 47), 1.5, Color(0.4, 0.9, 0.7))
		"hound":
			var fur := Color("4a4440")
			draw_colored_polygon(PackedVector2Array([Vector2(-14 * f, y - 18), Vector2(10 * f, y - 20), Vector2(12 * f, y - 10), Vector2(-14 * f, y - 9)]), fur)
			for lx in [-11, -6, 5, 9]:
				draw_rect(Rect2(lx * f - 1, y - 10, 3, 10), fur.darkened(0.3))
			draw_colored_polygon(PackedVector2Array([Vector2(8 * f, y - 24), Vector2(20 * f, y - 20), Vector2(18 * f, y - 14), Vector2(8 * f, y - 14)]), fur.lightened(0.1))
			draw_circle(Vector2(15 * f, y - 20), 1.3, Color(1, 0.3, 0.2))
			draw_line(Vector2(-14 * f, y - 17), Vector2(-20 * f, y - 24), fur, 2.0)
		"lurker":
			var skin := Color("3f5a3a")
			draw_colored_polygon(PackedVector2Array([Vector2(-15, y - 6), Vector2(-10, y - 22), Vector2(10, y - 24), Vector2(16, y - 6)]), skin)
			draw_circle(Vector2(8 * f, y - 22), 7.0, skin.lightened(0.1))
			draw_circle(Vector2(11 * f, y - 25), 2.0, Color(0.9, 0.8, 0.3))
			for lx in [-12, -5, 6, 13]:
				draw_line(Vector2(lx, y - 8), Vector2(lx + 3, y), skin.darkened(0.3), 3.0)
		"cultist":
			var robe := Color("5a2e2a")
			draw_colored_polygon(PackedVector2Array([Vector2(-7, y - 40), Vector2(7, y - 40), Vector2(11, y), Vector2(-11, y)]), robe)
			draw_circle(Vector2(f, y - 45), 7.0, robe.darkened(0.2))
			draw_circle(Vector2(f * 3, y - 44), 4.0, Color("d8d0b8"))  # bone mask
			draw_line(Vector2(f * 9, y - 44), Vector2(f * 9, y - 4), Color("5a4630"), 2.0)
			draw_circle(Vector2(f * 9, y - 46), 3.0, Color(0.7, 0.9, 0.5, 0.8))
