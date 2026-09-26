class_name QuestLog
extends RefCounted
## Active and finished quests, stored in GameState.quests as plain (saveable) dictionaries:
## {id, title, giver, status, stage, stages: [{text, obj, target, on_done}], reward: [effects], data}
## Objectives: kill_camp {camp} | kill_type {creature, count} | reach {cell, radius}
##             talk {options: [{npc, label, reply, need: [conds], effects: [...]}]}

static func start(id: String) -> void:
	if GameState.quests.has(id):
		return
	var q := QuestDefs.build(id, GameState.world)
	if q.is_empty():
		return
	accept(q)

static func accept(q: Dictionary) -> void:
	q.status = "active"
	q.stage = 0
	q.data = q.get("data", {"count": 0})
	GameState.quests[q.id] = q
	GameState.tracked = q.id
	ScriptOps.run_all(q.get("start_effects", []))
	Events.combat_message.emit("New quest: %s" % q.title)
	Events.quests_changed.emit()
	# A quest may already be satisfied (camp cleared earlier, items in hand...)
	_check_instant(q)

static func current(q: Dictionary) -> Dictionary:
	return q.stages[q.stage] if q.status == "active" and q.stage < q.stages.size() else {}

static func advance(id: String) -> void:
	var q: Dictionary = GameState.quests.get(id, {})
	if q.is_empty() or q.status != "active":
		return
	var st := current(q)
	ScriptOps.run_all(st.get("on_done", []))
	q.stage += 1
	q.data.count = 0
	if q.stage >= q.stages.size():
		q.status = "done"
		Events.combat_message.emit("Quest complete: %s" % q.title)
		ScriptOps.run_all(q.get("reward", []))
		if GameState.tracked == id:
			GameState.tracked = _next_active()
	else:
		Events.combat_message.emit("%s — %s" % [q.title, current(q).text])
		_check_instant(q)
	Events.quests_changed.emit()

static func _check_instant(q: Dictionary) -> void:
	var st := current(q)
	if st.is_empty():
		return
	if st.obj.type == "kill_camp" and GameState.cleared_camps.has(st.obj.camp):
		advance(q.id)

static func _next_active() -> String:
	for id in GameState.quests:
		if GameState.quests[id].status == "active":
			return id
	return ""

static func active() -> Array:
	return GameState.quests.values().filter(func(q): return q.status == "active")

## Called when a creature dies (after camp bookkeeping).
static func notify_kill(creature_type: String, camp_id: String) -> void:
	for q in active():
		var o: Dictionary = current(q).get("obj", {})
		match o.get("type"):
			"kill_camp":
				if o.camp == camp_id and GameState.cleared_camps.has(camp_id):
					advance(q.id)
			"kill_type":
				if o.creature == creature_type:
					q.data.count += 1
					if q.data.count >= o.count:
						advance(q.id)
					else:
						Events.quests_changed.emit()

## Called periodically with the party's cells.
static func notify_positions(cells: Array) -> void:
	for q in active():
		var o: Dictionary = current(q).get("obj", {})
		if o.get("type") != "reach":
			continue
		var target := Vector2i(o.cell[0], o.cell[1])
		for c in cells:
			if Vector2(c - target).length() <= o.radius:
				advance(q.id)
				break

## Quest-specific dialogue choices offered by an NPC right now.
static func talk_options(npc: String) -> Array:
	var out: Array = []
	for q in active():
		var o: Dictionary = current(q).get("obj", {})
		if o.get("type") != "talk":
			continue
		for opt in o.options:
			if opt.npc == npc:
				out.append({"quest": q.id, "title": q.title, "opt": opt, "ok": ScriptOps.check_all(opt.get("need", []))})
	return out

static func choose(quest_id: String, opt: Dictionary) -> bool:
	if not ScriptOps.check_all(opt.get("need", [])):
		return false
	ScriptOps.run_all(opt.get("effects", []))
	advance(quest_id)
	return true

static func target_cell(q: Dictionary) -> Variant:
	var st := current(q)
	if st.is_empty() or st.get("target") == null:
		return null
	return Vector2i(st.target[0], st.target[1])
