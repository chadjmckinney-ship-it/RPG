extends Node2D
## Builds the world scene in code: streamed terrain, y-sorted actors, party, creatures, camera, HUD.

const PARTY := [
	{"name": "Maren Vey", "role": "Deserter scout", "abilities": ["quick_shot", "hamstring"],
		"stats": {"max_hp": 72.0, "attack": 12.0, "defense": 5.0, "speed": 160.0, "attack_range": 1.5, "attack_cooldown": 1.0},
		"look": {"skin": Color("e0b894"), "hair": Color("7a2e22"), "hair_long": true, "coat": Color("3b2e2a"),
		"body": Color("5c3a2c"), "trim": Color("b08a4a"), "legs": Color("2a2422"), "slim": true, "hood": false}},
	{"name": "Brother Oswin", "role": "Penitent", "abilities": ["shield_wall", "mending"],
		"stats": {"max_hp": 96.0, "attack": 9.0, "defense": 9.0, "speed": 135.0, "attack_range": 1.5, "attack_cooldown": 1.3},
		"look": {"skin": Color("c89e7c"), "hair": Color("4a4038"), "coat": Color("4a4a52"), "body": Color("6a6a70"),
		"trim": Color("9a8a60"), "legs": Color("2e2e34"), "hood": true}},
	{"name": "Ketta", "role": "Poacher", "abilities": ["snare", "aimed_shot"],
		"stats": {"max_hp": 60.0, "attack": 10.0, "defense": 4.0, "speed": 155.0, "attack_range": 6.0, "attack_cooldown": 1.5, "ranged": true},
		"look": {"skin": Color("b98a66"), "hair": Color("2a2018"), "coat": Color("3a4630"), "body": Color("4f5a3a"),
		"trim": Color("7a6a42"), "legs": Color("2a2a22"), "slim": true}},
]

const OUT_OF_COMBAT_REGEN := 3.0   # hp/s
const REVIVE_DELAY := 4.0          # seconds of calm before downed members get up

var world: WorldGen
var streamer: ChunkStreamer
var ground: TileMapLayer
var trees: TileMapLayer
var ysorted: Node2D
var party: PartyController
var pathfinder: Pathfinder
var camera: Camera2D
var shade: CanvasModulate
var hud: Hud
var fx: Fx
var combat_log := CombatLog.new()
var actors: Array = []            # every live Actor (party + creatures)
var camp_creatures := {}          # chunk -> Array[Creature]
var calm_time := 0.0
var in_combat := false
var _low_hp_warned := {}
var _defeat_timer := -1.0
var spawn_encounters := true     # tests switch this off before adding the scene

func _ready() -> void:
	Actor.ctx = self
	if GameState.world == null:
		GameState.new_world(GameState.world_seed)
	world = GameState.world
	Events.combat_message.connect(combat_log.add)
	Events.enemy_spotted.connect(_on_enemy_spotted)

	ground = TileMapLayer.new()
	ground.name = "Ground"
	add_child(ground)
	# Trees and actors share one y-sorted parent so people walk behind trunks.
	ysorted = Node2D.new()
	ysorted.name = "YSorted"
	ysorted.y_sort_enabled = true
	add_child(ysorted)
	trees = TileMapLayer.new()
	trees.name = "Trees"
	trees.y_sort_enabled = true
	ysorted.add_child(trees)
	streamer = ChunkStreamer.new()
	streamer.name = "Streamer"
	add_child(streamer)
	streamer.chunk_loaded.connect(_spawn_camps)
	streamer.chunk_unloaded.connect(_despawn_camps)
	streamer.setup(world, ground, trees)
	fx = Fx.new()
	fx.z_index = 5
	add_child(fx)

	pathfinder = Pathfinder.new(world)
	party = PartyController.new()
	party.name = "Party"
	party.z_index = 10
	party.map_layer = ground
	party.pathfinder = pathfinder
	party.world = world
	add_child(party)

	var spawn := world.spawn_cell()
	pathfinder.ensure_covers(spawn)
	for i in PARTY.size():
		var d: Dictionary = PARTY[i]
		var m := PartyMember.new()
		m.display_name = d.name
		m.role = d.role
		m.look.merge(d.look, true)
		m.map_layer = ground
		m.world = world
		m.setup_stats(d.stats)
		m.abilities.assign(d.abilities)
		ysorted.add_child(m)
		m.place_at(party._free_near(spawn + PartyController.FORMATION[i], {}))
		party.members.append(m)
		actors.append(m)
	party.select([party.members[0]])

	streamer.focus_cell = spawn
	streamer.load_all_now()

	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	camera.zoom = Vector2(1.5, 1.5)
	add_child(camera)
	camera.position = party.members[0].position

	shade = CanvasModulate.new()
	add_child(shade)

	hud = Hud.new()
	add_child(hud)
	hud.setup(self)
	log_msg("Maren Vey's company makes camp at the edge of the wilds.")

