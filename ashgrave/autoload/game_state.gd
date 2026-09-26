extends Node
## Everything that must survive a save: world seed plus diffs against the generated world.

const SAVE_PATH := "user://ashgrave_save.json"

var world_seed: int = 1337
var world: WorldGen
var inventory := Inventory.new()
var reputation := {}
var cleared_camps := {}   # camp id -> true
var harvested := {}       # gather node id -> day harvested
## A save waiting for main.gd to apply after a scene reload.
var pending_load := {}

func _init() -> void:
	reset()

func reset() -> void:
	inventory = Inventory.new()
	inventory.add("coin", 15)
	inventory.add("bandage", 3)
	reputation = Factions.START.duplicate()
	cleared_camps = {}
	harvested = {}

func new_world(seed_value: int = -1) -> void:
	world_seed = seed_value if seed_value >= 0 else randi() % 1_000_000
	world = WorldGen.new(world_seed)

func change_rep(faction: String, amount: int) -> void:
	if amount == 0 or not reputation.has(faction):
		return
	var before: int = reputation[faction]
	reputation[faction] = clampi(before + amount, -100, 100)
	Events.combat_message.emit("%s %s %d (%s)" % [Factions.NAMES[faction], "+" if amount > 0 else "−", absi(amount), Factions.standing(reputation[faction])])

## Serialisable snapshot; party state is filled in by main.gd.
func to_dict(party_state: Array) -> Dictionary:
	return {
		"version": 1, "seed": world_seed, "time": TimeOfDay.time, "day": TimeOfDay.day,
		"inventory": inventory.counts.duplicate(), "reputation": reputation.duplicate(),
		"cleared_camps": cleared_camps.keys(), "harvested": harvested.duplicate(), "party": party_state,
	}

func load_dict(d: Dictionary) -> void:
	if world == null or world.seed_value != int(d.seed):
		new_world(int(d.seed))
	TimeOfDay.time = float(d.time)
	TimeOfDay.day = int(d.day)
	inventory = Inventory.new()
	for k in d.inventory:
		inventory.counts[k] = int(d.inventory[k])
	reputation = {}
	for k in d.reputation:
		reputation[k] = int(d.reputation[k])
	cleared_camps = {}
	for k in d.cleared_camps:
		cleared_camps[k] = true
	harvested = {}
	for k in d.harvested:
		harvested[k] = int(d.harvested[k])

func write_save(data: Dictionary) -> bool:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	return true

func read_save() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}
