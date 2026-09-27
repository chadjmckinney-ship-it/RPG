class_name Talents
extends RefCounted
## Per-companion growth, talent choices (one of two at levels 2/4/6/8/10) and the
## third ability that unlocks at level 5. Choices live in GameState.talents.

const TIERS := [2, 4, 6, 8, 10]
const THIRD_ABILITY_LEVEL := 5
const THIRD := {"maren": "cleave", "oswin": "sanctuary", "ketta": "volley"}

## Stat gain per level above 1.
const GROWTH := {
	"maren": {"max_hp": 6.0, "attack": 0.8, "defense": 0.4, "max_stamina": 4.0},
	"oswin": {"max_hp": 8.0, "attack": 0.5, "defense": 0.6, "max_stamina": 5.0},
	"ketta": {"max_hp": 5.0, "attack": 0.9, "defense": 0.3, "max_stamina": 4.0},
}

## Talent effects: stats {stat: +n}, on_hit {status}, evasion, lifesteal, riposte (chance),
## ability {id: {cd, power, heal (multipliers), radius, time, dr (additions)}}.
const DEFS := {
	"maren": [
		[{"id": "duelist", "name": "Duelist", "desc": "+2 attack.", "stats": {"attack": 2.0}},
		 {"id": "scouts_legs", "name": "Scout's Legs", "desc": "Faster, and 5% chance to dodge.", "stats": {"speed": 15.0}, "evasion": 0.05}],
		[{"id": "bleeding_cuts", "name": "Bleeding Cuts", "desc": "Her hits make foes bleed.", "on_hit": {"id": "bleed", "time": 4.0, "dps": 2.5}},
		 {"id": "riposte", "name": "Riposte", "desc": "20% chance to strike back when hit in melee.", "riposte": 0.2}],
		[{"id": "hamstring_mastery", "name": "Hamstring Mastery", "desc": "Hamstring recovers 40% faster and hits 50% harder.", "ability": {"hamstring": {"cd": 0.6, "power": 1.5}}},
		 {"id": "quick_hands", "name": "Quick Hands", "desc": "Quick Shot recovers 40% faster.", "ability": {"quick_shot": {"cd": 0.6}}}],
		[{"id": "veteran", "name": "Veteran", "desc": "+20 HP, +2 defense.", "stats": {"max_hp": 20.0, "defense": 2.0}},
		 {"id": "bloodthirst", "name": "Bloodthirst", "desc": "Heals for 10% of the damage she deals.", "lifesteal": 0.1}],
		[{"id": "deserters_luck", "name": "Deserter's Luck", "desc": "15% chance to dodge.", "evasion": 0.15},
		 {"id": "killing_edge", "name": "Killing Edge", "desc": "+4 attack.", "stats": {"attack": 4.0}}],
	],
	"oswin": [
		[{"id": "iron_faith", "name": "Iron Faith", "desc": "+2 defense.", "stats": {"defense": 2.0}},
		 {"id": "deep_reserves", "name": "Deep Reserves", "desc": "+25 stamina.", "stats": {"max_stamina": 25.0}}],
		[{"id": "shield_bash", "name": "Shield Bash", "desc": "His hits slow the foe.", "on_hit": {"id": "slow", "time": 2.0, "mult": 0.6}},
		 {"id": "wardens_touch", "name": "Warden's Touch", "desc": "Rite of Mending heals 50% more.", "ability": {"mending": {"heal": 1.5}}}],
		[{"id": "bulwark", "name": "Bulwark", "desc": "Shield Wall blocks 70% and recovers 30% faster.", "ability": {"shield_wall": {"dr": 0.2, "cd": 0.7}}},
		 {"id": "penance", "name": "Penance", "desc": "Heals for 15% of the damage he deals.", "lifesteal": 0.15}],
		[{"id": "unbreakable", "name": "Unbreakable", "desc": "+30 HP.", "stats": {"max_hp": 30.0}},
		 {"id": "zeal", "name": "Zeal", "desc": "+3 attack.", "stats": {"attack": 3.0}}],
		[{"id": "saints_grace", "name": "Saint's Grace", "desc": "Sanctuary heals 50% more.", "ability": {"sanctuary": {"heal": 1.5}}},
		 {"id": "hallowed_ground", "name": "Hallowed Ground", "desc": "+3 defense, +20 HP.", "stats": {"defense": 3.0, "max_hp": 20.0}}],
	],
	"ketta": [
		[{"id": "keen_eye", "name": "Keen Eye", "desc": "+2 attack.", "stats": {"attack": 2.0}},
		 {"id": "light_step", "name": "Light Step", "desc": "10% chance to dodge.", "evasion": 0.1}],
		[{"id": "barbed_arrows", "name": "Barbed Arrows", "desc": "Her arrows make foes bleed.", "on_hit": {"id": "bleed", "time": 4.0, "dps": 2.5}},
		 {"id": "poisoned_arrows", "name": "Poisoned Arrows", "desc": "Her arrows poison.", "on_hit": {"id": "poison", "time": 5.0, "dps": 2.5}}],
		[{"id": "deadeye", "name": "Deadeye", "desc": "Aimed Shot hits 50% harder.", "ability": {"aimed_shot": {"power": 1.5}}},
		 {"id": "wide_snare", "name": "Wide Snare", "desc": "Snare Trap catches a wider area and holds 2 s longer.", "ability": {"snare": {"radius": 1.0, "time": 2.0}}}],
		[{"id": "long_draw", "name": "Long Draw", "desc": "+2 bow range.", "stats": {"attack_range": 2.0}},
		 {"id": "rapid_fire", "name": "Rapid Fire", "desc": "Shoots 0.3 s faster.", "stats": {"attack_cooldown": -0.3}}],
		[{"id": "hunters_mark", "name": "Hunter's Mark", "desc": "+4 attack.", "stats": {"attack": 4.0}},
		 {"id": "survivor", "name": "Survivor", "desc": "+20 HP, 10% chance to dodge.", "stats": {"max_hp": 20.0}, "evasion": 0.1}],
	],
}

