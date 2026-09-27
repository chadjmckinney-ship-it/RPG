class_name Companions
extends RefCounted
## Party roster. Maren always leads; the others are recruited in the world.

const ORDER := ["maren", "oswin", "ketta"]
const DEFS := {
	"maren": {"name": "Maren Vey", "role": "Deserter scout", "abilities": ["quick_shot", "hamstring"],
		"stats": {"max_hp": 72.0, "attack": 12.0, "defense": 5.0, "speed": 160.0, "attack_range": 1.5, "attack_cooldown": 1.0},
		"look": {"skin": Color("e0b894"), "hair": Color("7a2e22"), "hair_long": true, "coat": Color("3b2e2a"),
		"body": Color("5c3a2c"), "trim": Color("b08a4a"), "legs": Color("2a2422"), "slim": true, "hood": false}},
	"oswin": {"name": "Brother Oswin", "role": "Penitent", "abilities": ["shield_wall", "mending"], "likes": "church",
		"stats": {"max_hp": 96.0, "attack": 9.0, "defense": 9.0, "speed": 135.0, "attack_range": 1.5, "attack_cooldown": 1.3},
		"look": {"skin": Color("c89e7c"), "hair": Color("4a4038"), "coat": Color("4a4a52"), "body": Color("6a6a70"),
		"trim": Color("9a8a60"), "legs": Color("2e2e34"), "hood": true}},
	"ketta": {"name": "Ketta", "role": "Poacher", "abilities": ["snare", "aimed_shot"], "likes": "hollow",
		"stats": {"max_hp": 60.0, "attack": 10.0, "defense": 4.0, "speed": 155.0, "attack_range": 6.0, "attack_cooldown": 1.5, "ranged": true},
		"look": {"skin": Color("b98a66"), "hair": Color("2a2018"), "coat": Color("3a4630"), "body": Color("4f5a3a"),
		"trim": Color("7a6a42"), "legs": Color("2a2a22"), "slim": true}},
}

static func id_for_name(n: String) -> String:
	for id in DEFS:
		if DEFS[id].name == n:
			return id
	return ""
