class_name MoveComponent
extends Node

## A component that handles movement for a CharacterBody3D parent using pathfinding.

@export var move_speed: float = 5.0
@export var stop_distance: float = 0.05 # Tight stop distance for centering

# Added to support entities (Enemy/Player) that set this directly for manual movement control
var target_position: Vector3 = Vector3.ZERO

var path: Array[Vector3] =[]
var current_path_index: int = 0
var is_moving: bool = false

var _body: CharacterBody3D

func _ready() -> void:
	_body = get_parent()
	assert(_body is CharacterBody3D, "MoveComponent must be a child of a CharacterBody3D.")
	target_position = _body.global_position

func move_to(target_pos: Vector3) -> void:
	target_position = target_pos # Sync target_position
	
	# Calculate path using LaneManager
	var is_ally = _body.is_in_group("allies") or _body.is_in_group("player")
	path = LaneManager.get_path_world(_body.global_position, target_pos, is_ally)
	current_path_index = 0
	
	# If start node is the same as first path point, skip it
	if not path.is_empty():
		var dist = _body.global_position.distance_to(path[0])
		if dist < stop_distance:
			current_path_index = 1
	
	if path.is_empty():
		is_moving = false
	else:
		is_moving = true

func stop_moving() -> void:
	path.clear()
	is_moving = false
	_body.velocity.x = 0
	_body.velocity.z = 0
	_body.velocity.y = 0

func _physics_process(delta: float) -> void:
	# 1. Base X/Z Movement
	if not is_moving or path.is_empty():
		_body.velocity.x = move_toward(_body.velocity.x, 0.0, move_speed)
		_body.velocity.z = move_toward(_body.velocity.z, 0.0, move_speed)
		_body.velocity.y = 0
		_body.move_and_slide()
	else:
		if current_path_index >= path.size():
			stop_moving()
		else:
			var target = path[current_path_index]
			# Ignore Y for planar movement checks
			var pos_flat = Vector3(_body.global_position.x, 0, _body.global_position.z)
			var target_flat = Vector3(target.x, 0, target.z)
			
			var dist = pos_flat.distance_to(target_flat)
			
			if dist < stop_distance:
				current_path_index += 1
			else:
				var direction = (_body.global_position.direction_to(target)).normalized()
				direction.y = 0 
				
				if direction.length_squared() > 0.01:
					direction = direction.normalized()
					_body.velocity.x = direction.x * move_speed
					_body.velocity.z = direction.z * move_speed
					_body.velocity.y = 0
					
					# Look at
					var look_target = _body.global_position + direction
					look_target.y = _body.global_position.y
					_body.look_at(look_target, Vector3.UP)
				else:
					_body.velocity = Vector3.ZERO
					
				_body.move_and_slide()

	# 2. Smart Floor Snap (The New Method)
	# Since the game takes place on a flat grid, we can just smoothly clamp the entity 
	# to the ground coordinate (y=1.0) rather than relying on physics gravity. 
	# This guarantees no clipping through the floor and prevents infinite falling into the void.
	if not is_equal_approx(_body.global_position.y, 1.0):
		_body.global_position.y = lerp(_body.global_position.y, 1.0, 15.0 * delta)
