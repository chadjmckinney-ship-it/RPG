extends Node3D
## Ashgrave 3D: the world, the party, the camera, the sun, camps, villages and story sites,
## combat bookkeeping, panels and save/load.

const OUT_OF_COMBAT_REGEN := 3.0   # hp/s
const REVIVE_DELAY := 4.0          # seconds of calm before downed members get up

## Tests and the balance harness turn camps off.
@export var spawn_encounters := true

var world: WorldGen
var terrain: Terrain
var pathfinder: Pathfinder
var cam: RtsCamera
var party: PartyController
var sun: DirectionalLight3D
var env: WorldEnvironment
var fx: Fx3D
var hud: Hud3D
var overlay: WorldOverlay
var panels: Panels
var portraits: Portraits3D
var actors: Array = []
var chunk_props := {}           # chunk -> [Node] (villagers, gather nodes, landmarks)
var gather_nodes: Array = []
var interactables: Array = []   # non-actor things the party can right-click (gather nodes)
var _quest_timer := 0.0
var combat_log := CombatLog.new()
var camp_creatures := {}        # chunk -> [Creature]
var in_combat := false
var calm_time := 0.0
var _low_hp_warned := {}
var _defeat_timer := -1.0

func _ready() -> void:
	Actor.ctx = self
	if not GameState.pending_load.is_empty():
		GameState.load_dict(GameState.pending_load)
	if GameState.world == null:
		GameState.new_world(GameState.world_seed)
	world = GameState.world
	Events.combat_message.connect(combat_log.add)
	Events.enemy_spotted.connect(_on_enemy_spotted)
	env = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.fog_enabled = true
	env.environment.fog_density = 0.004
	env.environment.fog_sky_affect = 0.0
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	add_child(env)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)
	terrain = Terrain.new()
	terrain.name = "Terrain"
	add_child(terrain)
	terrain.setup(world)
	terrain.chunk_loaded.connect(_spawn_camps)
	terrain.chunk_unloaded.connect(_despawn_camps)
	terrain.chunk_loaded.connect(_spawn_props)
	terrain.chunk_unloaded.connect(_despawn_props)
	portraits = Portraits3D.new()
	portraits.name = "Portraits"
	add_child(portraits)
	fx = Fx3D.new()
	add_child(fx)
	pathfinder = Pathfinder.new(world)
	cam = RtsCamera.new()
	cam.world = world
	add_child(cam)
	var ui := CanvasLayer.new()
	add_child(ui)
	overlay = WorldOverlay.new()
	overlay.main = self
	ui.add_child(overlay)
	party = PartyController.new()
	party.cam = cam
	party.world = world
	party.pathfinder = pathfinder
	ui.add_child(party)
	hud = Hud3D.new()
	ui.add_child(hud)
	hud.setup(self)
	panels = Panels.new()
	add_child(panels)
	panels.setup(self)
	var spawn := world.spawn_cell()
	pathfinder.ensure_covers(spawn)
	for id in Companions.ORDER:
		if GameState.recruited.has(id):
			add_member(id, party.free_near(spawn + PartyController.FORMATION[party.members.size()], {}))
	party.select([party.members[0]])
	if not GameState.pending_load.is_empty():
		var data := GameState.pending_load
		GameState.pending_load = {}
		apply_party_state(data.get("party", []))
		spawn = party.members[0].cell
	cam.position = party.members[0].position
	cam.follow = party.members[0]
	terrain.focus_cell = spawn
	terrain.load_all_now()
	Events.leveled_up.connect(_on_leveled_up)
	Events.talk_requested.connect(panels.open_dialogue)
	Events.story_effect.connect(_on_story_effect)
	apply_graphics()
	_update_sun()
	if ScriptOps.check("stage:mq_dust:2"):
		_spawn_barrow()
	if ScriptOps.check("stage:sq_ashen:1"):
		_spawn_boss("ashen")
	log_msg("Maren Vey's company makes camp at the edge of the wilds.")

func log_msg(text: String) -> void:
	Events.combat_message.emit(text)

func add_member(id: String, at: Vector2i) -> PartyMember:
	var m := PartyMember.new()
	m.world = world
	add_child(m)
	m.setup_member(id)
	m.place_at(at)
	party.members.append(m)
	actors.append(m)
	return m

# ---------------------------------------------------------------- creatures

func spawn_creature(type: String, at: Vector2i, camp_id := "", rank := 0) -> Creature:
	var c := Creature.new()
	c.world = world
	c.camp_id = camp_id
	add_child(c)
	c.setup(type, at, rank)
	actors.append(c)
	c.died.connect(_on_creature_died)
	c.tree_exiting.connect(func(): actors.erase(c))
	return c

