extends Node
class_name MovementComponent

@export_group("Movement")
@export var walk_speed: float = 250.0
@export var sprint_speed: float = 400.0
@export var air_acceleration: float = 1200.0
@export var jump_velocity: float = -800.0
@export var max_jumps: int = 2

@export_group("Friction")
@export var ground_friction: float = 2000.0
@export var air_friction: float = 300.0

@export_group("Gravity")
@export var weight: float = 1.0 # Multiplier for gravity. Higher is heavier.
@export var gravity: float = 3000.0
@export var jump_release_gravity_multiplier: float = 2.0
@export var fall_gravity_multiplier: float = 1.5
@export var fast_fall_gravity_multiplier: float = 2.5
@export var fast_fall_velocity: float = 200.0
@export var fast_fall_peak_threshold: float = 50.0

@export_group("Timers")
@export var landing_lag_duration: float = 0.15


func get_ground_velocity(current_velocity: Vector2, direction: float, is_sprinting: bool, delta: float) -> Vector2:
	var target_speed = 0.0
	if direction != 0:
		target_speed = sprint_speed if is_sprinting else walk_speed
	
	var new_velocity_x = move_toward(current_velocity.x, direction * target_speed, ground_friction * delta)
	return Vector2(new_velocity_x, current_velocity.y)


func get_air_velocity(current_velocity: Vector2, direction: float, delta: float) -> Vector2:
	var new_velocity_x
	if direction != 0.0:
		new_velocity_x = current_velocity.x + direction * air_acceleration * delta
		new_velocity_x = clamp(new_velocity_x, -sprint_speed, sprint_speed)
	else:
		# Apply air friction when there is no horizontal input
		new_velocity_x = move_toward(current_velocity.x, 0, air_friction * delta)
		
	return Vector2(new_velocity_x, current_velocity.y)


func get_gravity_vector(current_velocity: Vector2, is_jump_held: bool, is_down_pressed: bool, can_fast_fall: bool) -> Vector2:
	var gravity_multiplier = 1.0
	if current_velocity.y > 0: # Falling
		gravity_multiplier = fall_gravity_multiplier
		if is_down_pressed and can_fast_fall:
			gravity_multiplier = fast_fall_gravity_multiplier
	elif current_velocity.y < 0 and not is_jump_held: # Jumping but released button
		gravity_multiplier = jump_release_gravity_multiplier
	
	return Vector2.DOWN * gravity * gravity_multiplier * weight