class_name Progression
extends RefCounted
## Company experience: one XP pool, one level for everyone recruited (cap 10).
## Kills, cleared camps and quests award XP; enemies far from the start are worth more.

const MAX_LEVEL := 10
## Total XP needed to reach level i + 1.
const THRESHOLDS := [0, 80, 220, 420, 700, 1060, 1500, 2050, 2700, 3500]
const RANK_XP := 0.6          # +60% XP per regional rank
const CAMP_XP := 20

static func level_for(xp: int) -> int:
	var lv := 1
	for i in THRESHOLDS.size():
		if xp >= THRESHOLDS[i]:
			lv = i + 1
	return mini(lv, MAX_LEVEL)

static func level() -> int:
	return level_for(GameState.xp)

## XP earned inside the current level, and the size of that level (0 at the cap).
static func xp_into_level() -> int:
	return GameState.xp - THRESHOLDS[level() - 1]

static func xp_for_next() -> int:
	var lv := level()
	return 0 if lv >= MAX_LEVEL else THRESHOLDS[lv] - THRESHOLDS[lv - 1]

## XP a creature is worth: its own value, else from its toughness; scaled by rank.
static func kill_xp(type: String, rank: int) -> int:
	var d: Dictionary = CreatureDefs.DEFS.get(type, {})
	var base: float = d.get("xp", roundf(float(d.get("max_hp", 20.0)) / 5.0 + float(d.get("attack", 5.0))))
	return roundi(base * (1.0 + RANK_XP * rank))

static func camp_xp(rank: int) -> int:
	return CAMP_XP * (1 + rank)

## Add XP; emits Events.leveled_up once for every level gained.
static func award(amount: int, why := "") -> void:
	if amount <= 0:
		return
	var before := level()
	GameState.xp += amount
	if why != "":
		Events.combat_message.emit("+%d XP (%s)" % [amount, why])
	for lv in range(before + 1, level() + 1):
		Events.leveled_up.emit(lv)