func _spawn_camps(ch: Vector2i) -> void:
	if not spawn_encounters:
		return
	var list: Array = []
	for camp in Encounters.camps_for_chunk(world, ch):
		if GameState.cleared_camps.has(camp.id):
			continue
		for k in camp.cells.size():
			list.append(spawn_creature(camp.types[k], camp.cells[k], camp.id, camp.get("rank", 0)))
	camp_creatures[ch] = list

func _despawn_camps(ch: Vector2i) -> void:
	for c in camp_creatures.get(ch, []):
		if is_instance_valid(c) and not c.aggressive():
			c.queue_free()
	camp_creatures.erase(ch)

const KILL_REP := {"cultist": {"church": 2, "hollow": -3}, "risen": {"church": 1}, "revenant": {"church": 1},
	"bandit": {"companies": 1, "church": 1}, "crossbow": {"companies": 1, "church": 1}}

func _on_creature_died(c: Actor) -> void:
	for f in KILL_REP.get(c.type_id, {}):
		GameState.change_rep(f, KILL_REP[c.type_id][f])
	Progression.award(Progression.kill_xp(c.type_id, c.rank))
	var camp: String = c.camp_id
	if camp == "":
		QuestLog.notify_kill(c.type_id, "")
		return
	for other in actors:
		if is_instance_valid(other) and other is Creature and other != c and other.camp_id == camp and other.alive():
			return
	GameState.cleared_camps[camp] = true
	log_msg("The camp falls silent.")
	Progression.award(Progression.camp_xp(c.rank), "camp cleared")
	QuestLog.notify_kill(c.type_id, camp)
	var v := world.village_near(c.cell, 48.0)
	if not v.is_empty():
		log_msg("Word reaches %s." % v.name)
		GameState.change_rep(v.faction, 4)

func _on_enemy_spotted(c: Node) -> void:
	if not in_combat:
		Audio.play("alarm", 0.0)
	if not in_combat and TacticalPause.settings.on_enemy_spotted:
		log_msg("%s spotted!" % c.display_name)
		TacticalPause.set_paused(true)
	in_combat = true
	calm_time = 0.0

func _on_leveled_up(lv: int) -> void:
	Audio.play("quest", 0.0)
	var pending := false
	for m in party.members:
		m.recompute_stats()
		m.floaters.append({"text": "Level %d!" % lv, "color": Color(1.0, 0.85, 0.4), "t": 0.0})
		pending = pending or Talents.pending_tier(m.companion_id, lv) >= 0
	log_msg("The company reaches level %d%s" % [lv, " — talents to choose." if pending else "."])

# ---------------------------------------------------------------- settlements & resources

func _spawn_props(ch: Vector2i) -> void:
	var list: Array = []
	for v in world.villages():
		if terrain.chunk_of(v.center) != ch:
			continue
		pathfinder.ensure_covers(v.center)
		var specials := Story.special_npcs(world)
		for id in specials:
			var sp: Dictionary = specials[id]
			if sp.village != v.id or GameState.recruited.has(id):
				continue
			var npc := Villager.new()
			npc.world = world
			add_child(npc)
			npc.setup_special(v, id, sp)
			list.append(_place_villager(npc))
		var jobs := ["smith", "keeper", "villager", "villager"]
		for i in jobs.size():
			var vil := Villager.new()
			vil.world = world
			add_child(vil)
			vil.setup(v, jobs[i], i)
			list.append(_place_villager(vil))
	var story := Story.setup(world)
	for kind in ["barrow", "chapel", "ashen"]:
		var at: Vector2i = story[kind]
		if terrain.chunk_of(at) == ch:
			var lm := Landmark.new()
			lm.kind = kind
			lm.name = "Landmark_" + kind
			add_child(lm)
			lm.position = world.cell_to_world(at) + Vector3(0, -0.1, 0)
			list.append(lm)
	for d in Gathering.nodes_for_chunk(world, ch):
		var n := GatherNode.new()
		n.data = d
		add_child(n)
		n.position = world.cell_to_world(d.cell)
		gather_nodes.append(n)
		interactables.append(n)
		n.tree_exiting.connect(func(): gather_nodes.erase(n); interactables.erase(n))
		list.append(n)
	chunk_props[ch] = list

func _place_villager(vil: Villager) -> Villager:
	vil.place_at(vil.claim_spot(vil.schedule_target(TimeOfDay.hour())))
	actors.append(vil)
	vil.tree_exiting.connect(func(): actors.erase(vil))
	return vil

