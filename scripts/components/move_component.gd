class_name MoveComponent
extends Node

## A component that handles movement for a CharacterBody3D parent using pathfinding.
## Syncs fluidly to dynamic ECS Speed stats ensuring perfectly timed tile-to-tile traversals.

@export var move_speed: float = 5.0
@export var stop_distance: float = 0.05 

var target_position: Vector3 = Vector3.ZERO

var path: Array[Vector3] =[]
var current_path_index: int = 0
var is_moving: bool = false

var _body: CharacterBody3D

func _ready() -> void:
	_body = get_parent()
	assert(_body is CharacterBody3D, "MoveComponent must be a child of a CharacterBody3D.")
	target_position = _body.global_position

func get_dynamic_speed() -> float:
	if _body.has_method("get_stat"):
		return _body.get_stat("speed", move_speed)
	return move_speed

func move_to(target_pos: Vector3) -> void:
	target_position = target_pos 
	
	var is_ally = _body.is_in_group("allies") or _body.is_in_group("player")
	path = LaneManager.get_path_world(_body.global_position, target_pos, is_ally)
	current_path_index = 0
	
	if not path.is_empty():
		var pos_flat = Vector3(_body.global_position.x, 0, _body.global_position.z)
		var target_flat = Vector3(path[0].x, 0, path[0].z)
		var dist = pos_flat.distance_to(target_flat)
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
	var current_speed = get_dynamic_speed()
	
	# 1. Base X/Z Movement
	if not is_moving or path.is_empty():
		_body.velocity.x = move_toward(_body.velocity.x, 0.0, current_speed)
		_body.velocity.z = move_toward(_body.velocity.z, 0.0, current_speed)
		_body.velocity.y = 0
		_body.move_and_slide()
	else:
		if current_path_index >= path.size():
			stop_moving()
		else:
			var target = path[current_path_index]
			var pos_flat = Vector3(_body.global_position.x, 0, _body.global_position.z)
			var target_flat = Vector3(target.x, 0, target.z)
			
			var dist = pos_flat.distance_to(target_flat)
			
			# Parity: Dynamic Speed bounded constraint stops allies from overshooting tile centers
			if dist <= current_speed * delta or dist < stop_distance:
				_body.global_position.x = target.x
				_body.global_position.z = target.z
				current_path_index += 1
			else:
				var direction = (target_flat - pos_flat).normalized()
				
				if direction.length_squared() > 0.01:
					_body.velocity.x = direction.x * current_speed
					_body.velocity.z = direction.z * current_speed
					_body.velocity.y = 0
					
					var look_target = _body.global_position + direction
					look_target.y = _body.global_position.y
					_body.look_at(look_target, Vector3.UP)
				else:
					_body.velocity = Vector3.ZERO
					
				_body.move_and_slide()

	# 2. Smart Floor Snap (Ground Constraints)
	if not is_equal_approx(_body.global_position.y, 1.0):
		_body.global_position.y = lerp(_body.global_position.y, 1.0, 15.0 * delta)
