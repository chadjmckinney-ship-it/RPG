extends SceneTree
## Renders a character .glb from a few angles: OUT_DIR=/tmp MODEL=res://characters/maren/maren.glb godot --path . -s res://tests/preview_model.gd
func _initialize():
	await process_frame
	var out := OS.get_environment("OUT_DIR")
	var path := OS.get_environment("MODEL")
	var scene: PackedScene = load(path)
	var root3d := Node3D.new()
	root.add_child(root3d)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.16, 0.15, 0.14)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.55, 0.6)
	root3d.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 35, 0)
	sun.light_energy = 1.3
	root3d.add_child(sun)
	var m: Node3D = scene.instantiate()
	root3d.add_child(m)
	var ap: AnimationPlayer = m.find_child("AnimationPlayer", true, false)
	if ap:
		print("animations: ", ap.get_animation_list())
	var cam := Camera3D.new()
	root3d.add_child(cam)
	cam.fov = 35
	var angles := [0.0, 90.0, 180.0, 45.0]
	for i in angles.size():
		var a := deg_to_rad(angles[i])
		cam.position = Vector3(sin(a) * 4.2, 1.4, cos(a) * 4.2)
		cam.look_at(Vector3(0, 0.9, 0))
		if ap and ap.get_animation_list().size() > 0:
			ap.play(ap.get_animation_list()[0])
			ap.seek(0.25 * i, true)
		for k in 5: await process_frame
		root.get_viewport().get_texture().get_image().save_png(out + "/model_%d.png" % i)
	print("done")
	quit()
