class_name PartyMember
extends Actor
## A controllable party member: auto-retaliation when idle, stats from level, talents and gear.

const AUTO_ENGAGE_RANGE := 10.0  # join any fight this close (only creatures already fighting)

@export var role := ""
var companion_id := ""

var look := {
	"skin": Color("d9b08c"), "hair": Color("3a2a20"), "hair_long": false,
	"coat": Color("4a4038"), "body": Color("5a5048"), "trim": Color("8a7a5a"),
	"legs": Color("2e2a26"), "slim": false, "hood": false,
}

var base_stats := {}
var equipment := {"weapon": "", "armor": ""}

func _init() -> void:
	faction = "party"

func setup_stats(d: Dictionary) -> void:
	base_stats = d.duplicate()
	super.setup_stats(d)

## Equip from the party pack; the previous item goes back into it.
func equip(id: String, inv: Inventory) -> bool:
	if not Items.can_wield(self, id) or not inv.has(id):
		return false
	var slot: String = Items.get_def(id).slot
	inv.remove(id)
	if equipment[slot] != "":
		inv.add(equipment[slot])
	equipment[slot] = id
	recompute_stats()
	return true

func unequip(slot: String, inv: Inventory) -> void:
	if equipment.get(slot, "") == "":
		return
	inv.add(equipment[slot])
	equipment[slot] = ""
	recompute_stats()

## Stats = base (incl. quest bonuses) + level growth + talents + gear.
func recompute_stats() -> void:
	var hp_frac := hp / max_hp if max_hp > 0.0 else 1.0
	for k in base_stats:
		set(k, base_stats[k])
	evasion = float(base_stats.get("evasion", 0.0))
	lifesteal = float(base_stats.get("lifesteal", 0.0))
	on_hit_status = {}
	if companion_id != "":
		var lv := Progression.level()
		var fx := Talents.effects(companion_id, lv)
		for k in fx.stats:
			set(k, float(get(k)) + fx.stats[k])
		evasion += fx.evasion
		lifesteal += fx.lifesteal
		riposte = fx.riposte
		on_hit_status = fx.on_hit.duplicate()
		ability_mods = fx.ability
		abilities.assign(Talents.abilities_for(companion_id, lv))
	for slot in equipment:
		var id: String = equipment[slot]
		if id == "":
			continue
		var bonus: Dictionary = Items.get_def(id).get("bonus", {})
		for k in bonus:
			set(k, float(get(k)) + bonus[k])
	hp = clampf(max_hp * hp_frac, 1.0 if not downed else 0.0, max_hp)
	stamina = minf(stamina, max_stamina)
	refresh_look()

func use_item(id: String, inv: Inventory) -> bool:
	var d := Items.get_def(id)
	if d.get("type") != "consumable" or downed or not inv.has(id):
		return false
	if d.has("heal") and hp >= max_hp and not (d.has("cure") and d.cure.any(func(c): return statuses.has(c))):
		return false
	inv.remove(id)
	if d.has("heal"):
		heal(d.heal)
	for c in d.get("cure", []):
		statuses.erase(c)
	log_msg("%s uses %s." % [display_name, d.name])
	return true

func _idle(_delta: float) -> void:
	# Defend yourself and your companions: engage the nearest hostile that is fighting nearby.
	var best: Actor = null
	var best_d := AUTO_ENGAGE_RANGE
	for other in (ctx.actors if ctx else []):
		if not is_instance_valid(other) or not other.alive() or not is_hostile_to(other):
			continue
		if other is Creature and not other.aggressive():
			continue
		var d := cell_distance(other.cell)
		if d <= best_d:
			best_d = d
			best = other
	if best:
		issue({"type": "attack", "target": best, "auto": true})

var _kite_cd := 0.0

## Archers step back when something with teeth gets close, then resume shooting.
func _run_order(delta: float) -> void:
	_kite_cd -= delta
	if ranged and _kite_cd <= 0.0 and current != null and current.type == "attack" and ctx:
		for other in ctx.actors:
			if is_instance_valid(other) and other.alive() and is_hostile_to(other) and not other.ranged and cell_distance(other.cell) <= 1.6:
				var away := cell + Vector2i(signi(cell.x - other.cell.x) * 3, signi(cell.y - other.cell.y) * 3)
				if world.walkable(away) and not world.has_tree(away):
					_kite_cd = 5.0
					orders.push_front(current)
					current = null
					_begin({"type": "move", "cell": away})
					return
				break
	super._run_order(delta)

func _on_damaged(source: Actor) -> void:
	if riposte > 0.0 and source and source.alive() and not downed and cell_distance(source.cell) <= 1.6 and randf() < riposte:
		_floaters.append({"text": "riposte", "color": Color(1, 0.85, 0.5), "t": 0.0})
		_strike(source)
	if current == null and orders.is_empty() and source and source.alive():
		issue({"type": "attack", "target": source, "auto": true})

## Pick the art that matches current equipment: Maren's rendered model, or an LPC outfit and weapon.
func refresh_look() -> void:
	if companion_id == "":
		return
	var hero := ArtMap.hero_variant(companion_id, equipment)
	if hero != "":
		if sprite is HeroSprite and sprite.variant == hero:
			return
		var h := HeroSprite.new()
		h.setup(hero)
		set_sprite(h)
		return
	var look_ids := ArtMap.member_look(companion_id, equipment)
	if sprite is LpcSprite and sprite.character == look_ids[0] and sprite.weapon == look_ids[1]:
		return
	var s := LpcSprite.new()
	s.setup(look_ids[0], look_ids[1])
	set_sprite(s)