func log_msg(text: String) -> void:
	Events.combat_message.emit(text)

# ---------------------------------------------------------------- creatures

func spawn_creature(type: String, at: Vector2i, camp_id := "") -> Creature:
	var c := Creature.new()
	c.map_layer = ground
	c.world = world
	c.camp_id = camp_id
	c.setup(type, at)
	ysorted.add_child(c)
	actors.append(c)
	c.died.connect(_on_creature_died)
	c.tree_exiting.connect(func(): actors.erase(c))
	return c

func _spawn_camps(ch: Vector2i) -> void:
	var list: Array = []
	if not spawn_encounters:
		return
	for camp in Encounters.camps_for_chunk(world, ch):
		if GameState.cleared_camps.has(camp.id):
			continue
		for cell in camp.cells:
			list.append(spawn_creature(camp.type, cell, camp.id))
	camp_creatures[ch] = list

func _despawn_camps(ch: Vector2i) -> void:
	for c in camp_creatures.get(ch, []):
		if is_instance_valid(c) and not c.aggressive():
			c.queue_free()
	camp_creatures.erase(ch)

func _on_creature_died(c: Actor) -> void:
	var camp: String = c.camp_id
	if camp == "":
		return
	for other in actors:
		if other is Creature and other != c and other.camp_id == camp and other.alive():
			return
	GameState.cleared_camps[camp] = true
	log_msg("The camp falls silent.")

func _on_enemy_spotted(c: Node) -> void:
	if not in_combat and TacticalPause.settings.on_enemy_spotted:
		log_msg("%s spotted!" % c.display_name)
		TacticalPause.set_paused(true)
	in_combat = true
	calm_time = 0.0

# ---------------------------------------------------------------- loop

func _process(delta: float) -> void:
	var lead := party.leader()
	camera.position = lead.position if not _panning() else camera.position + _pan_vector() * 600.0 * delta / camera.zoom.x
	streamer.focus_cell = ground.local_to_map(camera.position)
	pathfinder.ensure_covers(lead.cell)
	shade.color = TimeOfDay.tint()
	if TacticalPause.paused:
		return
	_update_combat_state(delta)

func _update_combat_state(delta: float) -> void:
	var fighting := false
	for a in actors:
		if a is Creature and a.alive() and a.aggressive():
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
		m.revive(1.0)
		m.orders.clear()
		m.current = null
		m.place_at(party._free_near(spawn + PartyController.FORMATION[i], {}))
	camera.position = party.members[0].position

func _panning() -> bool:
	return _pan_vector() != Vector2.ZERO

func _pan_vector() -> Vector2:
	var v := Vector2.ZERO
	if Input.is_key_pressed(KEY_W): v.y -= 1
	if Input.is_key_pressed(KEY_S): v.y += 1
	if Input.is_key_pressed(KEY_A): v.x -= 1
	if Input.is_key_pressed(KEY_D): v.x += 1
	return v

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			camera.zoom = (camera.zoom * 1.1).clamp(Vector2(0.5, 0.5), Vector2(3, 3))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			camera.zoom = (camera.zoom / 1.1).clamp(Vector2(0.5, 0.5), Vector2(3, 3))

func terrain_under_mouse() -> String:
	var c := ground.local_to_map(ground.to_local(get_global_mouse_position()))
	return WorldGen.NAMES[world.terrain_at(c)]
