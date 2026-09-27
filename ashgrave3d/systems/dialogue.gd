class_name Dialogue
extends RefCounted
## Conversations are built per NPC from their role, the story state and live quest options.
## Node: {speaker, text, choices: [{label, enabled, next: Dictionary | "root" | "end" | "trade",
##        effects: [ScriptOps effects], action: Callable}]}

var npc               # Villager
var node: Dictionary = {}
var result := ""      # "", "end" or "trade" once finished

func _init(v) -> void:
	npc = v
	node = root()

## Pick a choice; returns false if it's disabled or out of range.
func choose(i: int) -> bool:
	if i < 0 or i >= node.choices.size():
		return false
	var c: Dictionary = node.choices[i]
	if not c.get("enabled", true):
		return false
	ScriptOps.run_all(c.get("effects", []))
	var next = c.get("next", "root")
	if c.has("action"):
		var r = c.action.call()
		if r is Dictionary:
			next = r
	if next is Dictionary:
		node = next
	elif next == "root":
		node = root()
	else:
		result = next
	return true

func _say(text: String, choices: Array) -> Dictionary:
	return {"speaker": npc.display_name, "text": text, "choices": choices}

func _back(text: String) -> Dictionary:
	return _say(text, [{"label": "Go on.", "next": "root"}])

func root() -> Dictionary:
	var choices: Array = []
	var text := _greeting()
	# Quest turn-ins and decisions come first.
	for q in QuestLog.talk_options(npc.npc_id):
		choices.append({"label": "[%s] %s" % [q.title, q.opt.label], "enabled": q.ok, "action": _quest_action.bind(q.quest, q.opt)})
	if npc.npc_id == "harl" and not GameState.quests.has("sq_ashen"):
		var pitch := _say("There's a knight in the ashfields who never stopped burning villages. Company contract, twenty years stale. He's still collecting. End him and there's a hundred coin in it.", [
			{"label": "Consider it done.", "effects": ["quest_start:sq_ashen"], "next": "end"},
			{"label": "Not now.", "next": "root"}])
		choices.append({"label": "Any work for a deserter, Captain?", "next": pitch})
	match npc.job:
		"elder": choices.append_array(_maud_choices())
		"companion": choices.append_array(_companion_choices())
		"keeper", "smith":
			if Factions.will_trade(GameState.reputation.get(npc.trader_faction(), 0)):
				choices.append({"label": "Let's trade.", "next": "trade"})
			choices.append(_work_choice())
	choices.append({"label": "Farewell.", "next": "end"})
	return _say(text, choices)

func _greeting() -> String:
	var rep: int = GameState.reputation.get(npc.trader_faction(), 0)
	match npc.npc_id:
		"maud":
			if not GameState.quests.has("mq_restless"):
				return "You're Vey. The deserter. I know the face from the Company's bills. I don't care. I have dead men walking out of the hills and three wardens left to stop them."
			if ScriptOps.check("done:mq_dust"):
				return "The hills are quiet. Whatever you decided about that ledger, we'll all live with it."
			return "Still breathing? Good. The dead aren't."
		"nessa":
			return "The dead are restless because someone woke them, girl. The dead are always a message." if not ScriptOps.check("flag:ledger_hollow") else "You did right by us. The barrows will be tended now."
		"harl":
			return "Maren Vey. Deserters hang, you know. But the Company is practical, and so am I. What do you want?" if not ScriptOps.check("flag:ledger_companies") else "My favourite former deserter. The Company remembers its friends."
		"oswin":
			return "I was a Tithe warden once. I barred a chapel door with the sick still inside because I was told to. I'm looking for a way to be useful instead of sorry."
		"ketta":
			return "You've got the look of someone who kills things for money. I kill things for supper. Could use the company, and I owe some people I'd rather not meet alone."
	if npc.job == "villager":
		return npc.chatter()
	if not Factions.will_trade(rep):
		return "We don't deal with your kind. Move along, deserter."
	return "Welcome to %s. %s" % [npc.village.name, "What'll it be?" if rep >= -10 else "Coin first, questions never."]

func _maud_choices() -> Array:
	if GameState.quests.has("mq_restless"):
		return []
	var accept := _say("There's a knot of barrow-risen out in the hills. Clear it. Then we'll talk about why they're walking at all. There's coin in it, and I'll forget I ever saw your face on a bill.", [
		{"label": "I'll do it.", "effects": ["quest_start:mq_restless"], "next": "end"},
		{"label": "Not yet.", "next": "root"}])
	return [{"label": "What's happening here?", "next": accept}]

func _companion_choices() -> Array:
	var id: String = npc.npc_id
	if GameState.recruited.has(id):
		return []
	var d: Dictionary = Companions.DEFS[id]
	var join := _say("Then I'm with you. Where you go, I go.", [{"label": "Welcome.", "effects": ["recruit:%s" % id], "next": "end"}])
	return [{"label": "Join my company, %s." % d.name.split(" ")[-1], "next": join}]

func _work_choice() -> Dictionary:
	var giver: String = npc.npc_id
	for q in QuestLog.active():
		if q.giver == giver:
			return {"label": "Any work? (you're already on a job for them)", "enabled": false}
	var offer := QuestGen.offer(GameState.world, giver, npc.village, TimeOfDay.day)
	if offer.is_empty():
		return {"label": "Any work? (nothing today)", "enabled": false}
	var pitch := _say(offer.pitch, [
		{"label": "I'll take it.", "action": _accept_offer.bind(offer)},
		{"label": "Not today.", "next": "root"}])
	return {"label": "Any work?", "next": pitch}

func _quest_action(qid: String, opt: Dictionary) -> Dictionary:
	QuestLog.choose(qid, opt)
	return _back(opt.get("reply", "..."))

func _accept_offer(offer: Dictionary) -> Dictionary:
	var q := offer.duplicate(true)
	GameState.quest_counter += 1
	q.id = "gq%d" % GameState.quest_counter
	QuestLog.accept(q)
	return _back("Good. Don't die on the way; it's bad for business.")
