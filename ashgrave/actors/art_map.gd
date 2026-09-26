class_name ArtMap
extends RefCounted
## Which art each character and creature uses.

const CREATURES := {
	"risen": {"flare": "skeleton"},
	"revenant": {"flare": "skeleton_mage", "tint": Color(0.8, 0.95, 1.1)},
	"barrow_lord": {"flare": "skeleton_knight_boss", "tint": Color(0.75, 0.95, 0.95), "size": 1.15},
	"ghoul": {"flare": "zombie", "tint": Color(0.8, 0.78, 0.75)},
	"wight": {"flare": "zombie_dark", "tint": Color(0.75, 1.0, 0.8)},
	"hound": {"flare": "goblin_runner"},
	"lurker": {"flare": "ice_ant", "tint": Color(0.7, 1.0, 0.7)},
	"boar": {"flare": "antlion"},
	"crows": {"flare": "antlion_small"},
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
	if a.has("lpc"):
		var s := LpcSprite.new()
		s.setup(a.lpc, a.get("weapon", ""))
		s.scale = Vector2.ONE * a.get("size", 1.0)
		return s
	var f := FlareSprite.new()
	f.setup(a.flare, a.get("tint", Color.WHITE), a.get("size", 1.0))
	return f

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
	var pool := ["villager_f1", "villager_m1", "villager_f2", "villager_m2"]
	return [pool[absi(hash(v.npc_id)) % pool.size()], ""]
