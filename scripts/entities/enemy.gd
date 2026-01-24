class_name Enemy
extends CharacterBody3D

@export var enemy_resource: EnemyResource

signal tile_changed(old_tile, new_tile)

enum State {
	MOVE,
	ATTACK_WAIT,
	ATTACK_LUNGE,
	ATTACK_RETURN,
	RAGDOLL
}

var current_state: State = State.MOVE

var health_component: HealthComponent
var elemental_component: ElementalComponent
var move_component: MoveComponent 
var attacker_component: AttackerComponent

# Visuals
@onready var model_container: Node3D = get_node_or_null("ModelContainer")

# Optimized Visual Tinting
var _tint_materials: Array[StandardMaterial3D] = []
var _tint_sprites: Array[Node] = []
var _tint_timer: float = 0.0
const TINT_DURATION: float = 0.5

const SPEED_SCALE: float = 0.02

# Stats
var base_speed: float = 5.0
var base_attack_damage: float = 10.0
var base_attack_speed: float = 1.0
var base_defense: float = 0.0
var base_weight: float = 10.0

var is_staggered: bool = false
var current_attack_target: Node3D = null

# Physics / Gravity Status
var has_gravity_effect: bool = false
var _ragdoll_recovery_timer: float = 0.0

# Pathfinding
var current_path_queue: Array[Vector3] = []
var _is_waiting_for_step: bool = false
var _first_physics_frame: bool = true

# Attack State Variables
var safe_tile_center: Vector3 = Vector3.ZERO
var attack_wait_timer: float = 0.0

# Lane Tracking
var _registered_lane_id: int = -1
var _current_tile_coords: Vector2i = Vector2i(-9999, -9999)

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 
	set_collision_mask_value(2, false) 
	
	if not model_container:
		model_container = get_node_or_null("ModelFallback")
	
	_cache_visual_materials(model_container)
	
	health_component = get_node_or_null("HealthComponent")
	elemental_component = get_node_or_null("ElementalComponent")
	move_component = get_node_or_null("MoveComponent")
	attacker_component = get_node_or_null("AttackerComponent")
	
	if not move_component:
		move_component = MoveComponent.new()
		move_component.name = "MoveComponent"
		add_child(move_component)
	
	move_component.set_physics_process(false)
	
	if health_component:
		health_component.staggered.connect(_on_staggered)
		health_component.recovered.connect(_on_recovered)
		health_component.died.connect(_on_died)
		health_component.health_changed.connect(_on_health_changed)
	
	if enemy_resource:
		initialize_from_resource(enemy_resource)
	else:
		if health_component:
			health_component.current_health = health_component.max_health
			base_defense = health_component.defense
		if move_component and move_component.move_speed > 0:
			base_speed = move_component.move_speed
		
	_register_lane()

func _cache_visual_materials(node: Node) -> void:
	if not is_instance_valid(node): return
	
	if node is Sprite3D or node is AnimatedSprite3D:
		_tint_sprites.append(node)
		
	elif node is MeshInstance3D:
		if node.mesh:
			var surf_count = node.mesh.get_surface_count()
			for i in range(surf_count):
				var mat = node.get_active_material(i)
				if not mat: mat = StandardMaterial3D.new()
				if mat is StandardMaterial3D:
					var unique_mat = mat.duplicate()
					node.set_surface_override_material(i, unique_mat)
					_tint_materials.append(unique_mat)
	
	for child in node.get_children():
		_cache_visual_materials(child)

func _exit_tree() -> void:
	if _registered_lane_id != -1:
		LaneManager.unregister_enemy(self, _registered_lane_id)
		LaneManager.update_enemy_position(self, _current_tile_coords, Vector2i(-9999, -9999))

func _register_lane() -> void:
	var tile = LaneManager.world_to_tile(global_position)
	_registered_lane_id = tile.y
	_current_tile_coords = tile
	LaneManager.register_enemy(self, _registered_lane_id)

