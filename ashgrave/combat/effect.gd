class_name Effect
extends RefCounted
## Combat math. Same shape as Emberfall: atk*power*1.25 - def*0.6, ±10%, 5% crits for 160%.

const CRIT_CHANCE := 0.05
const CRIT_MULT := 1.6

static func damage(attacker, target, power: float = 1.0, rng: RandomNumberGenerator = null) -> Dictionary:
	var r := rng if rng else RandomNumberGenerator.new()
	if rng == null:
		r.randomize()
	var atk: float = attacker.attack
	# The restless dead hit harder after dark.
	if attacker.night_bonus > 0.0:
		atk *= 1.0 + attacker.night_bonus * (1.0 - TimeOfDay.daylight())
	var raw: float = atk * power * 1.25 - float(target.defense) * 0.6
	raw = maxf(1.0, raw) * r.randf_range(0.9, 1.1)
	var crit := r.randf() < CRIT_CHANCE
	if crit:
		raw *= CRIT_MULT
	return {"amount": maxf(1.0, roundf(raw)), "crit": crit}
