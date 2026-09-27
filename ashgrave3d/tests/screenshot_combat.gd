extends SceneTree
## A fight: OUT_DIR=/tmp godot --path . -s res://tests/screenshot_combat.gd
func _initialize():
	await process_frame
	var out := OS.get_environment("OUT_DIR")
	var gs = root.get_node("GameState")
	gs.reset()
	gs.recruited = ["maren", "oswin", "ketta"]
	gs.xp = 720   # level 5: third abilities
	root.get_node("TimeOfDay").time = 0.45
	root.get_node("TacticalPause").settings.on_enemy_spotted = false
	root.get_node("TacticalPause").settings.on_low_health = false
	var main = load("res://main.tscn").instantiate()
	main.spawn_encounters = false
	root.add_child(main)
	current_scene = main
	for k in 20: await process_frame
	var party = main.party
	var lead = party.members[0]
	var foes = []
	# fight on open ground: walk the party to a clearing first
	var open = lead.cell
	for r in range(2, 120):
		var ok = true
		var c0 = lead.cell + Vector2i(r, r / 2)
		for dx in range(-4, 8):
			for dy in range(-4, 5):
				if not main.world.walkable(c0 + Vector2i(dx, dy)) or main.world.has_tree(c0 + Vector2i(dx, dy)):
					ok = false
		if ok:
			open = c0
			break
	for i in party.members.size():
		party.members[i].place_at(party.free_near(open + party.FORMATION[i], {}))
	lead = party.members[0]
	main.cam.position = lead.position
	var types = ["risen", "ghoul", "bandit", "risen"]
	for i in types.size():
		var c = party.free_near(lead.cell + Vector2i(3 + i % 2, -1 + i), {})
		foes.append(main.spawn_creature(types[i], c, "", i % 3))
	party.select(party.members.duplicate())
	party.order_attack(foes[0])
	main.cam.follow = null
	main.cam.position = (lead.position + foes[1].position) / 2.0
	main.cam.distance = 13.0
	main.cam._place()
	await create_timer(2.2).timeout
	root.get_viewport().get_texture().get_image().save_png(out + "/c_fight.png")
	lead.use_ability("cleave", lead, lead.cell)
	party.members[1].use_ability("sanctuary", party.members[1], party.members[1].cell)
	party.members[2].use_ability("volley", null, foes[1].cell)
	await create_timer(0.35).timeout
	root.get_viewport().get_texture().get_image().save_png(out + "/c_abilities.png")
	await create_timer(4.0).timeout
	root.get_viewport().get_texture().get_image().save_png(out + "/c_after.png")
	print("alive foes: ", foes.filter(func(f): return is_instance_valid(f) and f.alive()).size(), " party hp: ", party.members.map(func(m): return int(m.hp)))
	print(main.combat_log.lines)
	quit()
