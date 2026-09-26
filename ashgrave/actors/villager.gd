class_name Villager
extends Actor
## Settlement folk with a daily routine: work by day, the tavern in the evening, home at night.
## Traders (smith, tavern keeper) open the trade screen when the party talks to them.

const TRADES := {
	"keeper": ["bandage", "antivenom", "fen-tonic"],
	"smith": ["militia-spear", "iron-blade", "yew-bow", "hide-jerkin", "iron-mail", "iron-ore"],
}
const FACTION_GOODS := {"church": ["penitent-robes"], "companies": ["barrow-blade"], "hollow": ["bone-charm", "antivenom"]}

var job := "villager"     # smith | keeper | villager | elder | wisewoman | captain | companion
var npc_id := ""          # stable id used by dialogue and quests
var look := {}            # companions use the party figure
var village: Dictionary = {}
var work_cell := Vector2i.ZERO
var tavern_cell := Vector2i.ZERO
var home_cell := Vector2i.ZERO
var _think := 0.0

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

## Named story characters (Maud, Nessa, Harl, companions awaiting recruitment).
func setup_special(v: Dictionary, id: String, def: Dictionary) -> void:
	setup(v, def.job, 5)
	npc_id = id
	display_name = def.name
	if def.job == "companion":
		look = Companions.DEFS[id].look
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
	_think -= delta
	if _think > 0.0:
		return
	_think = randf_range(1.0, 2.5)
	var want := schedule_target(TimeOfDay.hour())
	if cell_distance(want) > 1.5:
		var dest := want
		if not world.walkable(dest):
			dest = want + Vector2i(0, 1)
		issue({"type": "move", "cell": dest})

func _name_for(v: Dictionary, index: int) -> String:
	var names := ["Aldo", "Bettrys", "Corwen", "Dagny", "Elsbet", "Fenn", "Garrick", "Hild", "Isolde", "Jory", "Kestrel", "Lise"]
	var h := absi(hash([v.id, index]))
	var title: String = {"smith": "the smith", "keeper": "of the tavern"}.get(job, "")
	return names[h % names.size()] + ((" " + title) if title != "" else "")

func _draw_body(bob: float) -> void:
	if not look.is_empty():
		Figures.draw_person(self, look, facing, bob, _walk_t, not path.is_empty(), ranged)
		return
	var y := -bob
	var f := facing
	var tunic: Color = {"church": Color("7a7060"), "companies": Color("6a3a2a"), "hollow": Color("4a5a3a")}.get(trader_faction(), Color("5a5048"))
	draw_rect(Rect2(-4, y - 13, 3, 13), Color("2e2a26"))
	draw_rect(Rect2(1, y - 13, 3, 13), Color("2e2a26"))
	draw_colored_polygon(PackedVector2Array([Vector2(-7, y - 36), Vector2(7, y - 36), Vector2(9, y - 12), Vector2(-9, y - 12)]), tunic)
	if job == "smith":
		draw_rect(Rect2(-6, y - 30, 12, 16), Color("3a2a1e"))  # apron
	elif job == "elder" or job == "wisewoman":
		draw_colored_polygon(PackedVector2Array([Vector2(-8, y - 38), Vector2(8, y - 38), Vector2(11, y), Vector2(-11, y)]), tunic.darkened(0.3))
	elif job == "captain":
		draw_rect(Rect2(-8, y - 36, 16, 8), Color("8a8a90"))  # pauldrons
	elif job == "keeper":
		draw_rect(Rect2(-6, y - 26, 12, 12), Color("c8c0a8"))
	var head := Vector2(f, y - 42)
	draw_circle(head, 6.0, Color("d0a888"))
	draw_arc(head + Vector2(0, -1), 6.0, PI * 1.05, PI * 1.95, 12, Color("4a3a2a"), 3.5)
	draw_circle(head + Vector2(f * 3, 0), 1.0, Color(0.1, 0.08, 0.08))

func on_interact(_who) -> void:
	Events.talk_requested.emit(self)
