extends Node
## Everything that must survive a save: world seed plus diffs against the generated world.

const SAVE_PATH := "user://ashgrave_save.json"

var world_seed: int = 1337
var world: WorldGen
var inventory := Inventory.new()
var reputation := {}
var cleared_camps := {}   # camp id -> true
var harvested := {}       # gather node id -> day harvested
var flags := {}
var quests := {}          # quest id -> quest dictionary (see QuestLog)
var tracked := ""
var quest_counter := 0
var recruited: Array = ["maren"]
var approval := {}        # companion id -> -100..100
var bonuses := {}         # companion id -> {stat: bonus} from companion quests
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
	flags = {}
	quests = {}
	tracked = ""
	quest_counter = 0
	recruited = ["maren"]
	approval = {"oswin": 0, "ketta": 0}
	bonuses = {}

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
		"flags": flags.keys(), "quests": quests.duplicate(true), "tracked": tracked, "quest_counter": quest_counter,
		"recruited": recruited.duplicate(), "approval": approval.duplicate(), "bonuses": bonuses.duplicate(true),
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
	flags = {}
	for k in d.get("flags", []):
		flags[k] = true
	quests = d.get("quests", {}).duplicate(true)
	for q in quests.values():
		q.stage = int(q.stage)          # JSON turns ints into floats
		q.data.count = int(q.data.get("count", 0))
	tracked = d.get("tracked", "")
	quest_counter = int(d.get("quest_counter", 0))
	recruited = d.get("recruited", ["maren"]).duplicate()
	approval = {}
	for k in d.get("approval", {}):
		approval[k] = int(d.approval[k])
	bonuses = d.get("bonuses", {}).duplicate(true)

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

func add_bonus(companion: String, stat: String, amount: float) -> void:
	if not bonuses.has(companion):
		bonuses[companion] = {}
	bonuses[companion][stat] = float(bonuses[companion].get(stat, 0.0)) + amount
