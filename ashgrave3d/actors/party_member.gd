class_name PartyMember
extends Actor
## A controllable companion: stats from Companions, level growth and talents, gear.

var companion_id := ""
var role := ""
var base_stats := {}
var equipment := {"weapon": "", "armor": ""}

func setup_member(id: String) -> void:
	companion_id = id
	var d: Dictionary = Companions.DEFS[id]
	display_name = d.name
	role = d.role
	var stats: Dictionary = d.stats.duplicate()
	for k in GameState.bonuses.get(id, {}):
		stats[k] = float(stats.get(k, 0.0)) + float(GameState.bonuses[id][k])
	base_stats = stats.duplicate()
	setup_stats(stats)
	abilities.assign(d.abilities)
	recompute_stats()
	hp = max_hp
	stamina = max_stamina
	set_body(id, Color(0.45, 0.4, 0.34))

## Stats = base (incl. quest bonuses) + level growth + talents + gear.
func recompute_stats() -> void:
	var hp_frac := hp / max_hp if max_hp > 0.0 else 1.0
	for k in base_stats:
		set(k, base_stats[k])
	evasion = float(base_stats.get("evasion", 0.0))
	lifesteal = float(base_stats.get("lifesteal", 0.0))
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
