extends Node2D
## Builds the world scene in code: streamed terrain, y-sorted actors, party, camera, HUD.

const PARTY := [
	{"name": "Maren Vey", "role": "Deserter scout", "speed": 160.0, "look": {
		"skin": Color("e0b894"), "hair": Color("7a2e22"), "hair_long": true, "coat": Color("3b2e2a"),
		"body": Color("5c3a2c"), "trim": Color("b08a4a"), "legs": Color("2a2422"), "slim": true, "hood": false}},
	{"name": "Brother Oswin", "role": "Penitent", "speed": 135.0, "look": {
		"skin": Color("c89e7c"), "hair": Color("4a4038"), "coat": Color("4a4a52"), "body": Color("6a6a70"),
		"trim": Color("9a8a60"), "legs": Color("2e2e34"), "hood": true}},
	{"name": "Ketta", "role": "Poacher", "speed": 155.0, "look": {
		"skin": Color("b98a66"), "hair": Color("2a2018"), "coat": Color("3a4630"), "body": Color("4f5a3a"),
		"trim": Color("7a6a42"), "legs": Color("2a2a22"), "slim": true}},
]

var world: WorldGen
var streamer: ChunkStreamer
var ground: TileMapLayer
var trees: TileMapLayer
var actors: Node2D
var party: PartyController
var pathfinder: Pathfinder
var camera: Camera2D
var shade: CanvasModulate
var hud: Hud

func _ready() -> void:
	if GameState.world == null:
		GameState.new_world(GameState.world_seed)
	world = GameState.world

	ground = TileMapLayer.new()
	ground.name = "Ground"
	add_child(ground)
	# Trees and actors share one y-sorted parent so people walk behind trunks.
	actors = Node2D.new()
	actors.name = "YSorted"
	actors.y_sort_enabled = true
	add_child(actors)
	trees = TileMapLayer.new()
	trees.name = "Trees"
	trees.y_sort_enabled = true
	actors.add_child(trees)

	streamer = ChunkStreamer.new()
	streamer.name = "Streamer"
	add_child(streamer)
	streamer.setup(world, ground, trees)

	pathfinder = Pathfinder.new(world)
	party = PartyController.new()
	party.name = "Party"
	party.z_index = 10
	party.map_layer = ground
	party.pathfinder = pathfinder
	party.world = world
	add_child(party)

	var spawn := world.spawn_cell()
	for i in PARTY.size():
		var d: Dictionary = PARTY[i]
		var m := PartyMember.new()
		m.display_name = d.name
		m.role = d.role
		m.speed = d.speed
		m.look.merge(d.look, true)
		m.map_layer = ground
		m.world = world
		actors.add_child(m)
		m.place_at(party._free_near(spawn + PartyController.FORMATION[i], {}))
		party.members.append(m)
	party.select([party.members[0]])

	streamer.focus_cell = spawn
	streamer.load_all_now()
	pathfinder.ensure_covers(spawn)

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

func _process(delta: float) -> void:
	var lead := party.leader()
	camera.position = lead.position if not _panning() else camera.position + _pan_vector() * 600.0 * delta / camera.zoom.x
	streamer.focus_cell = ground.local_to_map(camera.position)
	pathfinder.ensure_covers(lead.cell)
	shade.color = TimeOfDay.tint()

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
