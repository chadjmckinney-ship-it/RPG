class_name ArtMap
extends RefCounted
## Which art each character and creature uses.

const CREATURES := {
	"risen": {"lpc": "risen", "weapon": "longsword"},
	"revenant": {"lpc": "revenant", "weapon": "staff", "tint": Color(0.85, 0.95, 1.1)},
	"barrow_lord": {"lpc": "barrow_lord", "weapon": "longsword", "tint": Color(0.8, 1.0, 1.0), "size": 1.3},
	"ghoul": {"lpc": "ghoul", "weapon": ""},
	"wight": {"lpc": "wight", "weapon": ""},
	"hound": {"lpc": "hound", "weapon": ""},
	"lurker": {"lpc": "lurker", "weapon": "spear"},
	"boar": {"lpc": "boar", "weapon": "mace", "size": 1.1},
	"crows": {"lpc": "crows", "weapon": "dagger", "size": 0.85},
	"bandit": {"lpc": "bandit", "weapon": "dagger"},
	"crossbow": {"lpc": "crossbow", "weapon": "crossbow"},
	"cultist": {"lpc": "cultist", "weapon": "staff"},
	"ash_knight": {"lpc": "ash_knight", "weapon": "longsword", "size": 1.2},
}
const DEFAULT_WEAPON := {"maren": "longsword", "oswin": "mace", "ketta": "bow"}
const WEAPON_ART := {"militia-spear": "spear", "iron-blade": "longsword", "barrow-blade": "longsword", "ashen-greatsword": "longsword", "yew-bow": "bow"}
const ARMOR_ART := {"hide-jerkin": "_hide", "iron-mail": "_mail", "penitent-robes": "_robes"}

static func make_creature(type: String) -> CharSprite:
	var a: Dictionary = CREATURES.get(type, CREATURES.risen)
	var s := LpcSprite.new()
	s.setup(a.lpc, a.get("weapon", ""))
	s.scale = Vector2.ONE * a.get("size", 1.0)
	s.self_modulate = a.get("tint", Color.WHITE)
	return s

## LPC look for a party member given their equipment.
static func member_look(id: String, equipment: Dictionary) -> Array:
	var suffix: String = ARMOR_ART.get(equipment.get("armor", ""), "")
	var weapon: String = WEAPON_ART.get(equipment.get("weapon", ""), DEFAULT_WEAPON.get(id, ""))
	return [id + suffix, weapon]

static func villager_look(v) -> Array:
	match v.npc_id:
		"maud": return ["maud", "spear"]
		"nessa": return ["nessa", ""]
		"harl": return ["harl", "longsword"]
		"oswin", "ketta": return [v.npc_id, DEFAULT_WEAPON[v.npc_id]]
	match v.job:
		"smith": return ["smith", ""]
		"keeper": return ["keeper", ""]
	# generated villagers dressed for the village's faction (tools/import_lpc.py expand_villagers)
	var faction: String = v.village.get("faction", "hollow") if v.get("village") is Dictionary else "hollow"
	var pool: Array = LpcSprite.meta().characters.keys().filter(func(k): return k.begins_with("villager_%s_" % faction))
	if pool.is_empty():
		pool = ["villager_f1", "villager_m1", "villager_f2", "villager_m2"]
	pool.sort()
	return [pool[absi(hash(v.npc_id)) % pool.size()], ""]