func _despawn_props(ch: Vector2i) -> void:
	for n in chunk_props.get(ch, []):
		if is_instance_valid(n):
			n.queue_free()
	chunk_props.erase(ch)

## Crafting stations available right now.
func stations() -> Array:
	var out: Array = []
	if not in_combat:
		out.append("camp")
	for v in world.villages():
		var forge := Settlements.door_cell(v, "forge")
		if party.members.any(func(m): return m.alive() and m.cell_distance(forge) <= 4.0):
			out.append("forge")
			break
	return out

# ---------------------------------------------------------------- story

func _on_story_effect(effect: String) -> void:
	var p := effect.split(":")
	match p[0]:
		"recruit":
			var id := p[1]
			if GameState.recruited.has(id):
				return
			var at := party.leader().cell
			for a in actors.duplicate():
				if is_instance_valid(a) and a is Villager and a.npc_id == id:
					at = a.cell
					a.queue_free()
			GameState.recruited.append(id)
			var m := add_member(id, party.free_near(at, {}))
			log_msg("%s joins the company." % m.display_name)
			QuestLog.start("cq_" + id)
		"spawn":
			if p[1] == "barrow":
				_spawn_barrow()
			else:
				_spawn_boss(p[1])
		"stat":
			GameState.add_bonus(p[1], p[2], float(p[3]))
			for m in party.members:
				if m.companion_id == p[1]:
					m.base_stats[p[2]] = float(m.base_stats.get(p[2], 0.0)) + float(p[3])
					m.recompute_stats()
			log_msg("%s grows stronger (%s %+d)." % [Companions.DEFS[p[1]].name, p[2].replace("max_", "").to_upper(), int(p[3])])
		"note":
			panels.show_note(effect.substr(5))

## Story fights are pitched at a party level: the barrow around 4, the Ashen Knight around 7.
const BOSS_RANK := {"barrow": 1, "ashen": 2}

func _spawn_boss(site: String) -> void:
	var at: Vector2i = Story.setup(world)[site]
	var camp := "story:" + site
	for a in actors:
		if is_instance_valid(a) and a is Creature and a.camp_id == camp and a.alive():
			return
	pathfinder.ensure_covers(at)
	if site == "ashen":
		spawn_creature("ash_knight", party.free_near(at + Vector2i(0, 3), {}), camp, BOSS_RANK.ashen)
		spawn_creature("ghoul", party.free_near(at + Vector2i(2, 4), {}), camp, BOSS_RANK.ashen)
		log_msg("A figure in blackened plate rises from the ashes of the tower.")

func _spawn_barrow() -> void:
	var at: Vector2i = Story.setup(world).barrow
	for a in actors:
		if is_instance_valid(a) and a is Creature and a.camp_id == "story:barrow" and a.alive():
			return
	pathfinder.ensure_covers(at)
	spawn_creature("barrow_lord", party.free_near(at + Vector2i(0, 2), {}), "story:barrow", BOSS_RANK.barrow)
	for off in [Vector2i(2, 3), Vector2i(-2, 3)]:
		spawn_creature("risen", party.free_near(at + off, {}), "story:barrow", BOSS_RANK.barrow)
	log_msg("The barrow stones grind aside. Something drowned climbs out.")

# ---------------------------------------------------------------- save / load

func party_state() -> Array:
	var out: Array = []
	for m in party.members:
		out.append({"name": m.display_name, "cell": [m.cell.x, m.cell.y], "hp": m.hp, "stamina": m.stamina,
			"downed": m.downed, "equipment": m.equipment.duplicate()})
	return out

func apply_party_state(list: Array) -> void:
	for d in list:
		for m in party.members:
			if m.display_name != d.name:
				continue
			m.equipment = {"weapon": String(d.equipment.get("weapon", "")), "armor": String(d.equipment.get("armor", ""))}
			m.recompute_stats()
			m._attach_weapon()
			m.hp = float(d.hp)
			m.stamina = float(d.stamina)
			m.downed = bool(d.downed)
			m.orders.clear()
			m.current = null
			m.place_at(Vector2i(int(d.cell[0]), int(d.cell[1])))
			if m.downed:
				m.body.play("die", true)
	pathfinder.ensure_covers(party.members[0].cell)
	terrain.focus_cell = party.members[0].cell
	if cam:
		cam.position = party.members[0].position

