extends SceneTree
## Balance harness: stages fights in the real game at high speed and prints a table.
##   godot --headless --path . -s res://tests/balance.gd   (RUNS=n to change repetitions)

const SCENARIOS := [
	# [label, party ids, gear, enemies]
	["Maren solo vs hound", ["maren"], "none", ["hound"]],
	["Maren solo vs crows", ["maren"], "none", ["crows"]],
	["Maren solo vs cultist", ["maren"], "none", ["cultist"]],
	["Maren solo vs bandit", ["maren"], "none", ["bandit"]],
	["Maren solo vs risen", ["maren"], "none", ["risen"]],
	["Party vs 3 hounds", ["maren", "oswin", "ketta"], "none", ["hound", "hound", "hound"]],
	["Party vs 3 crows", ["maren", "oswin", "ketta"], "none", ["crows", "crows", "crows"]],
	["Party vs cultists+risen", ["maren", "oswin", "ketta"], "none", ["cultist", "cultist", "risen"]],
	["Party vs 3 lurkers", ["maren", "oswin", "ketta"], "none", ["lurker", "lurker", "lurker"]],
	["Party vs 2 wights", ["maren", "oswin", "ketta"], "none", ["wight", "wight"]],
	["Party vs 3 ghouls", ["maren", "oswin", "ketta"], "none", ["ghoul", "ghoul", "ghoul"]],
	["Party vs bandit camp", ["maren", "oswin", "ketta"], "none", ["bandit", "crossbow", "crossbow"]],
	["Party vs 2 boars", ["maren", "oswin", "ketta"], "none", ["boar", "boar"]],
	["Party vs 2 revenants", ["maren", "oswin", "ketta"], "none", ["revenant", "revenant"]],
	["Geared vs Drowned Lord", ["maren", "oswin", "ketta"], "iron", ["barrow_lord", "risen", "risen"]],
	["Geared vs Ashen Knight", ["maren", "oswin", "ketta"], "iron", ["ash_knight", "ghoul"]],
]
const GEAR := {"iron": {"maren": ["iron-blade", "hide-jerkin"], "oswin": ["iron-blade", "iron-mail"], "ketta": ["yew-bow", "hide-jerkin"]}}

func _initialize() -> void:
	await process_frame
	var runs := int(OS.get_environment("RUNS")) if OS.get_environment("RUNS") != "" else 4
	var only := OS.get_environment("ONLY")
	var gs = root.get_node("GameState")
	var tp = root.get_node("TacticalPause")
	tp.settings.on_enemy_spotted = false
	tp.settings.on_low_health = false
	Engine.time_scale = 8.0
	print("%-28s %6s %8s %8s" % ["scenario", "win%", "time(s)", "hp left"])
	for sc in SCENARIOS:
		if only != "" and not only in sc[0]:
			continue
		var wins := 0
		var t_sum := 0.0
		var hp_sum := 0.0
		for r in runs:
			var res: Dictionary = await _fight(gs, sc)
			if res.win:
				wins += 1
				t_sum += res.time
				hp_sum += res.hp
		print("%-28s %5d%% %8s %8s" % [sc[0], wins * 100 / runs, "%.1f" % (t_sum / wins) if wins else "-", "%d%%" % int(hp_sum / wins * 100) if wins else "-"])
	quit()

func _fight(gs, sc: Array) -> Dictionary:
	gs.reset()
	gs.recruited = sc[1].duplicate()
	var main = load("res://main.tscn").instantiate()
	main.spawn_encounters = false
	root.add_child(main)
	await process_frame
	for m in main.party.members:
		for id in GEAR.get(sc[2], {}).get(m.companion_id, []):
			gs.inventory.add(id)
			m.equip(id, gs.inventory)
		m.hp = m.max_hp
	var lead = main.party.members[0]
	var foes := []
	var r := 5
	while foes.size() < sc[3].size() and r < 14:
		for dx in range(-r, r + 1):
			var c = lead.cell + Vector2i(dx, -r)
			if foes.size() < sc[3].size() and main.world.walkable(c) and not main.world.has_tree(c) and not main.pathfinder.find_path(lead.cell, c).is_empty():
				foes.append(main.spawn_creature(sc[3][foes.size()], c))
		r += 1
	main.party.select(main.party.members.duplicate())
	main.party.order_attack(foes[0])
	var t := 0.0
	var win := false
	while t < 180.0:
		await create_timer(0.25).timeout
		t += 0.25 * Engine.time_scale
		if foes.all(func(f): return not is_instance_valid(f) or f.downed):
			win = true
			break
		if main.party.members.all(func(m): return m.downed):
			break
	if not win and OS.get_environment("DEBUG") != "":
		var left := foes.filter(func(f): return is_instance_valid(f) and not f.downed).map(func(f): return "%s %d/%d home=%s cell=%s ret=%s" % [f.type_id, f.hp, f.max_hp, f.home, f.cell, f.returning])
		print("   lost: party down=%s  foes=%s" % [main.party.members.all(func(m): return m.downed), left])
		for f in foes:
			if is_instance_valid(f) and not f.downed:
				print("     foe paused=%s statuses=%s swing=%s tgt=%s dist=%s" % [root.get_node("TacticalPause").paused, f.statuses, f._swing_cd, f.current.target.display_name if f.current and is_instance_valid(f.current.get("target")) else "?", f.cell_distance(f.current.target.cell) if f.current and is_instance_valid(f.current.get("target")) else -1])
		for m in main.party.members:
			print("     %s cell=%s down=%s order=%s hp=%d" % [m.display_name, m.cell, m.downed, m.current, m.hp])
		var rz = foes.filter(func(f): return is_instance_valid(f) and not f.downed)
		if not rz.is_empty():
			var z = rz[0]
			for i in 8:
				var mm = main.party.members[0]
				print("     Z cell=%s hp=%.0f | M pos=%s cell=%s path=%s swing=%.2f dist=%.2f range=%.1f st=%s" % [z.cell, z.hp, mm.position, mm.cell, mm.path, mm._swing_cd, mm.cell_distance(z.cell), mm.attack_range, mm.statuses.keys()])
				await create_timer(0.05).timeout
		var k = main.party.members[main.party.members.size() - 1]
		for i in 30:
			var tg = k.current.get("target") if k.current else null
			print("     rhp=%.1f khp=%.1f t%d ketta pos=%s swing=%.2f kite=%.2f tgt_valid=%s tgt=%s tgt_down=%s tgt_cell=%s path=%s orders=%d" % [tg.hp if is_instance_valid(tg) else -1.0, k.hp, i, k.position, k._swing_cd, k._kite_cd, is_instance_valid(tg), tg.display_name if is_instance_valid(tg) else "-", tg.downed if is_instance_valid(tg) else "-", tg.cell if is_instance_valid(tg) else "-", k.path, k.orders.size()])
			await create_timer(0.1).timeout
	var hp := 0.0
	for m in main.party.members:
		hp += (0.0 if m.downed else m.hp) / m.max_hp
	hp /= main.party.members.size()
	main.queue_free()
	await process_frame
	return {"win": win, "time": t, "hp": hp}
