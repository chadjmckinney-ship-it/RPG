class_name ScriptOps
extends RefCounted
## Tiny command language shared by dialogue, quests and rewards.
## Conditions:  flag:x  !flag:x  has:item:n  coin:n  recruited:id  !recruited:id
##              quest:id (known)  !quest:id  active:id  done:id  stage:id:n  rep:faction:>=n
## Effects:     flag:x  give:item:n  take:item:n  rep:faction:+n  approve:id:+n
##              quest_start:id  quest_advance:id  recruit:id  spawn:what  stat:id:stat:+n

static func check(cond: String) -> bool:
	var neg := cond.begins_with("!")
	var c := cond.substr(1) if neg else cond
	var p := c.split(":")
	var r := false
	match p[0]:
		"flag": r = GameState.flags.has(p[1])
		"has": r = GameState.inventory.has(p[1], int(p[2]) if p.size() > 2 else 1)
		"coin": r = GameState.inventory.has("coin", int(p[1]))
		"recruited": r = GameState.recruited.has(p[1])
		"quest": r = GameState.quests.has(p[1])
		"active": r = GameState.quests.has(p[1]) and GameState.quests[p[1]].status == "active"
		"done": r = GameState.quests.has(p[1]) and GameState.quests[p[1]].status == "done"
		"stage": r = GameState.quests.has(p[1]) and GameState.quests[p[1]].status == "active" and GameState.quests[p[1]].stage == int(p[2])
		"rep":
			var v: int = GameState.reputation.get(p[1], 0)
			var rhs := p[2]
			r = v >= int(rhs.substr(2)) if rhs.begins_with(">=") else v <= int(rhs.substr(2))
	return not r if neg else r

static func check_all(conds: Array) -> bool:
	for c in conds:
		if not check(c):
			return false
	return true

static func run(effect: String) -> void:
	var p := effect.split(":")
	match p[0]:
		"flag": GameState.flags[p[1]] = true
		"give":
			var n := int(p[2]) if p.size() > 2 else 1
			GameState.inventory.add(p[1], n)
			Events.combat_message.emit("Received %s%s." % [Items.item_name(p[1]), (" ×%d" % n) if n > 1 else ""])
		"take": GameState.inventory.remove(p[1], int(p[2]) if p.size() > 2 else 1)
		"rep": GameState.change_rep(p[1], int(p[2]))
		"approve":
			GameState.approval[p[1]] = clampi(GameState.approval.get(p[1], 0) + int(p[2]), -100, 100)
			if GameState.recruited.has(p[1]):
				Events.combat_message.emit("%s %s." % [Companions.DEFS[p[1]].name, "approves" if int(p[2]) > 0 else "disapproves"])
		"quest_start": QuestLog.start(p[1])
		"quest_advance": QuestLog.advance(p[1])
		_:
			# World-changing effects (recruit, spawn, stat) are handled by main.gd.
			Events.story_effect.emit(effect)

static func run_all(effects: Array) -> void:
	for e in effects:
		run(e)
