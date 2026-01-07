class_name EnemyUnit
extends CharacterBody3D

signal died

enum State { MOVING, ATTACKING }

@onready var health_component: HealthComponent = $HealthComponent
@onready var attacker_component = $AttackerComponent

var speed: float = 5.0 # Slower in 3D units typically
var lane_id: int = -1
var state: State = State.MOVING
var drop_table: Array = []

var _path: Array[Vector2i] = []
var _current_path_index: int = 0
var _attack_target: Node3D = null

func _ready() -> void:
	if not self is CharacterBody3D:
		printerr("EnemyUnit script attached to non-CharacterBody3D node: %s" % get_class())
		return
		
	if health_component:
		health_component.died.connect(_on_health_depleted)
	else:
		printerr("EnemyUnit: Missing HealthComponent on %s" % name)

func initialize(enemy_resource: EnemyResource, start_pos: Vector3, p_lane_id: int) -> void:
	# Physics / Movement
	self.speed = enemy_resource.speed * 0.05 # Scale speed for 3D
	
	# Stats
	if health_component:
		health_component.set_max_health(enemy_resource.health)
		health_component.armor = enemy_resource.defense
		if not enemy_resource.elemental_resistances.is_empty():
			health_component.resistances = enemy_resource.elemental_resistances.duplicate()
	
	# Combat
	if attacker_component:
		attacker_component.initialize(enemy_resource.attack_damage, enemy_resource.attack_speed, enemy_resource.attack_element)
	
	# Drops
	drop_table = enemy_resource.drops.duplicate()
	
	# Pos
	global_position = start_pos
	lane_id = p_lane_id
	
	if lane_id != -1:
		_path = LaneManager.get_path_for_lane(lane_id)
		if _path.is_empty():
			_find_core_and_attack()
		else:
			var my_tile = LaneManager.world_to_tile(global_position)
			var idx = _path.find(my_tile)
			if idx != -1:
				_current_path_index = idx
			else:
				_current_path_index = (_path.size() - 1)
				
		# Snap to exact lane center (Z axis) immediately on spawn
		var ideal_z = LaneManager.tile_to_world(Vector2i(0, lane_id)).z + LaneManager.get_layer_offset("building").z
		global_position.z = ideal_z
	else:
		_find_core_and_attack()

func _find_core_and_attack() -> void:
	_path = []
	var core = get_tree().current_scene.get_node_or_null("Core")
	if is_instance_valid(core):
		_attack_target = core
		state = State.MOVING

func _physics_process(delta: float) -> void:
	if state == State.ATTACKING:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	
	# Free Roaming Logic
	if lane_id == -1 or _path.is_empty():
		if not is_instance_valid(_attack_target):
			_find_core_and_attack()
			if not is_instance_valid(_attack_target):
				return 
		
		var dist = global_position.distance_to(_attack_target.global_position)
		if dist < 1.5:
			set_attack_target(_attack_target)
			state = State.ATTACKING
			attacker_component.start_attacking(_attack_target)
			velocity = Vector3.ZERO
		else:
			var dir = global_position.direction_to(_attack_target.global_position)
			dir.y = 0
			velocity = dir.normalized() * speed
		
		move_and_slide()
		return

	# Lane Logic
	if _current_path_index < 0:
		_on_reached_end()
		return

	# Lane Centering (Z-Axis Snap)
	# Determine the Z coordinate of the lane's center
	var ideal_z = LaneManager.tile_to_world(Vector2i(0, lane_id)).z + LaneManager.get_layer_offset("building").z
	# Soft snap / Correction to prevent physics drift
	if abs(global_position.z - ideal_z) > 0.01:
		global_position.z = move_toward(global_position.z, ideal_z, 5.0 * delta)

	var _next_tile = _path[_current_path_index]
	
	if _current_path_index <= 0:
		_on_reached_end()
		return

	var target_tile = _path[_current_path_index - 1]
	
	# Check for obstacles
	var obstacle = LaneManager.get_buildable_at(target_tile)
	if is_instance_valid(obstacle) and obstacle.has_node("HealthComponent"):
		var obstacle_pos = LaneManager.tile_to_world(target_tile)
		if abs(global_position.x - obstacle_pos.x) < 0.8: # Close enough to hit
			set_attack_target(obstacle)
			state = State.ATTACKING
			attacker_component.start_attacking(_attack_target)
			velocity = Vector3.ZERO
		else:
			# Move towards obstacle to hit it
			var dir = (obstacle_pos - global_position).normalized()
			dir.z = 0 # Force straight line
			velocity = dir * speed
	else:
		var target_position = LaneManager.tile_to_world(target_tile) + LaneManager.get_layer_offset("building")
		
		# Only check X distance for waypoint completion
		if abs(global_position.x - target_position.x) < 0.1:
			_current_path_index -= 1
			velocity = Vector3.ZERO
		else:
			var dir = (target_position - global_position).normalized()
			dir.z = 0 # Strictly horizontal movement along X
			velocity = dir * speed

	move_and_slide()

func set_attack_target(new_target: Node3D):
	if is_instance_valid(_attack_target) and _attack_target.has_node("HealthComponent"):
		var hc = _attack_target.get_node("HealthComponent")
		if hc.is_connected("died", _on_target_died):
			hc.died.disconnect(_on_target_died)
	_attack_target = new_target
	if is_instance_valid(_attack_target):
		_attack_target.get_node("HealthComponent").died.connect(_on_target_died, CONNECT_ONE_SHOT)

func _on_target_died(_node_that_died):
	attacker_component.stop_attacking()
	set_attack_target(null)
	state = State.MOVING

func _on_reached_end():
	var core = get_tree().current_scene.get_node_or_null("Core")
	if is_instance_valid(core):
		set_attack_target(core)
		state = State.ATTACKING
		attacker_component.start_attacking(_attack_target)
	else:
		emit_signal("died")
		queue_free()

func _on_health_depleted(_node):
	_spawn_drops()
	emit_signal("died")
	queue_free()

func _spawn_drops():
	if drop_table.is_empty(): return
	for drop in drop_table:
		if randf() <= drop.get("chance", 0.0):
			var item_id = drop.get("item", "")
			var count = randi_range(drop.get("min", 1), drop.get("max", 1))
			print("Enemy dropped: %s x%d" % [item_id, count])

func get_lane_id() -> int: return lane_id
