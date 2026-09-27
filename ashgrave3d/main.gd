extends Node3D
## Ashgrave 3D: the world, the party, the camera and the sun.

var world: WorldGen
var terrain: Terrain
var pathfinder: Pathfinder
var cam: RtsCamera
var party: PartyController
var sun: DirectionalLight3D
var env: WorldEnvironment
var actors: Array = []
var info: Label

func _ready() -> void:
	Actor.ctx = self
	if GameState.world == null:
		GameState.new_world(GameState.world_seed)
	world = GameState.world
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
	pathfinder = Pathfinder.new(world)
	cam = RtsCamera.new()
	cam.world = world
	add_child(cam)
	var ui := CanvasLayer.new()
	add_child(ui)
	party = PartyController.new()
	party.cam = cam
	party.world = world
	party.pathfinder = pathfinder
	ui.add_child(party)
	info = Label.new()
	info.position = Vector2(12, 8)
	info.add_theme_font_size_override("font_size", 20)
	info.add_theme_color_override("font_shadow_color", Color.BLACK)
	ui.add_child(info)
	var spawn := world.spawn_cell()
	terrain.focus_cell = spawn
	terrain.load_all_now()
	pathfinder.ensure_covers(spawn)
	for id in Companions.ORDER:
		if GameState.recruited.has(id):
			add_member(id, party.free_near(spawn + PartyController.FORMATION[party.members.size()], {}))
	party.select([party.members[0]])
	cam.position = party.members[0].position
	cam.follow = party.members[0]
	_update_sun()

func add_member(id: String, at: Vector2i) -> PartyMember:
	var m := PartyMember.new()
	m.world = world
	add_child(m)
	m.setup_member(id)
	m.place_at(at)
	party.members.append(m)
	actors.append(m)
	return m

func _process(_d: float) -> void:
	var lead := party.leader()
	terrain.focus_cell = world.world_to_cell(cam.position)
	pathfinder.ensure_covers(lead.cell)
	_update_sun()
	var pos := PackedVector3Array()
	for m in party.members:
		if pos.size() < 4:
			pos.append(m.global_position)
	while pos.size() < 4:
		pos.append(Vector3(0, -1000, 0))
	terrain.prop_material.set_shader_parameter("members", pos)
	terrain.prop_material.set_shader_parameter("member_count", party.members.size())
	info.text = "%s   %s   Lv %d%s" % [TimeOfDay.clock_text(), WorldGen.NAMES[world.terrain_at(lead.cell)], Progression.level(),
		"   — PAUSED (Space)" if TacticalPause.paused else ""]

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
