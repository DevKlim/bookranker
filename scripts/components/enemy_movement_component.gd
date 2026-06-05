class_name EnemyMovementComponent
extends Node

## Controller component that decouples grid movement handling from the enemy's main state machine.

var body: CharacterBody3D
var step_cooldown: float = 0.0
var current_target: Vector3 = Vector3.ZERO
var has_target: bool = false

var displacement_stun_timer: float = 0.0
var is_recentering: bool = false
var recenter_target: Vector3 = Vector3.ZERO
var forced_velocity: Vector3 = Vector3.ZERO

func _ready() -> void:
	body = get_parent() as CharacterBody3D

func apply_displacement(impulse: Vector3) -> void:
	displacement_stun_timer = 0.3
	is_recentering = false
	forced_velocity = impulse * 0.05
	has_target = false

func get_movement_velocity(delta: float, path_queue: Array[Vector3], is_field: bool, base_speed: float, lane_id: int, res: EnemyResource) -> Vector3:
	# Hard stop if speed calculation explicitly yields exactly or sub zero
	if base_speed <= 0.0:
		has_target = false
		return Vector3.ZERO

	if displacement_stun_timer > 0.0:
		displacement_stun_timer -= delta
		if displacement_stun_timer <= 0.0:
			is_recentering = true
			var tile = LaneManager.world_to_tile(body.global_position)
			recenter_target = LaneManager.tile_to_world(tile)
			recenter_target.y = body.global_position.y
		forced_velocity = forced_velocity.lerp(Vector3.ZERO, delta * 5.0)
		return forced_velocity

	if is_recentering:
		var target_flat = Vector3(recenter_target.x, 0, recenter_target.z)
		var my_flat = Vector3(body.global_position.x, 0, body.global_position.z)
		var dist = my_flat.distance_to(target_flat)
		
		if dist <= base_speed * delta or dist < 0.05:
			body.global_position.x = recenter_target.x
			body.global_position.z = recenter_target.z
			is_recentering = false
			return Vector3.ZERO
		
		var dir = (target_flat - my_flat).normalized()
		if dir.length_squared() > 0.01:
			var look_target = body.global_position + dir
			body.look_at(Vector3(look_target.x, body.global_position.y, look_target.z), Vector3.UP)
		
		return dir * base_speed

	var current_tile = LaneManager.world_to_tile(body.global_position)
	var speed_multiplier = 1.0
	var wire = LaneManager.get_entity_at(current_tile, "wire")
	
	if is_instance_valid(wire):
		var wire_name = wire.get("display_name")
		if wire_name == "Slipstream":
			speed_multiplier = 2.0
			if Engine.get_frames_drawn() % 30 == 0:
				var aqua = ElementManager.get_element("aqua")
				if aqua: ElementManager.apply_element(body, aqua, wire, 0.0, 1)
		elif wire_name == "Tarstream":
			speed_multiplier = 0.5
			if Engine.get_frames_drawn() % 30 == 0:
				var dark = ElementManager.get_element("dark")
				if dark: ElementManager.apply_element(body, dark, wire, 0.0, 1)

	var speed = max(0.01, base_speed * speed_multiplier)
	var is_block_mode = is_field or (res and res.wave_movement == EnemyResource.WaveMovement.BLOCK_BY_BLOCK)

	if is_block_mode and step_cooldown > 0:
		step_cooldown -= delta
		if step_cooldown <= 0 and not has_target:
			_advance_path(path_queue, is_field, lane_id)
		return Vector3.ZERO
		
	if not has_target:
		_advance_path(path_queue, is_field, lane_id)
		if not has_target:
			if not is_field and res and res.wave_movement == EnemyResource.WaveMovement.CONTINUOUS:
				return _continuous_wave_move(lane_id, speed)
			return Vector3.ZERO

	var target_flat = Vector3(current_target.x, 0, current_target.z)
	var my_flat = Vector3(body.global_position.x, 0, body.global_position.z)
	var dist = my_flat.distance_to(target_flat)

	var physical_speed = speed
	if is_block_mode:
		physical_speed = speed * 2.5 

	if dist <= physical_speed * delta or dist < 0.05:
		body.global_position.x = current_target.x
		body.global_position.z = current_target.z
		has_target = false
		
		if is_block_mode:
			var slide_time = 1.0 / physical_speed
			var total_time = 1.0 / speed
			step_cooldown = max(0.01, total_time - slide_time)
			
		_trigger_tile_arrival(res)
		return Vector3.ZERO

	var dir = (target_flat - my_flat).normalized()
	
	if dir.length_squared() > 0.01:
		var look_target = body.global_position + dir
		body.look_at(Vector3(look_target.x, body.global_position.y, look_target.z), Vector3.UP)

	return dir * physical_speed

func _trigger_tile_arrival(res: EnemyResource) -> void:
	if not res: return
	
	if "wipes_liquids" in res.tags:
		var tile = LaneManager.world_to_tile(body.global_position)
		var wire = LaneManager.get_entity_at(tile, "wire")
		if is_instance_valid(wire) and wire is Node3D:
			if wire.get("display_name") == "Slipstream" or wire.get("display_name") == "Tarstream":
				wire.queue_free()

func _advance_path(path_queue: Array[Vector3], is_field: bool, lane_id: int) -> void:
	if not path_queue.is_empty():
		var next_point = path_queue.pop_front()
		next_point.y = body.global_position.y
		current_target = next_point
		has_target = true
		return
		
	if not is_field:
		var current_tile = LaneManager.world_to_tile(body.global_position)
		var next_tile = Vector2i(current_tile.x - 1, lane_id)
		var next_point = LaneManager.tile_to_world(next_tile)
		next_point.y = body.global_position.y
		current_target = next_point
		has_target = true
	else:
		has_target = false

func _continuous_wave_move(lane_id: int, speed: float) -> Vector3:
	var target_z = LaneManager.tile_to_world(Vector2i(0, lane_id)).z
	var dir = Vector3(-1, 0, 0)
	
	var z_diff = target_z - body.global_position.z
	if abs(z_diff) > 0.05:
		dir.z = sign(z_diff) * 1.5 
		dir = dir.normalized()
		
	var look_target = body.global_position + Vector3(-1, 0, 0)
	body.look_at(Vector3(look_target.x, body.global_position.y, look_target.z), Vector3.UP)
	
	return dir * speed

func reset_target() -> void:
	has_target = false
	step_cooldown = 0.0
