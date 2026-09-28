class_name Villager
extends Actor
## Settlement folk with a daily routine: work by day, the tavern in the evening, home at night.
## Traders (smith, tavern keeper) open the trade screen when the party talks to them.
## Body: characters/<npc id>/ for story characters, characters/smith/ for the smith (a man), and one
## of VILLAGER_BODIES (women) for the tavern keeper and ordinary villagers, unless characters/keeper/
## exists; tinted by the village's faction until a model exists.

const TRADES := {
	"keeper": ["bandage", "antivenom", "fen-tonic"],
	"smith": ["militia-spear", "iron-blade", "yew-bow", "hide-jerkin", "iron-mail", "iron-ore"],
}
const FACTION_GOODS := {"church": ["penitent-robes"], "companies": ["barrow-blade"], "hollow": ["bone-charm", "antivenom"]}
const FACTION_TINT := {"church": Color("6a6a70"), "companies": Color("6a4a30"), "hollow": Color("4a5a3a")}
const STORY_TINT := {"maud": Color("3a4a5a"), "nessa": Color("5a4a5a"), "harl": Color("7a5a2a"),
	"oswin": Color("5a5a62"), "ketta": Color("3a4a2c")}
## Bodies for the keeper and villagers, all women. A village's three take consecutive ones, so none match.
const VILLAGER_BODIES := ["villager_1", "villager_2", "villager_3"]
## The keeper and villagers are women; the smith is a man.
const VILLAGER_NAMES := ["Bettrys", "Dagny", "Elsbet", "Hild", "Isolde", "Lise"]
const SMITH_NAMES := ["Aldo", "Corwen", "Fenn", "Garrick", "Jory"]

var job := "villager"     # smith | keeper | villager | elder | wisewoman | captain | companion
var npc_id := ""          # stable id used by dialogue and quests
var village: Dictionary = {}
var work_cell := Vector2i.ZERO
var tavern_cell := Vector2i.ZERO
var home_cell := Vector2i.ZERO
var _think := 0.0
## Where this villager is standing or heading, and the schedule target it was picked for.
var spot := Vector2i(-1, -1)
var _spot_for := Vector2i(-1, -1)

## Cells kept between villagers' spots, so they never stack and each one can be clicked.
const SPACING := 2

func _init() -> void:
	faction = "neutral"
	speed = 90.0

func setup(v: Dictionary, role: String, index: int) -> void:
	village = v
	job = role
	display_name = _name_for(v, index)
	npc_id = "%s:%s" % [v.id, role] if role != "villager" else "%s:villager%d" % [v.id, index]
	setup_stats({"max_hp": 40.0, "defense": 3.0, "speed": 90.0})
	tavern_cell = Settlements.door_cell(v, "tavern") + Vector2i(index % 2, 0)
	match role:
		"smith": work_cell = Settlements.door_cell(v, "forge")
		"keeper", "companion": work_cell = tavern_cell
		"elder", "captain": work_cell = v.center
		_: work_cell = v.center + Vector2i(index - 2, 1)
	home_cell = Settlements.door_cell(v, "house_a" if index % 2 == 0 else "house_b")
	var tint: Color = FACTION_TINT.get(v.get("faction", ""), Color(0.45, 0.4, 0.34))
	var body_id := role
	if role == "villager" or (role == "keeper" and not ResourceLoader.exists("res://characters/keeper/keeper.glb")):
		body_id = VILLAGER_BODIES[(absi(hash(v.id)) + index) % VILLAGER_BODIES.size()]
	set_body(body_id, tint.lerp(Color(0.5, 0.45, 0.4), float(index % 3) * 0.2))

## Named story characters (Maud, Nessa, Harl, companions awaiting recruitment).
func setup_special(v: Dictionary, id: String, def: Dictionary) -> void:
	setup(v, def.job, 5)
	npc_id = id
	display_name = def.name
	set_body(id, STORY_TINT.get(id, Color.GRAY))
	if def.job == "companion":
		ranged = Companions.DEFS[id].stats.get("ranged", false)
	if def.job in ["companion", "wisewoman"]:
		home_cell = tavern_cell if def.job == "companion" else home_cell
		tavern_cell = work_cell

func chatter() -> String:
	var lines := {
		"church": ["The Tithe-priests say the dead walk because we stopped paying. Maybe they're right.", "Keep your voice down near the chapel. The wardens listen."],
		"companies": ["Free Company coin keeps the walls up. Don't make trouble.", "Captain says there's work for anyone who can swing a blade and keep quiet."],
		"hollow": ["Leave an offering at the barrow stones and the risen pass you by. Usually.", "Old Nessa knows the barrows better than anyone living."],
	}
	var l: Array = lines.get(trader_faction(), ["..."])
	return l[absi(hash(npc_id)) % l.size()]

func trader_faction() -> String:
	return village.get("faction", "")

func stock() -> Array:
	var out: Array = TRADES.get(job, []).duplicate()
	if is_trader():
		for id in FACTION_GOODS.get(trader_faction(), []):
			if not out.has(id):
				out.append(id)
	return out

func is_trader() -> bool:
	return job == "smith" or job == "keeper"

## Where this villager wants to be at a given hour.
func schedule_target(hour: int) -> Vector2i:
	if hour >= 6 and hour < 18:
		return work_cell
	if hour >= 18 and hour < 22:
		return tavern_cell
	return home_cell

func _idle(delta: float) -> void:
	if is_attending():
		return
	_think -= delta
	if _think > 0.0:
		return
	_think = randf_range(1.0, 2.5)
	var want := schedule_target(TimeOfDay.hour())
	if want != _spot_for:
		claim_spot(want)
	if cell != spot:
		issue({"type": "move", "cell": spot})

## Pick (and remember) where to stand for a schedule target: the nearest open cell that keeps
## SPACING from every other villager's spot and cell, and isn't a party member's cell.
func claim_spot(want: Vector2i) -> Vector2i:
	_spot_for = want
	spot = want
	for r in 8:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var c := want + Vector2i(dx, dy)
				if world.walkable(c) and not world.has_tree(c) and not _crowded(c):
					spot = c
					return spot
	return spot

func _goal_moved(c: Vector2i) -> void:
	if current != null and current.type == "move":
		spot = c
		current.cell = c

func _crowded(c: Vector2i) -> bool:
	if Actor.ctx == null or not is_instance_valid(Actor.ctx):
		return false
	for a in Actor.ctx.actors:
		if a == self or not is_instance_valid(a):
			continue
		if a is PartyMember and a.cell == c:
			return true
		if not (a is Villager):
			continue
		for o in [a.cell, a.spot]:
			if maxi(absi(o.x - c.x), absi(o.y - c.y)) < SPACING:
				return true
	return false

func _name_for(v: Dictionary, index: int) -> String:
	var pool: Array = SMITH_NAMES if job == "smith" else VILLAGER_NAMES
	var given: String = pool[(absi(hash([v.id, "names"])) + index) % pool.size()]
	var title: String = {"smith": "the smith", "keeper": "of the tavern"}.get(job, "")
	return given + ((" " + title) if title != "" else "")

func _process(delta: float) -> void:
	super._process(delta)
	if body:
		body.highlight(Color(1.0, 0.8, 0.4, 0.18) if hovered else Color(0, 0, 0, 0))

func on_interact(who) -> void:
	attend(who)
	Events.talk_requested.emit(self)
