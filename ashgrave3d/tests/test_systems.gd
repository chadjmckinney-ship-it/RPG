extends TestCase
## Inventory, crafting, equipment, factions, settlements, gathering, schedules, save/load.

func _boot() -> Node:
	GameState.reset()
	GameState.recruited = ["maren", "oswin", "ketta"]
	var main: Node = load("res://main.tscn").instantiate()
	main.spawn_encounters = false
	tree.root.add_child(main)
	await tree.process_frame
	TacticalPause.set_paused(false)
	return main

func _teardown(main: Node) -> void:
	TacticalPause.set_paused(false)
	main.queue_free()
	await tree.process_frame
	GameState.reset()

func test_inventory() -> void:
	var inv := Inventory.new()
	inv.add("hide", 3)
	check(inv.count("hide") == 3, "add failed")
	check(not inv.remove("hide", 4), "removed more than owned")
	check(inv.count("hide") == 3, "failed remove changed the count")
	check(inv.remove("hide", 3) and not inv.counts.has("hide"), "emptied entry not cleared")
	inv.add("bandage", 0)
	check(not inv.counts.has("bandage"), "adding zero created an entry")

func test_crafting() -> void:
	var inv := Inventory.new()
	check(not Crafting.can_craft(inv, "bandage", ["camp"]), "crafted from nothing")
	inv.add("bitterroot", 5)
	check(Crafting.craft(inv, "bandage", ["camp"]), "bandage craft failed")
	check(inv.count("bandage") == 2 and inv.count("bitterroot") == 3, "wrong craft result: %s" % inv.counts)
	inv.add("iron-ore", 3)
	inv.add("deadwood", 1)
	check(not Crafting.can_craft(inv, "iron-blade", ["camp"]), "forge recipe allowed at camp")
	check(Crafting.craft(inv, "iron-blade", ["camp", "forge"]), "forge craft failed")
	check(Crafting.missing(inv, "iron-mail") == {"iron-ore": 5, "hide": 2}, "missing() wrong: %s" % Crafting.missing(inv, "iron-mail"))
	for id in Crafting.RECIPES:
		check(Items.DEFS.has(id), "recipe output %s has no item" % id)
		for k in Crafting.RECIPES[id].in:
			check(Items.DEFS.has(k), "recipe input %s has no item" % k)

func test_equipment() -> void:
	var main: Node = await _boot()
	var inv := GameState.inventory
	var maren: PartyMember = main.party.members[0]
	var ketta: PartyMember = main.party.members[2]
	var atk := maren.attack
	inv.add("iron-blade")
	inv.add("yew-bow")
	check(not maren.equip("yew-bow", inv), "melee fighter equipped a bow")
	check(maren.equip("iron-blade", inv), "equip failed")
	check(maren.attack == atk + 4.0, "blade bonus not applied: %s" % maren.attack)
	check(not inv.has("iron-blade"), "equipped item still in pack")
	check(ketta.equip("yew-bow", inv), "archer couldn't take a bow")
	inv.add("iron-mail")
	var spd := maren.speed
	maren.equip("iron-mail", inv)
	check(maren.defense == 5.0 + 5.0 and maren.speed == spd - 12.0, "mail bonus/penalty wrong")
	maren.unequip("weapon", inv)
	check(maren.attack == atk and inv.has("iron-blade"), "unequip didn't restore")
	maren.hp = 10.0
	inv.add("bandage")
	check(maren.use_item("bandage", inv) and maren.hp == 40.0, "bandage didn't heal 30")
	await _teardown(main)

func test_faction_prices() -> void:
	check(Factions.buy_price(40, 50) < Factions.buy_price(40, 0), "good standing not cheaper")
	check(Factions.buy_price(40, -30) > Factions.buy_price(40, 0), "bad standing not dearer")
	check(Factions.sell_price(40, 50) > Factions.sell_price(40, -30), "sell prices ignore standing")
	check(Factions.buy_price(1, 100) >= 1 and Factions.sell_price(1, -100) >= 1, "price fell below 1")
	check(not Factions.will_trade(-45) and Factions.will_trade(-25), "trade threshold wrong")
	GameState.reset()
	GameState.change_rep("church", 500)
	check(GameState.reputation.church == 100, "reputation not clamped")
	check(GameState.reputation.companies == -25, "deserter should start distrusted by the Companies")
	GameState.reset()

func test_settlements() -> void:
	for s in [1337, 7, 424242]:
		var w := WorldGen.new(s)
		var vs := w.villages()
		check(vs.size() >= 4, "seed %d has only %d villages" % [s, vs.size()])
		check(str(vs) == str(Settlements.generate(WorldGen.new(s))), "villages not deterministic")
		for v in vs:
			check(w.walkable(v.center), "%s centre blocked" % v.name)
			check(not w.walkable(Settlements.building_cell(v, "forge")), "forge cell walkable")
			check(w.walkable(Settlements.door_cell(v, "forge")), "%s forge door blocked" % v.name)
			check(Factions.NAMES.has(v.faction), "bad faction")
		var sp := w.spawn_cell()
		var nearest := INF
		for v in vs:
			nearest = minf(nearest, Vector2(v.center - sp).length())
		check(nearest < 16.0, "seed %d spawn is %0.1f from any village" % [s, nearest])
		for cx in range(0, 16, 3):
			for cy in range(0, 16, 3):
				for camp in Encounters.camps_for_chunk(w, Vector2i(cx, cy)):
					for c in camp.cells:
						check(w.village_near(c, Encounters.VILLAGE_RADIUS).is_empty(), "camp inside a village at %s" % c)