static func get_talent(companion: String, id: String) -> Dictionary:
	for tier in DEFS.get(companion, []):
		for t in tier:
			if t.id == id:
				return t
	return {}

static func chosen(companion: String) -> Array:
	return GameState.talents.get(companion, [])

## Index of the first tier this companion may pick now but hasn't, or -1.
static func pending_tier(companion: String, level: int) -> int:
	var tiers: Array = DEFS.get(companion, [])
	for i in tiers.size():
		if level >= TIERS[i] and not tiers[i].any(func(t): return chosen(companion).has(t.id)):
			return i
	return -1

static func choose(companion: String, tier: int, id: String) -> bool:
	var tiers: Array = DEFS.get(companion, [])
	if tier < 0 or tier >= tiers.size() or Progression.level() < TIERS[tier]:
		return false
	if not tiers[tier].any(func(t): return t.id == id) or tiers[tier].any(func(t): return chosen(companion).has(t.id)):
		return false
	if pending_tier(companion, Progression.level()) != tier:
		return false   # earlier tiers are picked first
	if not GameState.talents.has(companion):
		GameState.talents[companion] = []
	GameState.talents[companion].append(id)
	return true

static func abilities_for(companion: String, level: int) -> Array:
	var list: Array = Companions.DEFS[companion].abilities.duplicate()
	if level >= THIRD_ABILITY_LEVEL and THIRD.has(companion):
		list.append(THIRD[companion])
	return list

## Everything a companion's level and talents add: {stats, on_hit, evasion, lifesteal, riposte, ability}.
static func effects(companion: String, level: int) -> Dictionary:
	var out := {"stats": {}, "on_hit": {}, "evasion": 0.0, "lifesteal": 0.0, "riposte": 0.0, "ability": {}}
	var g: Dictionary = GROWTH.get(companion, {})
	for k in g:
		out.stats[k] = g[k] * (level - 1)
	for id in chosen(companion):
		var t := get_talent(companion, id)
		for k in t.get("stats", {}):
			out.stats[k] = float(out.stats.get(k, 0.0)) + t.stats[k]
		if t.has("on_hit"):
			out.on_hit = t.on_hit
		for k in ["evasion", "lifesteal", "riposte"]:
			out[k] += float(t.get(k, 0.0))
		for ab in t.get("ability", {}):
			if not out.ability.has(ab):
				out.ability[ab] = {}
			for k in t.ability[ab]:
				out.ability[ab][k] = t.ability[ab][k]
	return out
