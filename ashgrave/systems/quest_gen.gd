class_name QuestGen
extends RefCounted
## Side quests built from the live world: a real camp, a real village, a real trader.
## Templates: bounty, clear_barrow, gather, courier, dispute.

const TEMPLATES := ["bounty", "clear_barrow", "gather", "courier", "dispute"]

static func nearest_camp(world: WorldGen, from: Vector2i, types: Array, max_dist: float) -> Dictionary:
	var best := {}
	var best_d := max_dist
	var ch := Vector2i(from.x / WorldGen.CHUNK, from.y / WorldGen.CHUNK)
	var taken := {}
	for q in GameState.quests.values():
		for st in q.stages:
			if st.obj.type == "kill_camp":
				taken[st.obj.camp] = true
	for dx in range(-4, 5):
		for dy in range(-4, 5):
			var c := ch + Vector2i(dx, dy)
			if c.x < 0 or c.y < 0 or c.x >= WorldGen.WORLD_CHUNKS or c.y >= WorldGen.WORLD_CHUNKS:
				continue
			for camp in Encounters.camps_for_chunk(world, c):
				if GameState.cleared_camps.has(camp.id) or taken.has(camp.id):
					continue
				if not types.is_empty() and not types.has(camp.type):
					continue
				var d := Vector2(camp.cells[0] - from).length()
				if d < best_d:
					best_d = d
					best = {"id": camp.id, "type": camp.type, "center": camp.cells[0]}
	return best

## An offer from a village trader (npc id "<village>:keeper" or ":smith"). Same offer all day.
static func offer(world: WorldGen, giver: String, village: Dictionary, day: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world.seed_value, giver, day, GameState.quest_counter])
	var order := TEMPLATES.duplicate()
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = order[i]
		order[i] = order[j]
		order[j] = t
	for t in order:
		var q := _make(t, world, giver, village, rng)
		if not q.is_empty():
			q.template = t
			return q
	return {}

static func _make(t: String, world: WorldGen, giver: String, v: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var giver_name := "the trader"
	var turn_in := {"npc": giver, "label": "", "reply": "Good work. Here's what I promised.", "effects": []}
	var reward := 20 + rng.randi_range(0, 4) * 5
	match t:
		"bounty", "clear_barrow":
			var types := ["risen"] if t == "clear_barrow" else ["hound", "cultist", "lurker"]
			var camp := nearest_camp(world, v.center, types, 80.0)
			if camp.is_empty():
				return {}
			var what: String = CreatureDefs.DEFS[camp.type].display_name
			reward += 15 if t == "clear_barrow" else 0
			turn_in.label = "The %s are dead." % what.to_lower()
			turn_in.effects = ["give:coin:%d" % reward, "rep:%s:4" % v.faction]
			return {"title": ("Clear the Barrow" if t == "clear_barrow" else "Bounty: %ss" % what), "giver": giver, "pitch":
				"%s are gathering %s of here. Put them down and I'll pay %d coin." % [what, QuestDefs.compass(v.center, camp.center), reward],
				"stages": [
					{"text": "Kill the %s camp %s of %s." % [what.to_lower(), QuestDefs.compass(v.center, camp.center), v.name], "obj": {"type": "kill_camp", "camp": camp.id}, "target": QuestDefs.vec(camp.center)},
					{"text": "Collect your %d coin in %s." % [reward, v.name], "obj": {"type": "talk", "options": [turn_in]}, "target": QuestDefs.vec(v.center)},
				], "reward": []}
		"gather":
			var item: String = ["bitterroot", "iron-ore", "deadwood", "hide"][rng.randi_range(0, 3)]
			var n := rng.randi_range(3, 6)
			reward = Items.get_def(item).value * n * 2 + 5
			turn_in.label = "Hand over %d %s." % [n, Items.item_name(item).to_lower()]
			turn_in.need = ["has:%s:%d" % [item, n]]
			turn_in.effects = ["take:%s:%d" % [item, n], "give:coin:%d" % reward, "rep:%s:2" % v.faction]
			return {"title": "Supplies: %s" % Items.item_name(item), "giver": giver,
				"pitch": "I'm short on %s. Bring me %d and I'll pay %d coin." % [Items.item_name(item).to_lower(), n, reward],
				"stages": [{"text": "Bring %d %s to %s." % [n, Items.item_name(item).to_lower(), v.name], "obj": {"type": "talk", "options": [turn_in]}, "target": QuestDefs.vec(v.center)}],
				"reward": []}
		"courier":
			var other := {}
			var best := INF
			for w in world.villages():
				var d := Vector2(w.center - v.center).length()
				if w.id != v.id and d < best:
					best = d
					other = w
			if other.is_empty():
				return {}
			reward = 15 + int(best / 8.0)
			var target_npc: String = "%s:keeper" % other.id
			return {"title": "Letter for %s" % other.name, "giver": giver,
				"pitch": "This letter needs to reach the tavern in %s, %s of here. %d coin when it's delivered." % [other.name, QuestDefs.compass(v.center, other.center), reward],
				"start_effects": ["give:sealed-letter:1"],
				"stages": [{"text": "Deliver the sealed letter to the tavern keeper in %s." % other.name, "target": QuestDefs.vec(other.center),
					"obj": {"type": "talk", "options": [{"npc": target_npc, "label": "Deliver the sealed letter.", "need": ["has:sealed-letter"],
						"reply": "From %s? About time. Here, the sender left this for the courier." % v.name, "effects": ["take:sealed-letter", "give:coin:%d" % reward]}]}}],
				"reward": []}
		"dispute":
			var smith := "%s:smith" % v.id
			if smith == giver:
				return {}
			var rival: String = ["church", "companies", "hollow"].filter(func(f): return f != v.faction)[rng.randi_range(0, 1)]
			return {"title": "A Quarrel in %s" % v.name, "giver": giver,
				"pitch": "The smith has been selling blades to %s agents. Half the village wants him run out. Talk to him and settle it, one way or the other." % Factions.NAMES[rival],
				"stages": [{"text": "Settle the smith's quarrel in %s." % v.name, "target": QuestDefs.vec(v.center),
					"obj": {"type": "talk", "options": [
						{"npc": smith, "label": "Tell him to stop dealing with the %s." % Factions.NAMES[rival], "reply": "...Fine. My own village over coin. Fine.", "effects": ["rep:%s:6" % v.faction, "rep:%s:-4" % rival, "give:coin:15"]},
						{"npc": smith, "label": "Back the smith: his trade, his business.", "reply": "Finally, someone with sense. Take this, you earned it.", "effects": ["rep:%s:6" % rival, "rep:%s:-4" % v.faction, "give:iron-ore:3"]},
					]}}],
				"reward": []}
	return {}