func save_game() -> bool:
	if in_combat:
		log_msg("You can't save with enemies nearby.")
		return false
	var ok := GameState.write_save(GameState.to_dict(party_state()))
	log_msg("Game saved (day %d, %s)." % [TimeOfDay.day, TimeOfDay.clock_text()] if ok else "Saving failed.")
	return ok

func load_game() -> void:
	var data := GameState.read_save()
	if data.is_empty():
		log_msg("No saved game yet (F5 saves).")
		return
	GameState.pending_load = data
	TacticalPause.set_paused(false)
	get_tree().change_scene_to_file("res://main.tscn")

func apply_graphics() -> void:
	Settings.apply_graphics(env.environment, sun, get_viewport())

# ---------------------------------------------------------------- loop

func _process(delta: float) -> void:
	var lead := party.leader()
	terrain.focus_cell = world.world_to_cell(cam.position)
	pathfinder.ensure_covers(lead.cell)
	_update_sun()
	_update_prop_fade()
	if TacticalPause.paused:
		return
	_update_combat_state(delta)
	Audio.set_music("combat" if in_combat else ("day" if TimeOfDay.daylight() > 0.35 else "night"))
	_quest_timer -= delta
	if _quest_timer <= 0.0:
		_quest_timer = 0.5
		QuestLog.notify_positions(party.members.filter(func(m): return m.alive()).map(func(m): return m.cell))

func _update_combat_state(delta: float) -> void:
	var fighting := false
	for a in actors:
		if is_instance_valid(a) and a is Creature and a.alive() and a.aggressive():
			fighting = true
			break
	in_combat = fighting
	calm_time = 0.0 if fighting else calm_time + delta
	var up := 0
	for m in party.members:
		if m.alive():
			up += 1
			if not fighting:
				m.hp = minf(m.max_hp, m.hp + OUT_OF_COMBAT_REGEN * delta)
			if m.hp < m.max_hp * 0.25:
				if not _low_hp_warned.get(m, false) and TacticalPause.settings.on_low_health and fighting:
					_low_hp_warned[m] = true
					log_msg("%s is badly hurt!" % m.display_name)
					TacticalPause.set_paused(true)
			else:
				_low_hp_warned[m] = false
	if up == 0:
		if _defeat_timer < 0.0:
			_defeat_timer = 2.5
			log_msg("The company has fallen. They wake, bloodied, back at camp.")
		_defeat_timer -= delta
		if _defeat_timer <= 0.0:
			_defeat_timer = -1.0
			_regroup_at_spawn()
		return
	if calm_time > REVIVE_DELAY:
		for m in party.members:
			if m.downed:
				m.revive(0.25)
				log_msg("%s staggers back to their feet." % m.display_name)

func _regroup_at_spawn() -> void:
	var spawn := world.spawn_cell()
	pathfinder.ensure_covers(spawn)
	for i in party.members.size():
		var m: PartyMember = party.members[i]
		m.revive(0.5)
		m.place_at(party.free_near(spawn + PartyController.FORMATION[i], {}))
	cam.follow = party.members[0]

func _update_prop_fade() -> void:
	var pos := PackedVector3Array()
	for m in party.members:
		if pos.size() < 4:
			pos.append(m.global_position)
	while pos.size() < 4:
		pos.append(Vector3(0, -1000, 0))
	terrain.prop_material.set_shader_parameter("members", pos)
	terrain.prop_material.set_shader_parameter("member_count", party.members.size())

## Sun angle and colour from the clock; moonlight at night.
func _update_sun() -> void:
	var t := TimeOfDay.time
	var day := TimeOfDay.daylight()
	var elev := sin((t - 0.25) * TAU)          # -1 midnight .. 1 noon
	sun.rotation = Vector3(-deg_to_rad(lerpf(20.0, 70.0, clampf(elev, 0.0, 1.0))), deg_to_rad(t * 360.0 + 30.0), 0)
	sun.light_color = Color(1.0, 0.9, 0.78).lerp(Color(0.55, 0.62, 0.85), 1.0 - day)
	sun.light_energy = lerpf(0.15, 1.05, day)
	var sky := Color(0.5, 0.56, 0.6).lerp(Color(0.04, 0.05, 0.08), 1.0 - day)
	env.environment.background_color = sky
	env.environment.fog_light_color = sky
	env.environment.ambient_light_color = Color(0.55, 0.55, 0.6).lerp(Color(0.12, 0.14, 0.22), 1.0 - day)
	env.environment.ambient_light_energy = lerpf(0.3, 0.45, day)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_I: panels.toggle_pack()
			KEY_J: panels.open_quests()
			KEY_F5: save_game()
			KEY_F9: load_game()
