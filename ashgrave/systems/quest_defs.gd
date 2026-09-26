class_name QuestDefs
extends RefCounted
## Hand-written quests, instantiated against the generated world.

static func build(id: String, world: WorldGen) -> Dictionary:
	var s := Story.setup(world)
	var start := Story.village(world, s.start)
	var hollow := Story.village(world, s.hollow)
	var company := Story.village(world, s.company)
	var npcs := Story.special_npcs(world)
	match id:
		"mq_restless":
			var camp := QuestGen.nearest_camp(world, start.center, ["risen"], 90.0)
			if camp.is_empty():
				camp = QuestGen.nearest_camp(world, start.center, [], 120.0)
			return {"id": id, "title": "The Restless Dead", "giver": "maud", "stages": [
				{"text": "Destroy the barrow-risen gathering %s of %s." % [compass(start.center, camp.center), start.name],
					"obj": {"type": "kill_camp", "camp": camp.id}, "target": vec(camp.center)},
				{"text": "Report to Warden Maud in %s." % start.name, "target": vec(start.center),
					"obj": {"type": "talk", "options": [{"npc": "maud", "label": "The risen are destroyed.",
						"reply": "Then you've bought us a week. No more. The dead don't wander this far unless something drives them.", "effects": ["give:coin:30", "rep:%s:5" % start.faction]}]}},
			], "reward": ["quest_start:mq_dust"]}
		"mq_dust":
			return {"id": id, "title": "Grave Dust", "giver": "maud", "stages": [
				{"text": "Collect 3 grave dust from barrow-risen and show it to Old Nessa in %s." % hollow.name, "target": vec(hollow.center),
					"obj": {"type": "talk", "options": [{"npc": "nessa", "label": "Show her the grave dust (3).", "need": ["has:grave-dust:3"],
						"reply": "Salt-dust. Sea salt, in the hills. They were buried in the Drowned Barrow and something has pulled the stones off them. Go and see who.",
						"effects": ["take:grave-dust:3"]}]}},
				{"text": "Find the Drowned Barrow, %s of %s." % [compass(start.center, s.barrow), start.name],
					"obj": {"type": "reach", "cell": vec(s.barrow), "radius": 5.0}, "target": vec(s.barrow), "on_done": ["spawn:barrow"]},
				{"text": "Put down whatever guards the Drowned Barrow.", "obj": {"type": "kill_camp", "camp": "story:barrow"}, "target": vec(s.barrow)},
				{"text": "Decide who learns what the Tithe Ledger says: Warden Maud, Old Nessa, or Captain Harl of %s." % company.name, "target": vec(start.center),
					"obj": {"type": "talk", "options": [
						{"npc": "maud", "label": "Give the Church its ledger.", "need": ["has:tithe-ledger"],
							"reply": "...The Tithe took the plague-dead's coin for burial and never buried them. Say nothing of this. The Church will make it right. Quietly.",
							"effects": ["take:tithe-ledger", "give:coin:60", "rep:church:20", "rep:hollow:-15", "approve:oswin:10", "approve:ketta:-10", "flag:ledger_church"]},
						{"npc": "nessa", "label": "Give the Hollow Folk the proof.", "need": ["has:tithe-ledger"],
							"reply": "Every village will hear what the Tithe did. Our barrows will be tended properly now, by us.",
							"effects": ["take:tithe-ledger", "give:fen-tonic:3", "rep:hollow:20", "rep:church:-15", "approve:ketta:10", "approve:oswin:-10", "flag:ledger_hollow"]},
						{"npc": "harl", "label": "Sell the ledger to the Free Companies.", "need": ["has:tithe-ledger"],
							"reply": "Leverage over the Church? That's worth more than your desertion, Vey. Consider your name cleared. And your purse full.",
							"effects": ["take:tithe-ledger", "give:coin:150", "rep:companies:30", "rep:church:-10", "approve:oswin:-5", "approve:ketta:-5", "flag:ledger_companies"]},
					]}},
			], "reward": ["flag:act1_done"]}
		"sq_ashen":
			return {"id": id, "title": "The Ashen Knight", "giver": "harl", "stages": [
				{"text": "Find the burnt watchtower %s of %s." % [compass(company.center, s.ashen), company.name],
					"obj": {"type": "reach", "cell": vec(s.ashen), "radius": 5.0}, "target": vec(s.ashen), "on_done": ["spawn:ashen"]},
				{"text": "Kill the Ashen Knight.", "obj": {"type": "kill_camp", "camp": "story:ashen"}, "target": vec(s.ashen)},
				{"text": "Tell Captain Harl in %s the Knight is dead." % company.name, "target": vec(company.center),
					"obj": {"type": "talk", "options": [{"npc": "harl", "label": "Your Ashen Knight is ash.",
						"reply": "Sir Edric burned the plague villages on the Church's coin and kept burning after they stopped paying. Good riddance. Keep the sword; you've earned it.",
						"effects": ["give:coin:100", "rep:companies:10", "approve:ketta:5"]}]}},
			], "reward": []}
		"cq_oswin":
			return {"id": id, "title": "Oswin's Penance", "giver": "oswin", "stages": [
				{"text": "Bring Oswin to the Chapel of Ash, %s of %s." % [compass(start.center, s.chapel), start.name],
					"obj": {"type": "reach", "cell": vec(s.chapel), "radius": 3.0}, "target": vec(s.chapel),
					"on_done": ["note:Oswin kneels in the ash for a long time. When he stands, he says only: \"It was my order that barred the doors.\" He walks a little straighter after that.", "stat:oswin:max_hp:15", "approve:oswin:15"]},
			], "reward": []}
		"cq_ketta":
			return {"id": id, "title": "Poacher's Debt", "giver": "ketta", "stages": [
				{"text": "Settle Ketta's debt with Captain Harl in %s." % company.name, "target": vec(company.center),
					"obj": {"type": "talk", "options": [
						{"npc": "harl", "label": "Pay Ketta's debt (40 coin).", "need": ["coin:40"], "reply": "Paid in full. She can stop looking over her shoulder.",
							"effects": ["take:coin:40", "approve:ketta:15", "stat:ketta:attack:2"]},
						{"npc": "harl", "label": "Settle it with 6 hound hides.", "need": ["has:hide:6"], "reply": "Good hides. Fine. We're square.",
							"effects": ["take:hide:6", "approve:ketta:15", "stat:ketta:attack:2"]},
						{"npc": "harl", "label": "Tell Harl the debt dies with his old captain.", "reply": "Bold, from a deserter. Get out before I remember what you're worth to the gallows.",
							"effects": ["rep:companies:-10", "approve:ketta:5", "stat:ketta:attack:2"]},
					]}},
			], "reward": []}
	return {}

static func vec(c: Vector2i) -> Array:
	return [c.x, c.y]

static func compass(from: Vector2i, to: Vector2i) -> String:
	# Isometric: screen-up is (-1,-1) in cells. Report screen directions.
	var d := Vector2(to - from)
	var screen := Vector2(d.x - d.y, (d.x + d.y) * 0.5)
	var names := ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]
	var i := posmod(roundi(screen.angle() / (PI / 4.0)), 8)
	return names[i]
