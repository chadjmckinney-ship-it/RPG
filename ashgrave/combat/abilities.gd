class_name Abilities
extends RefCounted
## Ability definitions. target: enemy | ally | self | cell.
## kind: damage | heal | self_status | area_status.

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
}

static func get_def(id: String) -> Dictionary:
	return DEFS.get(id, {})
