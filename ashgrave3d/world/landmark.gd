class_name Landmark
extends Node3D
## Story locations as stand-in shapes: the Drowned Barrow (a mound ringed by standing stones),
## the Chapel of Ash (a roofless ruin) and the burnt watchtower (with drifting embers).
## Drop a characters-style .glb at res://landmarks/<kind>.glb to replace one.

var kind := "barrow"

func _ready() -> void:
	var path := "res://landmarks/%s.glb" % kind
	if ResourceLoader.exists(path):
		add_child((load(path) as PackedScene).instantiate())
		return
	match kind:
		"barrow": _barrow()
		"chapel": _chapel()
		"ashen": _tower()

func _barrow() -> void:
	Shapes.add(self, Shapes.sphere(3.2, 16), Vector3(0, -0.6, -2.5), Color("4a5040"), Vector3(1.2, 0.5, 1.0))
	# the grave-mouth, flanked by two stones and a lintel
	Shapes.add(self, Shapes.box(Vector3(1.4, 1.2, 0.6)), Vector3(0, 0.4, 0.6), Color("141614"))
	Shapes.add(self, Shapes.box(Vector3(0.45, 1.8, 0.45)), Vector3(-0.95, 0.8, 0.8), Color("6a6860"))
	Shapes.add(self, Shapes.box(Vector3(0.45, 1.8, 0.45)), Vector3(0.95, 0.8, 0.8), Color("6a6860"))
	Shapes.add(self, Shapes.box(Vector3(2.5, 0.4, 0.55)), Vector3(0, 1.85, 0.8), Color("5e5c56"))
	for i in 7:
		var a := PI * 0.15 + i * PI * 0.7 / 6.0
		var h := 1.2 + 0.5 * sin(i * 1.7)
		Shapes.add(self, Shapes.box(Vector3(0.4, h, 0.3)), Vector3(cos(a) * 5.0, h / 2.0 - 0.1, sin(a) * 5.0 - 2.5), Color("5a5850"), Vector3.ONE, Vector3(0.1 * sin(i), a, 0.08 * cos(i)))

func _chapel() -> void:
	var stone := Color("7a746a")
	# nave walls, broken at uneven heights; no roof
	for side in [-1.0, 1.0]:
		for k in 4:
			var h: float = [3.0, 2.2, 3.4, 1.4][k] if side < 0 else [2.6, 3.2, 1.8, 2.8][k]
			Shapes.add(self, Shapes.box(Vector3(0.4, h, 1.6)), Vector3(side * 2.2, h / 2.0, -k * 1.6), stone)
	Shapes.add(self, Shapes.box(Vector3(4.8, 3.6, 0.4)), Vector3(0, 1.8, -6.2), stone)
	# gable front with a doorway gap
	Shapes.add(self, Shapes.box(Vector3(1.4, 3.2, 0.4)), Vector3(-1.6, 1.6, 1.0), stone)
	Shapes.add(self, Shapes.box(Vector3(1.4, 3.2, 0.4)), Vector3(1.6, 1.6, 1.0), stone)
	Shapes.add(self, Shapes.prism(Vector3(4.8, 1.6, 0.4)), Vector3(0, 4.0, 1.0), stone)
	# bell tower stump at the back
	Shapes.add(self, Shapes.box(Vector3(1.6, 5.5, 1.6)), Vector3(0, 2.75, -7.6), Color("6e6860"))
	Shapes.add(self, Shapes.box(Vector3(0.9, 0.2, 0.3)), Vector3(0, 0.1, -3.0), Color("3a3430"))   # fallen beam
	Shapes.add(self, Shapes.box(Vector3(1.2, 0.9, 0.6)), Vector3(0, 0.45, -5.4), Color("8a8478"))  # altar

func _tower() -> void:
	Shapes.add(self, Shapes.cyl(1.5, 1.9, 5.5, 10), Vector3(0, 2.75, 0), Color("2e2a28"))
	# a jagged, burnt-off crown
	for i in 8:
		var a := TAU * i / 8.0
		var h := 0.5 + 0.6 * absf(sin(i * 2.3))
		Shapes.add(self, Shapes.box(Vector3(0.55, h, 0.4)), Vector3(cos(a) * 1.35, 5.5 + h / 2.0, sin(a) * 1.35), Color("1e1b1a"), Vector3.ONE, Vector3(0, -a, 0))
	Shapes.add(self, Shapes.box(Vector3(0.9, 1.8, 0.3)), Vector3(0, 0.9, 1.8), Color("0c0a0a"))            # doorway
	for p in [Vector3(2.4, 0.2, 1.0), Vector3(-2.0, 0.15, 1.6), Vector3(1.0, 0.1, -2.4)]:
		Shapes.add(self, Shapes.box(Vector3(0.8, 0.3, 0.6)), p, Color("262220"), Vector3.ONE, Vector3(0, p.x, 0.2))
	var embers := CPUParticles3D.new()
	embers.amount = 24
	embers.lifetime = 3.0
	embers.position = Vector3(0, 5.7, 0)
	embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	embers.emission_sphere_radius = 1.2
	embers.direction = Vector3(0.2, 1, 0)
	embers.spread = 25.0
	embers.gravity = Vector3(0.3, 0.6, 0)
	embers.initial_velocity_min = 0.4
	embers.initial_velocity_max = 1.0
	var q := QuadMesh.new()
	q.size = Vector2(0.09, 0.09)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	q.material = m
	embers.mesh = q
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.6, 0.2, 1.0))
	g.set_color(1, Color(1.0, 0.3, 0.1, 0.0))
	embers.color_ramp = g
	add_child(embers)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.45, 0.2)
	glow.light_energy = 1.2
	glow.omni_range = 6.0
	glow.position = Vector3(0, 5.0, 0)
	add_child(glow)
