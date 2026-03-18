class_name CameraController extends Node

var main: Node3D
var camera_locked: bool = false
var camera_offset: Vector3 = Vector3(10, 10, 10)

func setup(main_node: Node3D) -> void:
	main = main_node
	if main.camera:
		main.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		main.camera.size = 20.0
		if is_instance_valid(main.core):
			camera_offset = main.camera.global_position - main.core.global_position

func handle_camera_movement(delta: float) -> void:
	if Input.is_action_just_pressed("ui_accept"): camera_locked = !camera_locked
	
	if camera_locked and is_instance_valid(main.player):
		var target = main.player.global_position + camera_offset
		main.camera.global_position = main.camera.global_position.lerp(target, delta * 5.0)
		return
	
	var dir = Vector3.ZERO
	if Input.is_action_pressed("move_up"): dir.z -= 1
	if Input.is_action_pressed("move_down"): dir.z += 1
	if Input.is_action_pressed("move_left"): dir.x -= 1
	if Input.is_action_pressed("move_right"): dir.x += 1
	
	if dir != Vector3.ZERO:
		dir = dir.rotated(Vector3.UP, main.camera.rotation.y).normalized()
		main.camera.position += dir * main.camera_speed * delta

func handle_zoom(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		main.camera.size = clamp(main.camera.size - main.zoom_step, main.min_zoom, main.max_zoom)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		main.camera.size = clamp(main.camera.size + main.zoom_step, main.min_zoom, main.max_zoom)

