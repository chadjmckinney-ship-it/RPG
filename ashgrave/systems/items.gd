class_name Items
extends RefCounted
## Item definitions. type: currency | material | consumable | gear.
## Gear has slot (weapon | armor), stat bonuses, and optional "style" (melee | ranged).

const DEFS := {
	"coin": {"name": "Coin", "type": "currency", "value": 1},
	"hide": {"name": "Hound hide", "type": "material", "value": 3},
	"grave-dust": {"name": "Grave dust", "type": "material", "value": 4},
	"lurker-gland": {"name": "Lurker gland", "type": "material", "value": 5},
	"bone-charm": {"name": "Bone charm", "type": "material", "value": 8},
	"bitterroot": {"name": "Bitterroot", "type": "material", "value": 2},
	"iron-ore": {"name": "Iron ore", "type": "material", "value": 4},
	"deadwood": {"name": "Deadwood", "type": "material", "value": 2},

	"bandage": {"name": "Bandage", "type": "consumable", "value": 6, "heal": 30.0, "desc": "Heals 30."},
	"antivenom": {"name": "Antivenom", "type": "consumable", "value": 10, "cure": ["poison"], "heal": 5.0, "desc": "Cures poison."},
	"fen-tonic": {"name": "Fen tonic", "type": "consumable", "value": 18, "heal": 65.0, "desc": "Heals 65."},

	"militia-spear": {"name": "Militia spear", "type": "gear", "slot": "weapon", "style": "melee", "value": 30, "bonus": {"attack": 3.0}},
	"iron-blade": {"name": "Iron blade", "type": "gear", "slot": "weapon", "style": "melee", "value": 45, "bonus": {"attack": 4.0}},
	"barrow-blade": {"name": "Barrow blade", "type": "gear", "slot": "weapon", "style": "melee", "value": 90, "bonus": {"attack": 7.0}},
	"yew-bow": {"name": "Yew bow", "type": "gear", "slot": "weapon", "style": "ranged", "value": 40, "bonus": {"attack": 4.0}},
	"hide-jerkin": {"name": "Hide jerkin", "type": "gear", "slot": "armor", "value": 25, "bonus": {"defense": 2.0, "max_hp": 10.0}},
	"iron-mail": {"name": "Iron mail", "type": "gear", "slot": "armor", "value": 80, "bonus": {"defense": 5.0, "speed": -12.0}},
	"penitent-robes": {"name": "Penitent robes", "type": "gear", "slot": "armor", "value": 50, "bonus": {"defense": 1.0, "max_stamina": 25.0}},
}

static func get_def(id: String) -> Dictionary:
	return DEFS.get(id, {})

static func item_name(id: String) -> String:
	return DEFS.get(id, {}).get("name", id)

static func can_wield(member, id: String) -> bool:
	var d := get_def(id)
	if d.get("type") != "gear":
		return false
	var style: String = d.get("style", "")
	if style == "ranged":
		return member.ranged
	if style == "melee":
		return not member.ranged
	return true