func initialize_from_resource(res: EnemyResource) -> void:
	enemy_resource = res 
	if health_component:
		health_component.max_health = res.health
		health_component.current_health = res.health
		health_component.defense = res.defense
		health_component.magical_defense = res.magical_defense
		base_defense = res.defense
	
	if elemental_component:
		elemental_component.elemental_cd += res.elemental_cd

	base_speed = res.speed * SPEED_SCALE
	base_attack_damage = res.attack_damage
	base_attack_speed = res.attack_speed
	base_weight = res.weight
	
	if attacker_component:
		attacker_component.initialize(res.attack_damage, res.attack_speed, res.attack_element)

func set_path(world_path: Array[Vector3]) -> void:
	current_path_queue = world_path.duplicate()
	_is_waiting_for_step = false
	if current_state != State.RAGDOLL:
		current_state = State.MOVE
		_advance_path_point()

func _advance_path_point() -> void:
	if not move_component: return
	if current_path_queue.is_empty():
		move_component.target_position = global_position
		return
	var next_point = current_path_queue.pop_front()
	next_point.y = global_position.y
	move_component.target_position = next_point

func _process(delta: float) -> void:
	# Priority 1: Damage Flash (Red)
	if _tint_timer > 0.0:
		_tint_timer -= delta
		var t = 0.0
		if _tint_timer > 0.0: t = _tint_timer / TINT_DURATION
		var col = Color.WHITE.lerp(Color(1.0, 0.2, 0.2), t)
		_apply_tint(col)
		
	# Priority 2: Elemental Tint (10% Opacity Mix)
	else:
		var target_color = Color.WHITE
		if elemental_component:
			var active_elements = elemental_component.get_active_element_names()
			if not active_elements.is_empty():
				var r = 0.0
				var g = 0.0
				var b = 0.0
				var count = 0
				
				for id in active_elements:
					var res = ElementManager.get_element(id)
					if res:
						r += res.color.r
						g += res.color.g
						b += res.color.b
						count += 1
						
				if count > 0:
					var avg_color = Color(r / count, g / count, b / count, 1.0)
					target_color = Color.WHITE.lerp(avg_color, 0.1) # 10% tint strength
		
		_apply_tint(target_color)
		
		# Reset timer flag to keep it inactive
		if _tint_timer != -10.0:
			_tint_timer = -10.0

func _physics_process(delta: float) -> void:
	var new_tile = LaneManager.world_to_tile(global_position)
	if new_tile != _current_tile_coords:
		var old_tile = _current_tile_coords
		LaneManager.update_enemy_position(self, _current_tile_coords, new_tile)
		_current_tile_coords = new_tile
		
		# Notify components of tile change for spatial optimization (e.g., Conduct)
		emit_signal("tile_changed", old_tile, new_tile)
		
		if new_tile.y != _registered_lane_id:
			LaneManager.unregister_enemy(self, _registered_lane_id)
			_registered_lane_id = new_tile.y
			LaneManager.register_enemy(self, _registered_lane_id)

	if is_staggered and current_state != State.RAGDOLL: return
	_update_stats()
	
	if current_attack_target:
		if not is_instance_valid(current_attack_target) or current_attack_target.is_queued_for_deletion():
			_stop_attacking_sequence()
	
	match current_state:
		State.MOVE:
			_process_move_state(delta)
		State.ATTACK_WAIT:
			_process_attack_wait(delta)
		State.ATTACK_LUNGE:
			_process_attack_lunge(delta)
		State.ATTACK_RETURN:
			_process_attack_return(delta)
		State.RAGDOLL:
			_process_ragdoll_state(delta)

# --- PHYSICS / GRAVITY SYSTEM ---

func apply_impulse(force_vector: Vector3) -> void:
	has_gravity_effect = true
	current_state = State.RAGDOLL
	_ragdoll_recovery_timer = 0.5
	
	var final_weight = get_weight()
	if final_weight < 0.1: final_weight = 0.1
	
	var accel = force_vector / final_weight
	velocity += accel
	
	if abs(force_vector.y) < 0.1:
		velocity.y += 2.0 

