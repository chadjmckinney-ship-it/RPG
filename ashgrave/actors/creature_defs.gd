class_name CreatureDefs
extends RefCounted
## Stats per creature type. Loot is placeholder until inventory lands in Milestone 3.

const DEFS := {
	"barrow_lord": {"display_name": "The Drowned Lord", "max_hp": 220.0, "attack": 16.0, "defense": 9.0, "speed": 80.0,
		"attack_range": 1.6, "attack_cooldown": 1.5, "night_bonus": 0.4, "on_hit_status": {"id": "slow", "time": 2.5, "mult": 0.6},
		"loot": {"tithe-ledger": 1.0, "coin": [20, 30], "grave-dust": 1.0}},
	"risen": {"display_name": "Barrow-risen", "max_hp": 60.0, "attack": 11.0, "defense": 6.0, "speed": 70.0,
		"attack_range": 1.5, "attack_cooldown": 1.6, "night_bonus": 0.5, "loot": {"coin": [2, 6], "grave-dust": 0.6}},
	"hound": {"display_name": "Grave-hound", "max_hp": 28.0, "attack": 8.0, "defense": 2.0, "speed": 175.0,
		"attack_range": 1.5, "attack_cooldown": 0.9, "flee_at": 0.2, "loot": {"coin": [0, 2], "hide": 0.5}},
	"lurker": {"display_name": "Fen-lurker", "max_hp": 45.0, "attack": 7.0, "defense": 4.0, "speed": 100.0,
		"attack_range": 1.5, "attack_cooldown": 1.4, "on_hit_status": {"id": "poison", "time": 5.0, "dps": 3.0},
		"loot": {"coin": [1, 3], "lurker-gland": 0.5}},
	"cultist": {"display_name": "Hollow cultist", "max_hp": 34.0, "attack": 9.0, "defense": 3.0, "speed": 110.0,
		"attack_range": 6.0, "attack_cooldown": 2.0, "ranged": true, "loot": {"coin": [3, 9], "bone-charm": 0.35}},
}
