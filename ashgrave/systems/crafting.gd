class_name Crafting
extends RefCounted
## Recipes. station: camp (anywhere out of combat) or forge (next to a village forge).

const RECIPES := {
	"bandage": {"station": "camp", "in": {"bitterroot": 2}, "out": 2},
	"antivenom": {"station": "camp", "in": {"lurker-gland": 1, "bitterroot": 1}, "out": 1},
	"fen-tonic": {"station": "camp", "in": {"bitterroot": 3, "grave-dust": 1}, "out": 1},
	"hide-jerkin": {"station": "camp", "in": {"hide": 4}, "out": 1},
	"yew-bow": {"station": "camp", "in": {"deadwood": 3, "hide": 1}, "out": 1},
	"iron-blade": {"station": "forge", "in": {"iron-ore": 3, "deadwood": 1}, "out": 1},
	"iron-mail": {"station": "forge", "in": {"iron-ore": 5, "hide": 2}, "out": 1},
	"barrow-blade": {"station": "forge", "in": {"iron-ore": 4, "grave-dust": 3}, "out": 1},
}

static func missing(inv: Inventory, id: String) -> Dictionary:
	var out := {}
	var r: Dictionary = RECIPES[id]
	for k in r.in:
		var need: int = r.in[k] - inv.count(k)
		if need > 0:
			out[k] = need
	return out

## stations: Array of available station names.
static func can_craft(inv: Inventory, id: String, stations: Array) -> bool:
	return RECIPES.has(id) and stations.has(RECIPES[id].station) and missing(inv, id).is_empty()

static func craft(inv: Inventory, id: String, stations: Array) -> bool:
	if not can_craft(inv, id, stations):
		return false
	var r: Dictionary = RECIPES[id]
	for k in r.in:
		inv.remove(k, r.in[k])
	inv.add(id, r.out)
	return true

static func describe(id: String) -> String:
	var r: Dictionary = RECIPES[id]
	var parts: Array[String] = []
	for k in r.in:
		parts.append("%d %s" % [r.in[k], Items.item_name(k)])
	return ", ".join(parts)
