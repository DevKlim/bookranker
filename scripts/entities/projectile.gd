class_name Projectile
extends Area2D

## The script for a projectile. It handles its own movement and collision logic.

var _velocity: Vector2 = Vector2.ZERO
var _damage: float = 0.0
var _element: ElementResource = null
var lane_id: int = -1
var speed: float = 0.0

# Pathing variables
var current_path_index: int = -1
var path: Array = []

@onready var sprite: Sprite2D = $Sprite2D

func _physics_process(delta: float) -> void:
	if path.is_empty():
		# Fallback to straight line if no path found
		global_position += _velocity * delta
		return

	# Move towards the next point in the path (Index increases towards spawn)
	var target_index = current_path_index + 1
	
	if target_index < path.size():
		var target_tile = path[target_index]
		var target_pos = LaneManager.tile_map.map_to_local(target_tile)
		
		var direction = global_position.direction_to(target_pos)
		var distance = global_position.distance_to(target_pos)
		var move_amount = speed * delta
		
		rotation = direction.angle()
		
		if distance <= move_amount:
			global_position = target_pos
			current_path_index = target_index
		else:
			global_position += direction * move_amount
	else:
		# End of path reached (Spawn point), despawn
		queue_free()

## Initializes the projectile with its starting properties.
func initialize(start_position: Vector2, _direction: Vector2, p_speed: float, damage: float, p_lane_id: int, p_element: ElementResource = null, texture: Texture2D = null, color: Color = Color.WHITE, use_pathing: bool = false) -> void:
	global_position = start_position
	# direction is used for straight movement if path is invalid (p_lane_id = -1)
	speed = p_speed
	_velocity = _direction * speed
	rotation = _direction.angle()
	
	_damage = damage
	lane_id = p_lane_id
	_element = p_element
	
	if texture:
		sprite.texture = texture
	
	if _element:
		sprite.self_modulate = _element.color
	else:
		sprite.self_modulate = color
	
	if use_pathing:
		_initialize_path_tracking()
	
	body_entered.connect(_on_body_entered)

func _initialize_path_tracking() -> void:
	if LaneManager.lane_paths.has(lane_id):
		path = LaneManager.lane_paths[lane_id]
		# Find the closest tile index to start from
		var tile = LaneManager.tile_map.local_to_map(global_position)
		# We look for the index in the path
		current_path_index = path.find(tile)
		
		# If exact match not found (e.g. turret offset), find closest by distance
		if current_path_index == -1:
			var min_dist = INF
			for i in range(path.size()):
				var world_pos = LaneManager.tile_map.map_to_local(path[i])
				var dist = global_position.distance_squared_to(world_pos)
				if dist < min_dist:
					min_dist = dist
					current_path_index = i

func _on_body_entered(body: Node2D) -> void:
	# Debug collision
	print("Projectile collided with: ", body.name)

	# If shooting straight (lane_id == -1), we hit any enemy regardless of lane
	# Otherwise, restrict to same lane
	if body is EnemyUnit:
		var enemy_lane = body.get_lane_id()
		print("Enemy Lane: ", enemy_lane, " | Projectile Filter Lane: ", self.lane_id)
		
		if self.lane_id == -1 or enemy_lane == self.lane_id:
			# FIX: Access HealthComponent explicitly instead of calling take_damage on body
			var health_component = body.get_node_or_null("HealthComponent")
			if health_component:
				health_component.take_damage(_damage)
				print("Enemy hit! Dealt ", _damage, " damage. Remaining Health: ", health_component.current_health)
			else:
				# Fallback if body has method (unlikely with current component structure)
				if body.has_method("take_damage"):
					body.take_damage(_damage)
					print("Enemy hit via body method! Damage: ", _damage)
				else:
					printerr("Projectile hit EnemyUnit but found no HealthComponent!")
			
			if _element:
				ElementManager.apply_element(body, _element)
			
			queue_free()
		else:
			print("Projectile ignored enemy due to lane mismatch.")
