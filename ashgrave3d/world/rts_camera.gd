class_name RtsCamera
extends Node3D
## Isometric-style camera: a pivot on the ground, the camera pulled back and up at a fixed pitch.
## Wheel zooms, middle-drag (or Z/C) rotates, WASD / screen edges pan; follows a target when set.

const PITCH := -52.0
const MIN_DIST := 7.0
const MAX_DIST := 42.0
const PAN_SPEED := 24.0

var camera: Camera3D
var world: WorldGen
var distance := 17.0
var yaw := 45.0
var follow: Node3D
var _rotating := false

func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = 38.0
	camera.far = 400.0
	add_child(camera)
	_place()

## Flat direction from the ground toward the camera (idle folk turn this way to show their faces).
func facing() -> Vector3:
	return Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(0, 0, 1)

func _place() -> void:
	rotation_degrees = Vector3(0, yaw, 0)
	var pitch := deg_to_rad(PITCH)
	camera.position = Vector3(0, -sin(pitch) * distance, cos(pitch) * distance)
	camera.rotation = Vector3(pitch, 0, 0)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance = maxf(MIN_DIST, distance * 0.9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance = minf(MAX_DIST, distance * 1.1)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_MIDDLE:
		_rotating = event.pressed
	if event is InputEventMouseMotion and _rotating:
		yaw -= event.relative.x * 0.3
	_place()

func pan_input() -> Vector2:
	var v := Vector2(
		float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W)))
	return v

func _process(delta: float) -> void:
	var turn := float(Input.is_key_pressed(KEY_C)) - float(Input.is_key_pressed(KEY_Z))
	if turn != 0.0:
		yaw += turn * 90.0 * delta
		_place()
	var pan := pan_input()
	if pan != Vector2.ZERO:
		follow = null
		var fwd := -global_transform.basis.z
		var right := global_transform.basis.x
		position += (right * pan.x + fwd * -pan.y).normalized() * PAN_SPEED * delta * distance / 17.0
	elif follow and is_instance_valid(follow):
		position = position.lerp(follow.global_position, clampf(delta * 6.0, 0.0, 1.0))
	if world:
		position.y = lerpf(position.y, world.ground_y(position), clampf(delta * 4.0, 0.0, 1.0))

## The ground point under a screen position (ray-marched against the height field).
func ground_point(screen: Vector2) -> Variant:
	var from := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	var t := 0.0
	var prev := from
	for i in 400:
		t += 0.5
		var p := from + dir * t
		if p.y <= world.ground_y(p):
			# refine between prev and p
			var a := prev
			var b := p
			for k in 8:
				var m := (a + b) / 2.0
				if m.y <= world.ground_y(m):
					b = m
				else:
					a = m
			return b
		prev = p
	return null