func test_gathering() -> void:
	GameState.reset()
	var w := WorldGen.new(1337)
	var found := 0
	for ch in [Vector2i(7, 7), Vector2i(8, 8), Vector2i(5, 9)]:
		var a := Gathering.nodes_for_chunk(w, ch)
		check(str(a) == str(Gathering.nodes_for_chunk(w, ch)), "nodes not deterministic")
		for n in a:
			found += 1
			check(w.walkable(n.cell), "node on blocked cell")
	check(found > 0, "no gather nodes")
	var node := {"id": "test-node", "kind": "herb", "cell": Vector2i.ZERO}
	var got := Gathering.harvest(node, 3)
	check(got.item == "bitterroot" and GameState.inventory.count("bitterroot") == got.count, "harvest didn't add items")
	check(Gathering.harvest(node, 4).is_empty(), "harvested twice in a row")
	check(not Gathering.harvest(node, 5).is_empty(), "node didn't regrow after %d days" % Gathering.REGROW_DAYS)
	GameState.reset()

func test_villager_schedule() -> void:
	var w := WorldGen.new(1337)
	var v: Dictionary = w.villages()[0]
	var smith := Villager.new()
	smith.world = w
	smith.setup(v, "smith", 0)
	check(smith.schedule_target(10) == Settlements.door_cell(v, "forge"), "smith not at forge by day")
	check(smith.schedule_target(20) == smith.tavern_cell, "not at tavern in the evening")
	check(smith.schedule_target(2) == smith.home_cell, "not home at night")
	check(smith.is_trader() and smith.stock().has("iron-blade"), "smith has no blades")
	smith.free()

func test_villagers_get_different_bodies() -> void:
	var w := WorldGen.new(1337)
	for v in w.villages():
		var a := Villager.new()
		a.world = w
		a.setup(v, "villager", 2)
		var b := Villager.new()
		b.world = w
		b.setup(v, "villager", 3)
		check(a.body.id in Villager.VILLAGER_BODIES and b.body.id in Villager.VILLAGER_BODIES, "villager body not one of %s" % [Villager.VILLAGER_BODIES])
		check(a.body.id != b.body.id, "two villagers in %s share a body" % v.id)
		a.free()
		b.free()

func test_gather_in_world() -> void:
	var main: Node = await _boot()
	var lead: PartyMember = main.party.members[0]
	var best: Node = null
	for n in main.gather_nodes:
		if n.ready_to_harvest() and not main.pathfinder.find_path(lead.cell, n.data.cell).is_empty():
			if best == null or lead.cell_distance(n.data.cell) < lead.cell_distance(best.data.cell):
				best = n
	check(best != null, "no reachable gather node near spawn")
	if best:
		var item: String = Gathering.KINDS[best.data.kind].item
		var before: int = GameState.inventory.count(item)
		main.party.select([lead])
		main.party.order_interact(best, best.data.cell, 1.5)
		for i in 300:
			await tree.create_timer(0.1).timeout
			if GameState.inventory.count(item) > before:
				break
		check(GameState.inventory.count(item) > before, "walking to %s gathered nothing" % best.display_name())
	await _teardown(main)

func test_save_load_round_trip() -> void:
	var main: Node = await _boot()
	var inv := GameState.inventory
	inv.add("iron-blade")
	main.party.members[0].equip("iron-blade", inv)
	inv.add("hide", 7)
	GameState.change_rep("hollow", 12)
	GameState.cleared_camps["9:9:0"] = true
	GameState.harvested["g1:1:1"] = 2
	TimeOfDay.day = 4
	main.party.members[1].hp = 33.0
	var saved: Dictionary = JSON.parse_string(JSON.stringify(GameState.to_dict(main.party_state())))
	# scramble everything
	GameState.reset()
	TimeOfDay.day = 1
	main.party.members[0].unequip("weapon", GameState.inventory)
	main.party.members[1].hp = 96.0
	main.party.members[1].place_at(main.party.members[1].cell + Vector2i(1, 0))
	GameState.load_dict(saved)
	main.apply_party_state(saved.party)
	check(GameState.inventory.count("hide") == 7, "inventory not restored")
	check(GameState.reputation.hollow == 12, "reputation not restored")
	check(GameState.cleared_camps.has("9:9:0") and GameState.harvested.get("g1:1:1") == 2, "world diffs not restored")
	check(TimeOfDay.day == 4, "day not restored")
	check(main.party.members[0].equipment.weapon == "iron-blade", "equipment not restored")
	check(main.party.members[0].attack == 16.0, "equipment bonus not reapplied: %s" % main.party.members[0].attack)
	check(main.party.members[1].hp == 33.0, "hp not restored")
	check(GameState.write_save(saved), "couldn't write the save file")
	var disk := GameState.read_save()
	check(disk.get("seed") == saved.seed and disk.get("inventory", {}).get("hide") == 7, "save file didn't round-trip")
	await _teardown(main)
