class_name MoveComponent
extends Node

## A component that handles movement for a CharacterBody3D parent using pathfinding.

@export var move_speed: float = 5.0
@export var stop_distance: float = 0.05 # Tight stop distance for centering

# Added to support entities (Enemy/Player) that set this directly for manual movement control
var target_position: Vector3 = Vector3.ZERO

var path: Array[Vector3] = []
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
	path = LaneManager.get_path_world(_body.global_position, target_pos)
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
	_body.velocity = Vector3.ZERO

func _physics_process(_delta: float) -> void:
	if not is_moving or path.is_empty():
		_body.velocity = Vector3.ZERO
		return
	
	if current_path_index >= path.size():
		stop_moving()
		return
		
	var target = path[current_path_index]
	# Ignore Y for planar movement checks
	var pos_flat = Vector3(_body.global_position.x, 0, _body.global_position.z)
	var target_flat = Vector3(target.x, 0, target.z)
	
	var dist = pos_flat.distance_to(target_flat)
	
	if dist < stop_distance:
		current_path_index += 1
		return
	
	var direction = (_body.global_position.direction_to(target)).normalized()
	# Keep Y velocity 0 for top-down, or handle gravity if needed (usually 0 for these units)
	direction.y = 0 
	
	_body.velocity = direction * move_speed
	_body.move_and_slide()
	
	# Look at
	if direction.length_squared() > 0.01:
		var look_target = _body.global_position + direction
		_body.look_at(look_target, Vector3.UP)
