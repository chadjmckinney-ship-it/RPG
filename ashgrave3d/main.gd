extends Node3D
## Ashgrave 3D: the world, the party, the camera, the sun, camps and combat bookkeeping.

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
var actors: Array = []
var combat_log := CombatLog.new()
var camp_creatures := {}        # chunk -> [Creature]
var in_combat := false
var calm_time := 0.0
var _low_hp_warned := {}
var _defeat_timer := -1.0

func _ready() -> void:
	Actor.ctx = self
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
	var spawn := world.spawn_cell()
	pathfinder.ensure_covers(spawn)
	for id in Companions.ORDER:
		if GameState.recruited.has(id):
			add_member(id, party.free_near(spawn + PartyController.FORMATION[party.members.size()], {}))
	party.select([party.members[0]])
	cam.position = party.members[0].position
	cam.follow = party.members[0]
	terrain.focus_cell = spawn
	terrain.load_all_now()
	Events.leveled_up.connect(_on_leveled_up)
	_update_sun()
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
