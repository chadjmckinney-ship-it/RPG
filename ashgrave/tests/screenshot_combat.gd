extends SceneTree
## Renders a mid-fight tactical pause with queued orders:  OUT=/tmp/x.png godot --path . -s res://tests/screenshot_combat.gd
func _initialize():
	await process_frame
	var tp = root.get_node("TacticalPause")
	root.get_node("TimeOfDay").time = 0.72
	var main = load("res://main.tscn").instantiate()
	main.spawn_encounters = false
	root.add_child(main)
	tp.settings.on_enemy_spotted = false
	await process_frame
	var lead = main.party.members[0]
	var foes = []
	var types = ["hound", "risen", "cultist", "lurker"]
	var i = 0
	for r in range(3, 9):
		for dx in range(-r, r + 1):
			var c = lead.cell + Vector2i(dx, -r)
			if foes.size() < 4 and main.world.walkable(c) and not main.world.has_tree(c) and not main.pathfinder.find_path(lead.cell, c).is_empty():
				foes.append(main.spawn_creature(types[i], c)); i += 1
	main.party.select(main.party.members.duplicate())
	main.party.order_attack(foes[0])
	for k in 150: await process_frame
	await create_timer(2.5).timeout
	tp.set_paused(true)
	main.party.select([main.party.members[1], main.party.members[2]])
	main.party.order_attack(foes[min(2, foes.size() - 1)], true)
	main.party.members[2].use_ability("snare", null, foes[1].cell, true)
	for k in 30: await process_frame
	root.get_viewport().get_texture().get_image().save_png(OS.get_environment("OUT"))
	quit()
