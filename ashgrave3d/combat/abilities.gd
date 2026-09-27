class_name Abilities
extends RefCounted
## Ability definitions. target: enemy | ally | self | cell.
## kind: damage | heal | self_status | area_status | area_damage | area_heal.
## Area kinds centre on the caster when target is "self", else on the target cell.

const DEFS := {
	"quick_shot": {"name": "Quick Shot", "cd": 4.0, "cost": 15.0, "range": 7.0, "target": "enemy",
		"kind": "damage", "power": 1.2, "ranged": true},
	"hamstring": {"name": "Hamstring", "cd": 8.0, "cost": 20.0, "range": 1.6, "target": "enemy",
		"kind": "damage", "power": 0.8, "status": {"id": "slow", "time": 5.0, "mult": 0.45}},
	"shield_wall": {"name": "Shield Wall", "cd": 15.0, "cost": 25.0, "range": 0.0, "target": "self",
		"kind": "self_status", "status": {"id": "guard", "time": 6.0, "dr": 0.5}},
	"mending": {"name": "Rite of Mending", "cd": 10.0, "cost": 25.0, "range": 6.0, "target": "ally",
		"kind": "heal", "heal": 32.0},
	"snare": {"name": "Snare Trap", "cd": 12.0, "cost": 20.0, "range": 6.0, "target": "cell",
		"kind": "area_status", "radius": 1.6, "status": {"id": "root", "time": 4.0}},
	"aimed_shot": {"name": "Aimed Shot", "cd": 9.0, "cost": 25.0, "range": 9.0, "target": "enemy",
		"kind": "damage", "power": 2.2, "ranged": true},
	# Third abilities, unlocked at level 5 (Talents.THIRD).
	"cleave": {"name": "Cleave", "cd": 10.0, "cost": 25.0, "range": 0.0, "target": "self",
		"kind": "area_damage", "radius": 1.6, "power": 1.0},
	"sanctuary": {"name": "Sanctuary", "cd": 20.0, "cost": 35.0, "range": 0.0, "target": "self",
		"kind": "area_heal", "radius": 3.0, "heal": 22.0},
	"volley": {"name": "Volley", "cd": 14.0, "cost": 30.0, "range": 8.0, "target": "cell",
		"kind": "area_damage", "radius": 1.8, "power": 0.9, "ranged": true},
}

static func get_def(id: String) -> Dictionary:
	return DEFS.get(id, {})

## The definition as this actor uses it, with talent modifiers (actor.ability_mods) applied:
## cd/power/heal multiply; radius/time add; dr adds to a status's damage reduction.
static func effective(actor, id: String) -> Dictionary:
	var a := get_def(id)
	var m: Dictionary = actor.ability_mods.get(id, {}) if actor else {}
	if a.is_empty() or m.is_empty():
		return a
	a = a.duplicate(true)
	for k in ["cd", "power", "heal"]:
		if m.has(k) and a.has(k):
			a[k] = a[k] * m[k]
	if m.has("radius") and a.has("radius"):
		a.radius += m.radius
	if a.has("status"):
		if m.has("time"):
			a.status.time += m.time
		if m.has("dr") and a.status.has("dr"):
			a.status.dr = minf(0.9, a.status.dr + m.dr)
	return a
