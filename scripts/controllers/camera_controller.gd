class_name CameraController extends Node

var main: Node3D
var isometric_view: bool = true
var camera_locked: bool = true

# Perspective settings (Sega view)
var persp_offset: Vector3 = Vector3(-8.0, 6.0, 0.0)
var persp_pitch: float = deg_to_rad(-45.0)

# Orthogonal settings (Original Isometric view)
var iso_offset: Vector3 = Vector3(-10.0, 10.0, 10.0)
var iso_rotation: Vector3 = Vector3(deg_to_rad(-45.0), deg_to_rad(-45.0), 0)

var current_focus: Vector3 = Vector3.ZERO

func setup(main_node: Node3D) -> void:
	main = main_node
	if is_instance_valid(main.player):
		current_focus = main.player.global_position
	_apply_camera_state()

func _apply_camera_state() -> void:
	if isometric_view:
		main.camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		main.camera.size = 20.0
		main.camera.rotation = iso_rotation
	else:
		main.camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		main.camera.fov = 75.0
		main.camera.rotation = Vector3(persp_pitch, deg_to_rad(-90.0), 0)

func handle_camera_movement(delta: float) -> void:
	# Space toggles Isometric / Birds-Eye view
	if Input.is_action_just_pressed("ui_accept"): 
		isometric_view = !isometric_view
		_apply_camera_state()
		
	var dir = Vector3.ZERO
	if Input.is_action_pressed("move_up"): dir.z -= 1
	if Input.is_action_pressed("move_down"): dir.z += 1
	if Input.is_action_pressed("move_left"): dir.x -= 1
	if Input.is_action_pressed("move_right"): dir.x += 1
	
	# WASD automatically unlocks from the player
	if dir != Vector3.ZERO:
		camera_locked = false
		var move_vec = dir.rotated(Vector3.UP, main.camera.rotation.y).normalized()
		current_focus += move_vec * main.camera_speed * delta
	elif camera_locked and is_instance_valid(main.player):
		current_focus = current_focus.lerp(main.player.global_position, delta * 5.0)

	# Apply final position based on currently active mode
	var target_cam_pos = current_focus + (iso_offset if isometric_view else persp_offset)
	main.camera.global_position = main.camera.global_position.lerp(target_cam_pos, delta * 15.0)

func handle_zoom(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		if isometric_view:
			main.camera.size = clamp(main.camera.size - main.zoom_step, main.min_zoom, main.max_zoom)
		else:
			persp_offset.y = clamp(persp_offset.y - main.zoom_step, main.min_zoom, main.max_zoom)
			persp_offset.x = clamp(persp_offset.x + main.zoom_step, -main.max_zoom, -main.min_zoom)
			
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		if isometric_view:
			main.camera.size = clamp(main.camera.size + main.zoom_step, main.min_zoom, main.max_zoom)
		else:
			persp_offset.y = clamp(persp_offset.y + main.zoom_step, main.min_zoom, main.max_zoom)
			persp_offset.x = clamp(persp_offset.x - main.zoom_step, -main.max_zoom, -main.min_zoom)