func get_weight() -> float:
	var w = base_weight
	if elemental_component:
		w += elemental_component.get_stat_modifier("weight")
	return max(1.0, w)

func _process_ragdoll_state(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	
	var friction = 2.0 if not is_on_floor() else 8.0
	velocity.x = move_toward(velocity.x, 0, friction * delta)
	velocity.z = move_toward(velocity.z, 0, friction * delta)
	
	if model_container and velocity.length_squared() > 1.0:
		var axis = velocity.cross(Vector3.UP).normalized()
		if axis.length_squared() > 0.01:
			model_container.rotate(axis, velocity.length() * delta * 0.2)
	
	move_and_slide()
	
	_ragdoll_recovery_timer -= delta
	if _ragdoll_recovery_timer <= 0:
		if is_on_floor() and velocity.length_squared() < 1.0:
			_recover_from_ragdoll()

func _recover_from_ragdoll() -> void:
	has_gravity_effect = false
	velocity = Vector3.ZERO
	if model_container:
		var tween = create_tween()
		tween.tween_property(model_container, "rotation", Vector3.ZERO, 0.3)
	
	if _registered_lane_id != -1:
		var path = LaneManager.get_path_for_enemy(_registered_lane_id, global_position)
		set_path(path)
	else:
		current_state = State.MOVE

# --- STANDARD STATES ---

func _process_move_state(_delta: float) -> void:
	if _is_waiting_for_step: return
	if not move_component: return
	
	var dir = (move_component.target_position - global_position).normalized()
	velocity = dir * move_component.move_speed
	velocity.y = 0 
	
	if dir.length_squared() > 0.01:
		var look_pos = global_position + dir
		look_at(Vector3(look_pos.x, global_position.y, look_pos.z), Vector3.UP)
		
	move_and_slide()
	
	for i in range(get_slide_collision_count()):
		var col = get_slide_collision(i)
		var collider = col.get_collider()
		if collider is BaseBuilding or collider is StaticBody3D:
			_start_attacking_sequence(collider)
			return

	var dist_sq = Vector2(global_position.x, global_position.z).distance_squared_to(Vector2(move_component.target_position.x, move_component.target_position.z))
	if dist_sq < (move_component.stop_distance * move_component.stop_distance):
		if enemy_resource and enemy_resource.movement_type == EnemyResource.MovementType.BLOCK_BY_BLOCK:
			_handle_block_arrival()
		else:
			_advance_path_point()

func _handle_block_arrival() -> void:
	velocity = Vector3.ZERO
	_is_waiting_for_step = true
	
	var wait_time = 0.5
	if move_component.move_speed > 0.001:
		wait_time = (LaneManager.GRID_SCALE * 0.5) / move_component.move_speed
	
	await get_tree().create_timer(wait_time).timeout
	if not is_instance_valid(self): return
	if is_staggered: return
	if current_state != State.MOVE: return
	
	_advance_path_point()
	_is_waiting_for_step = false

func _process_attack_wait(delta: float) -> void:
	if is_instance_valid(current_attack_target):
		var target_pos = current_attack_target.global_position
		var look_pos = Vector3(target_pos.x, global_position.y, target_pos.z)
		if global_position.distance_squared_to(look_pos) > 0.001:
			look_at(look_pos, Vector3.UP)
	
	attack_wait_timer -= delta
	if attack_wait_timer <= 0:
		current_state = State.ATTACK_LUNGE

func _process_attack_lunge(_delta: float) -> void:
	if not is_instance_valid(current_attack_target):
		_stop_attacking_sequence()
		return

	var target_pos = current_attack_target.global_position
	target_pos.y = global_position.y 
	
	var dir = (target_pos - global_position).normalized()
	velocity = dir * move_component.move_speed
	velocity.y = 0
	
	move_and_slide()
	
	var dist_2d = Vector2(global_position.x, global_position.z).distance_to(Vector2(target_pos.x, target_pos.z))
	if dist_2d < 0.75: 
		_perform_attack_damage()
		current_state = State.ATTACK_RETURN

func _process_attack_return(_delta: float) -> void:
	var my_pos_2d = Vector2(global_position.x, global_position.z)
	var target_pos_2d = Vector2(safe_tile_center.x, safe_tile_center.z)
	var dist = my_pos_2d.distance_to(target_pos_2d)
	
	if dist < 0.05:
		global_position.x = safe_tile_center.x
		global_position.z = safe_tile_center.z
		velocity = Vector3.ZERO
		_reset_attack_timer()
		current_state = State.ATTACK_WAIT
		return

	var dir = (safe_tile_center - global_position).normalized()
	dir.y = 0 
	velocity = dir * move_component.move_speed
	
	if is_instance_valid(current_attack_target):
		var t_pos = current_attack_target.global_position
		look_at(Vector3(t_pos.x, global_position.y, t_pos.z), Vector3.UP)
		
	move_and_slide()

# --- HELPERS ---

func _start_attacking_sequence(target: Node) -> void:
	if current_state != State.MOVE: return
	
	current_attack_target = target
	velocity = Vector3.ZERO
	set_collision_mask_value(1, false)
	
	var target_tile = LaneManager.world_to_tile(target.global_position)
	var my_tile = LaneManager.world_to_tile(global_position)
	var safe_tile_coords = my_tile
	
	if safe_tile_coords == target_tile:
		var diff = global_position - target.global_position
		var offset = Vector2i.ZERO
		if abs(diff.x) > abs(diff.z):
			offset.x = 1 if diff.x > 0 else -1
		else:
			offset.y = 1 if diff.z > 0 else -1
		safe_tile_coords = target_tile + offset

	safe_tile_center = LaneManager.tile_to_world(safe_tile_coords) + LaneManager.get_layer_offset("building")
	safe_tile_center.y = global_position.y
	
	current_state = State.ATTACK_RETURN

func _perform_attack_damage() -> void:
	if not is_instance_valid(current_attack_target): return
	
	var dmg = base_attack_damage
	var elem = enemy_resource.attack_element if enemy_resource else null
	
	if current_attack_target.has_method("take_damage"):
		current_attack_target.take_damage(dmg, elem, self)
	elif current_attack_target.has_node("HealthComponent"):
		current_attack_target.get_node("HealthComponent").take_damage(dmg, elem, self)

func _stop_attacking_sequence() -> void:
	set_collision_mask_value(1, true)
	current_attack_target = null
	if current_state != State.RAGDOLL:
		current_state = State.MOVE
		_handle_block_arrival()

func _reset_attack_timer() -> void:
	var spd = base_attack_speed
	if elemental_component:
		var mult = elemental_component.get_stat_modifier("attack_speed_mult")
		spd *= (1.0 + mult)
	
	if spd <= 0.1: spd = 0.1
	attack_wait_timer = 1.0 / spd

func _update_stats() -> void:
	var final_speed = base_speed
	if elemental_component:
		var spd_mult = elemental_component.get_stat_modifier("speed_mult")
		final_speed *= (1.0 + spd_mult)
	if move_component:
		move_component.move_speed = max(0, final_speed)

func _on_staggered(_duration: float) -> void:
	is_staggered = true
	if current_state != State.RAGDOLL:
		velocity = Vector3.ZERO

func _on_recovered() -> void:
	is_staggered = false

func _on_died(_node):
	queue_free()

func _on_health_changed(new_val, old_val):
	print("Enemy %s health changed: %s -> %s" % [name, old_val, new_val]) # DO NOT REMOVE
	if new_val < old_val:
		_tint_timer = TINT_DURATION

func _apply_tint(color: Color):
	for s in _tint_sprites:
		if is_instance_valid(s): s.modulate = color
	for m in _tint_materials:
		if m: m.albedo_color = color

func take_damage(amount: float, element: ElementResource = null, source: Node = null) -> void:
	if health_component:
		if element:
			ElementManager.apply_element(self, element, source, amount)
		health_component.take_damage(amount, element, source)

func get_lane_id() -> int:
	return _registered_lane_id
