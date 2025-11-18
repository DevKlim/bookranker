class_name EnemyUnit
extends CharacterBody2D

signal died

enum State { MOVING, ATTACKING }

@onready var health_component: HealthComponent = $HealthComponent
@onready var attacker_component = $AttackerComponent

var speed: float = 75.0
var lane_id: int = -1
var state: State = State.MOVING

# Pathing data in tile coordinates
var _path: Array[Vector2i] = []
var _current_path_index: int = 0

var _attack_target: Node2D = null

func _ready() -> void:
	# Disable all physics-based collision response; movement is purely logical.
	set_collision_mask(0)
	
	assert(health_component, "Enemy is missing a HealthComponent!")
	assert(attacker_component, "Enemy is missing an AttackerComponent!")
	
	health_component.died.connect(_on_health_depleted)

func initialize(enemy_resource: EnemyResource, start_pos: Vector2, p_lane_id: int) -> void:
	self.speed = enemy_resource.speed
	health_component.set_max_health(enemy_resource.health)
	attacker_component.initialize(
		enemy_resource.attack_damage,
		enemy_resource.attack_speed,
		enemy_resource.attack_element
	)
	
	global_position = start_pos
	lane_id = p_lane_id
	
	_path = LaneManager.get_path_for_lane(lane_id)
	if _path.is_empty():
		printerr("Enemy spawned in lane %d has no path!" % lane_id)
		queue_free()
		return

	_current_path_index = (_path.size() - 1)

func _physics_process(_delta: float) -> void:
	if state == State.ATTACKING:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	if _path.is_empty() or not is_instance_valid(LaneManager.tile_map):
		return

	# --- PATH FOLLOWING LOGIC ---
	
	# 1. Check if we have finished the path.
	if _current_path_index <= 0:
		_on_reached_end()
		return

	# 2. Look ahead for obstacles on the next tile.
	var next_tile = _path[_current_path_index - 1]
	var obstacle = LaneManager.get_buildable_at(next_tile)
	
	if is_instance_valid(obstacle) and obstacle.has_node("HealthComponent"):
		# Obstacle found. Stop at the current tile and attack.
		var current_tile_center = LaneManager.tile_map.map_to_local(_path[_current_path_index])
		if global_position.distance_to(current_tile_center) < 2.0:
			set_attack_target(obstacle)
			state = State.ATTACKING
			attacker_component.start_attacking(_attack_target)
			velocity = Vector2.ZERO
		else:
			# Move to the center of the current tile before attacking.
			velocity = global_position.direction_to(current_tile_center) * speed
	else:
		# 3. No obstacle, so move to the center of the next tile in the path.
		var target_position = LaneManager.tile_map.map_to_local(next_tile)
		if global_position.distance_to(target_position) < 2.0:
			# Arrived at the next tile, advance the path index.
			_current_path_index -= 1
			# Recalculate velocity towards the new next tile to prevent stopping for a frame.
			if _current_path_index < 0:
				var new_target_pos = LaneManager.tile_map.map_to_local(_path[_current_path_index+1])
				velocity = global_position.direction_to(new_target_pos) * speed
			else:
				velocity = Vector2.ZERO
		else:
			velocity = global_position.direction_to(target_position) * speed

	move_and_slide()
	
func set_attack_target(new_target: Node2D):
	# Disconnect from the previous target's 'died' signal if it exists.
	if is_instance_valid(_attack_target) and _attack_target.has_node("HealthComponent"):
		var hc = _attack_target.get_node("HealthComponent")
		if hc.is_connected("died", _on_target_died):
			hc.died.disconnect(_on_target_died)
			
	_attack_target = new_target
	
	# Connect to the new target's 'died' signal so we know when to resume moving.
	if is_instance_valid(_attack_target):
		_attack_target.get_node("HealthComponent").died.connect(_on_target_died, CONNECT_ONE_SHOT)

func _on_target_died(_node_that_died):
	attacker_component.stop_attacking()
	set_attack_target(null)
	state = State.MOVING

func _on_reached_end():
	# Attack the core directly when the end of the path is reached.
	var core = get_tree().current_scene.get_node_or_null("Core")
	if is_instance_valid(core) and core.has_node("HealthComponent"):
		set_attack_target(core)
		state = State.ATTACKING
		attacker_component.start_attacking(_attack_target)
	else: # If core is already destroyed or invalid, just despawn.
		emit_signal("died")
		queue_free()

func _on_health_depleted(_node):
	emit_signal("died")
	queue_free()

func get_lane_id() -> int:
	return lane_id
