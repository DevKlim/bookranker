class_name Enemy
extends CharacterBody3D

@export var enemy_resource: EnemyResource

signal tile_changed(old_tile, new_tile)

enum State {
	MOVE,
	ATTACK_WAIT,
	ATTACK_LUNGE,
	ATTACK_RETURN,
	RAGDOLL,
	IDLE,
	WANDER,
	AGGRO 
}

var current_state: State = State.MOVE

var health_component: HealthComponent
var elemental_component: ElementalComponent
var move_component: MoveComponent 
var attacker_component: AttackerComponent
var enemy_movement_component: EnemyMovementComponent

# Visuals
@onready var model_container: Node3D = get_node_or_null("ModelContainer")

# Optimized Visual Tinting
var _tint_materials: Array[StandardMaterial3D] =[]
var _tint_sprites: Array[Node] =[]
var _tint_timer: float = 0.0
const TINT_DURATION: float = 0.5

const SPEED_SCALE: float = 0.05

# Stats
var base_speed: float = 5.0
var base_weight: float = 10.0

# Range Config
var range_depth: int = 1
var range_width: int = 0

# Field Behavior
var is_field_enemy: bool = false
var aggro_range: float = 10.0
var wander_radius: float = 5.0
var base_idle_time: float = 2.0
var idle_timer: float = 0.0
var _home_tile: Vector2i = Vector2i.ZERO 

var is_staggered: bool = false
var current_attack_target: Node3D = null

# Physics / Gravity Status
var has_gravity_effect: bool = false
var _ragdoll_recovery_timer: float = 0.0

# Pathfinding
var current_path_queue: Array[Vector3] =[]

# Attack State Variables
var safe_tile_center: Vector3 = Vector3.ZERO
var attack_wait_timer: float = 0.0

# Lane Tracking
var _registered_lane_id: int = -1
var _current_tile_coords: Vector2i = Vector2i(-9999, -9999)

var _debug_timer: float = 0.0

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1 
	
	if not model_container:
		model_container = get_node_or_null("ModelFallback")
	
	_cache_visual_materials(model_container)
	_apply_retro_glow(model_container)
	
	health_component = get_node_or_null("HealthComponent")
	elemental_component = get_node_or_null("ElementalComponent")
	move_component = get_node_or_null("MoveComponent")
	attacker_component = get_node_or_null("AttackerComponent")
	
	if not move_component:
		move_component = MoveComponent.new()
		move_component.name = "MoveComponent"
		add_child(move_component)
	move_component.set_physics_process(false)
	
	enemy_movement_component = get_node_or_null("EnemyMovementComponent")
	if not enemy_movement_component:
		enemy_movement_component = EnemyMovementComponent.new()
		enemy_movement_component.name = "EnemyMovementComponent"
		add_child(enemy_movement_component)
	
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
		current_state = State.MOVE
		
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

func _apply_retro_glow(node: Node) -> void:
	if not is_instance_valid(node): return
	if node.name == "SelectionVisuals" or node.name == "ProgressBar": return
	
	if node is MeshInstance3D:
		var glow_mat = ShaderMaterial.new()
		glow_mat.shader = load("res://shaders/retro_glow.gdshader")
		if glow_mat.shader:
			glow_mat.set_shader_parameter("glow_color", Color(1.0, 0.1, 0.3, 0.8)) # Red/Magenta Retro Glow
			glow_mat.set_shader_parameter("fresnel_power", 2.0)
			glow_mat.set_shader_parameter("edge_intensity", 1.5)
			node.material_overlay = glow_mat
			
	elif node is Sprite3D or node is AnimatedSprite3D:
		var sprite_mat = ShaderMaterial.new()
		sprite_mat.shader = load("res://shaders/sprite_retro_glow.gdshader")
		if sprite_mat.shader:
			sprite_mat.set_shader_parameter("glow_color", Color(1.0, 0.1, 0.3, 0.8))
			sprite_mat.set_shader_parameter("width", 2.0)
			
			if node.material_override:
				var base_tex = null
				if node.material_override is StandardMaterial3D:
					base_tex = node.material_override.albedo_texture
				sprite_mat.set_shader_parameter("texture_albedo", base_tex)
			else:
				if "texture" in node and node.get("texture"):
					sprite_mat.set_shader_parameter("texture_albedo", node.texture)
				elif "sprite_frames" in node and node is AnimatedSprite3D:
					if node.sprite_frames and node.animation:
						sprite_mat.set_shader_parameter("texture_albedo", node.sprite_frames.get_frame_texture(node.animation, node.frame))
			
			node.material_override = sprite_mat

	for child in node.get_children():
		_apply_retro_glow(child)

func _exit_tree() -> void:
	if _registered_lane_id != -1:
		LaneManager.unregister_enemy(self, _registered_lane_id)
		LaneManager.update_enemy_position(self, _current_tile_coords, Vector2i(-9999, -9999))

func _register_lane() -> void:
	var tile = LaneManager.world_to_tile(global_position)
	_registered_lane_id = tile.y
	_current_tile_coords = tile
	LaneManager.register_enemy(self, _registered_lane_id)

func initialize_from_resource(res: EnemyResource, config: Dictionary = {}) -> void:
	enemy_resource = res 
	if health_component:
		health_component.max_health = res.health
		health_component.current_health = res.health
		health_component.defense = res.defense
		health_component.magical_defense = res.magical_defense
	
	if elemental_component:
		elemental_component.elemental_cd += res.elemental_cd

	base_speed = res.speed * SPEED_SCALE
	base_weight = res.weight
	range_depth = res.attack_range_depth
	range_width = res.attack_range_width
	
	if attacker_component:
		attacker_component.initialize(res.attack_damage, res.attack_speed, res.attack_element)
	
	is_field_enemy = config.get("is_field_enemy", false)
	aggro_range = config.get("aggro_range", 10.0)
	wander_radius = config.get("wander_radius", 5.0)
	base_idle_time = config.get("idle_time", 2.0)
	idle_timer = base_idle_time

	if is_field_enemy:
		current_state = State.IDLE
		_home_tile = LaneManager.world_to_tile(global_position)
		if global_position.y < 0.5: global_position.y = 0.5

func set_as_wave_enemy() -> void:
	is_field_enemy = false
	current_state = State.MOVE
	
	var clutters = get_tree().get_nodes_in_group("clutter")
	for c in clutters:
		if is_instance_valid(c):
			_ignore_collisions_recursive(c)
			
	set_path([])

func _ignore_collisions_recursive(node: Node) -> void:
	if node is PhysicsBody3D:
		add_collision_exception_with(node)
	for child in node.get_children():
		_ignore_collisions_recursive(child)

func set_path(world_path: Array[Vector3]) -> void:
	current_path_queue = world_path.duplicate()
	
	if enemy_movement_component:
		enemy_movement_component.reset_target()
		
	if current_state != State.RAGDOLL:
		if current_state != State.AGGRO:
			current_state = State.MOVE

func _process(delta: float) -> void:
	_process_tint(delta)

func _process_tint(delta: float) -> void:
	if _tint_timer > 0.0:
		_tint_timer -= delta
		var t = 0.0
		if _tint_timer > 0.0: t = _tint_timer / TINT_DURATION
		var col = Color.WHITE.lerp(Color(1.0, 0.2, 0.2), t)
		_apply_tint(col)
	else:
		_apply_tint(Color.WHITE)

func _physics_process(delta: float) -> void:
	# Failsafe kill-Z plane (prevents soft-locks if spawning outside of terrain bounds incorrectly)
	if global_position.y < -10.0:
		if health_component:
			health_component.take_damage(999999.0)
		else:
			queue_free()
		return

	var new_tile = LaneManager.world_to_tile(global_position)
	if new_tile != _current_tile_coords:
		var old_tile = _current_tile_coords
		LaneManager.update_enemy_position(self, _current_tile_coords, new_tile)
		_current_tile_coords = new_tile
		emit_signal("tile_changed", old_tile, new_tile)
		if new_tile.y != _registered_lane_id:
			LaneManager.unregister_enemy(self, _registered_lane_id)
			_registered_lane_id = new_tile.y
			LaneManager.register_enemy(self, _registered_lane_id)

	if is_staggered and current_state != State.RAGDOLL: return
	_update_stats()
	
	if current_attack_target:
		if not is_instance_valid(current_attack_target) or current_attack_target.is_queued_for_deletion() or current_attack_target.get("is_dead") == true:
			_stop_attacking_sequence()
		elif current_state in[State.ATTACK_WAIT, State.ATTACK_LUNGE]:
			if not _is_target_in_range(current_attack_target):
				if attacker_component: attacker_component.stop_attacking()
				
				if is_field_enemy and global_position.distance_to(current_attack_target.global_position) <= aggro_range * 1.5:
					current_state = State.AGGRO
					set_path([])
				else:
					_stop_attacking_sequence()
		elif is_field_enemy and current_state == State.AGGRO:
			if global_position.distance_to(current_attack_target.global_position) > aggro_range * 1.5:
				_stop_attacking_sequence()
	
	if current_state == State.RAGDOLL:
		set_collision_mask_value(1, true)
		if not is_on_floor(): velocity.y -= 20.0 * delta
	else:
		set_collision_mask_value(1, true)
		velocity.y = 0.0
		if not is_equal_approx(global_position.y, 1.0):
			global_position.y = lerp(global_position.y, 1.0, 15.0 * delta)

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
		State.IDLE:
			_process_idle_state(delta)
		State.WANDER:
			_process_wander_state(delta)
		State.AGGRO:
			_process_aggro_state(delta)
	
	move_and_slide()
	
	_debug_timer += delta
	if _debug_timer >= 2.0:
		_debug_timer = 0.0
		var tgt_name = current_attack_target.name if is_instance_valid(current_attack_target) else "None"

# --- PHYSICS SYSTEM ---

func apply_impulse(force_vector: Vector3) -> void:
	has_gravity_effect = true
	current_state = State.RAGDOLL
	_ragdoll_recovery_timer = 0.5
	var final_weight = max(1.0, get_weight())
	velocity += (force_vector / final_weight)
	if abs(force_vector.y) < 0.1: velocity.y += 2.0 

func get_weight() -> float:
	var w = base_weight
	if elemental_component: w += elemental_component.get_stat_modifier("weight")
	return max(1.0, w)

func _process_ragdoll_state(delta: float) -> void:
	var friction = 2.0 if not is_on_floor() else 8.0
	velocity.x = move_toward(velocity.x, 0, friction * delta)
	velocity.z = move_toward(velocity.z, 0, friction * delta)
	
	if model_container and velocity.length_squared() > 1.0:
		var axis = velocity.cross(Vector3.UP).normalized()
		if axis.length_squared() > 0.01:
			model_container.rotate(axis, velocity.length() * delta * 0.2)
	
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
	
	if is_field_enemy:
		current_state = State.IDLE
		idle_timer = base_idle_time
	elif _registered_lane_id != -1:
		var path = LaneManager.get_path_for_enemy(_registered_lane_id, global_position)
		set_path(path)
	else:
		current_state = State.MOVE

# --- FIELD BEHAVIOR ---

func _process_idle_state(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0, 10.0 * delta)
	velocity.z = move_toward(velocity.z, 0, 10.0 * delta)
	_check_aggro(delta)
	if current_state != State.IDLE: return
	
	if enemy_resource and enemy_resource.field_movement == EnemyResource.FieldMovement.STATIC:
		return 
	
	idle_timer -= delta
	if idle_timer <= 0:
		_pick_wander_target()

func _pick_wander_target() -> void:
	var valid_tiles =[]
	for x in range(-int(wander_radius), int(wander_radius) + 1):
		for y in range(-int(wander_radius), int(wander_radius) + 1):
			var t = _home_tile + Vector2i(x,y)
			if t == _current_tile_coords: continue
			if not LaneManager.is_valid_tile(t): continue
			if LaneManager.get_entity_at(t, "building"): continue
			valid_tiles.append(t)
	
	if valid_tiles.is_empty():
		idle_timer = base_idle_time
		return

	var target_tile = valid_tiles.pick_random()
	var target_pos = LaneManager.tile_to_world(target_tile)
	var world_path = LaneManager.get_path_world(global_position, target_pos)
	
	if world_path.is_empty():
		idle_timer = base_idle_time
		return

	set_path(world_path)
	current_state = State.WANDER

func _process_wander_state(delta: float) -> void:
	_check_aggro(delta)
	if current_state != State.WANDER: return

	if enemy_movement_component and not enemy_movement_component.has_target and enemy_movement_component.step_cooldown <= 0:
		current_state = State.IDLE
		idle_timer = base_idle_time
		return

	_process_grid_movement(delta)

func _process_aggro_state(delta: float) -> void:
	if not is_instance_valid(current_attack_target) or current_attack_target.get("is_dead") == true:
		_stop_attacking_sequence()
		return
	
	if global_position.distance_to(current_attack_target.global_position) > aggro_range * 1.5:
		_stop_attacking_sequence()
		return

	if _is_target_in_range(current_attack_target):
		_start_attacking_sequence(current_attack_target)
		return
	
	if enemy_movement_component and not enemy_movement_component.has_target and enemy_movement_component.step_cooldown <= 0:
		var path = LaneManager.get_path_world(global_position, current_attack_target.global_position)
		if path.is_empty():
			var look_pos = current_attack_target.global_position
			look_pos.y = global_position.y
			look_at(look_pos, Vector3.UP)
			return 
		set_path(path) 

	_process_grid_movement(delta)

func _check_aggro(_delta: float) -> void:
	if not is_field_enemy: return
	var nearby = LaneManager.get_entity_at(_current_tile_coords, "building")
	
	# Explicitly ignore clutter so enemies don't aggro rocks/trees
	if nearby and is_instance_valid(nearby) and not (nearby is ClutterObject):
		current_attack_target = nearby
		current_state = State.AGGRO
		set_path([])
		return
	
	var allies = get_tree().get_nodes_in_group("allies")
	for ally in allies:
		if ally.get("is_dead") == true: continue
		if is_instance_valid(ally):
			if global_position.distance_squared_to(ally.global_position) <= (aggro_range * aggro_range):
				current_attack_target = ally
				current_state = State.AGGRO
				set_path([])
				return

# --- MOVEMENT & ATTACK ---

func _process_move_state(delta: float) -> void:
	if is_field_enemy and enemy_movement_component and not enemy_movement_component.has_target and enemy_movement_component.step_cooldown <= 0:
		current_state = State.IDLE
		idle_timer = 1.0
		return
	_process_grid_movement(delta)

func _process_grid_movement(delta: float) -> void:
	_scan_for_targets()
	if current_state in[State.ATTACK_WAIT, State.ATTACK_LUNGE, State.ATTACK_RETURN]: return

	if not enemy_movement_component: return

	var spd: float = base_speed
	if move_component:
		spd = move_component.move_speed

	var move_vel = enemy_movement_component.get_movement_velocity(delta, current_path_queue, is_field_enemy, spd, _registered_lane_id, enemy_resource)
	
	velocity.x = move_vel.x
	velocity.z = move_vel.z

func _process_attack_wait(delta: float) -> void:
	velocity.x = 0; velocity.z = 0
	if is_instance_valid(current_attack_target) and current_attack_target.get("is_dead") != true:
		var target_pos = current_attack_target.global_position
		var look_pos = Vector3(target_pos.x, global_position.y, target_pos.z)
		if global_position.distance_squared_to(look_pos) > 0.001:
			look_at(look_pos, Vector3.UP)
	
	attack_wait_timer -= delta
	if attack_wait_timer <= 0:
		current_state = State.ATTACK_LUNGE

func _process_attack_lunge(_delta: float) -> void:
	if not is_instance_valid(current_attack_target) or current_attack_target.get("is_dead") == true:
		_stop_attacking_sequence(); return

	var target_pos = current_attack_target.global_position
	var my_flat = Vector3(global_position.x, 0, global_position.z)
	var t_flat = Vector3(target_pos.x, 0, target_pos.z)
	var dir = (t_flat - my_flat).normalized()
	
	var spd: float = base_speed
	if move_component:
		spd = move_component.move_speed
	spd *= 3.0
	
	# Lunge physics
	velocity.x = dir.x * spd
	velocity.z = dir.z * spd
	
	var lunge_blocked = false
	for i in get_slide_collision_count():
		var col = get_slide_collision(i)
		if abs(col.get_normal().y) < 0.5:
			lunge_blocked = true
			break
	
	if my_flat.distance_to(t_flat) < 0.8 or lunge_blocked: 
		_perform_attack_damage()
		current_state = State.ATTACK_RETURN

func _process_attack_return(delta: float) -> void:
	var my_pos_2d = Vector2(global_position.x, global_position.z)
	var target_pos_2d = Vector2(safe_tile_center.x, safe_tile_center.z)
	
	var dist = my_pos_2d.distance_to(target_pos_2d)
	
	var spd: float = base_speed
	if move_component:
		spd = move_component.move_speed
	spd *= 2.0
	
	if dist <= spd * delta or dist < 0.05:
		global_position.x = safe_tile_center.x
		global_position.z = safe_tile_center.z
		velocity.x = 0; velocity.z = 0
		
		var cd = 1.0
		if attacker_component and attacker_component.basic_attack:
			cd = attacker_component.basic_attack.cooldown
		
		attack_wait_timer = cd
		current_state = State.ATTACK_WAIT
		return

	var dir = (safe_tile_center - global_position).normalized()
	velocity.x = dir.x * spd
	velocity.z = dir.z * spd
	
	if is_instance_valid(current_attack_target) and current_attack_target.get("is_dead") != true:
		var t_pos = current_attack_target.global_position
		look_at(Vector3(t_pos.x, global_position.y, t_pos.z), Vector3.UP)

func _scan_for_targets() -> void:
	var allies = get_tree().get_nodes_in_group("allies")
	for ally in allies:
		if ally.get("is_dead") == true: continue
		if is_instance_valid(ally) and _is_target_in_range(ally):
			if ally.has_method("take_damage") or ally.has_node("HealthComponent"):
				_start_attacking_sequence(ally); return

	var my_tile = LaneManager.world_to_tile(global_position)
	for d in range(0, range_depth + 1):
		for w in range(-range_width, range_width + 1):
			if not is_field_enemy and w != 0: continue
			
			var check_tile = Vector2i(my_tile.x - d, my_tile.y + w)
			var building = LaneManager.get_entity_at(check_tile, "building")
			
			# Group check bypasses script evaluation cyclic dependency issues
			if building and is_instance_valid(building) and not building.is_in_group("clutter") and (building.has_method("take_damage") or building.has_node("HealthComponent")):
				_start_attacking_sequence(building); return

func _is_target_in_range(target: Node3D) -> bool:
	if not is_instance_valid(target): return false
	
	var my_tile = LaneManager.world_to_tile(global_position)
	
	if is_field_enemy:
		var attack_dist = (float(range_depth) * LaneManager.GRID_SCALE) + 0.5
		var my_flat = Vector3(global_position.x, 0, global_position.z)
		var t_flat = Vector3(target.global_position.x, 0, target.global_position.z)
		return my_flat.distance_to(t_flat) <= attack_dist
	else:
		# Wave Enemy Logic: Must be strictly forward
		for d in range(0, range_depth + 1):
			for w in range(-range_width, range_width + 1):
				if w != 0: continue # Strict Lane Combat
				
				var check_tile = Vector2i(my_tile.x - d, my_tile.y + w)
				
				var entity = LaneManager.get_entity_at(check_tile, "building")
				if entity == target:
					return true
					
				var target_tile = LaneManager.world_to_tile(target.global_position)
				if target_tile == check_tile:
					return true
					
		return false

func _start_attacking_sequence(target: Node) -> void:
	if current_state != State.MOVE and current_state != State.AGGRO and current_state != State.WANDER and current_state != State.IDLE: return
	
	current_attack_target = target
	velocity.x = 0; velocity.z = 0
	
	var safe_tile_coords = LaneManager.world_to_tile(global_position)
	safe_tile_center = LaneManager.tile_to_world(safe_tile_coords)
	safe_tile_center.y = global_position.y
	
	current_state = State.ATTACK_RETURN

func _perform_attack_damage() -> void:
	if not is_instance_valid(current_attack_target) or current_attack_target.get("is_dead") == true: return
	
	if attacker_component:
		attacker_component.start_attacking(current_attack_target)
	else:
		if current_attack_target.has_method("take_damage"):
			current_attack_target.take_damage(10.0, null, self)

func _stop_attacking_sequence() -> void:
	if attacker_component: attacker_component.stop_attacking()
	current_attack_target = null
	if current_state != State.RAGDOLL:
		if is_field_enemy:
			current_state = State.IDLE
			idle_timer = 0.5
		else:
			current_state = State.MOVE
			if enemy_movement_component:
				enemy_movement_component.reset_target()

func get_stat(stat_name: String, default_value: float = 0.0) -> float:
	var val = default_value
	if stat_name == "health": val = health_component.max_health if health_component else enemy_resource.health
	elif stat_name == "speed": val = base_speed
	elif stat_name == "defense": val = health_component.defense if health_component else enemy_resource.defense
	elif stat_name == "attack_damage": val = attacker_component.basic_attack.base_damage if attacker_component and attacker_component.basic_attack else enemy_resource.attack_damage
	
	if elemental_component:
		val *= (1.0 + elemental_component.get_stat_modifier(stat_name + "_mult"))
		val += elemental_component.get_stat_modifier(stat_name + "_flat")
	return val

func _update_stats() -> void:
	var final_speed = base_speed
	if elemental_component:
		var spd_mult = elemental_component.get_stat_modifier("speed_mult")
		final_speed *= (1.0 + spd_mult)
		
	if enemy_resource and enemy_resource.speed_equation != "":
		if ClassDB.class_exists("FormulaHelper") or ResourceLoader.exists("res://scripts/utils/formula_helper.gd"):
			var fh = load("res://scripts/utils/formula_helper.gd")
			if fh:
				var vars = {"base_speed": base_speed, "final_speed": final_speed}
				for k in enemy_resource.stat_weights.keys():
					vars[k+"_weight"] = enemy_resource.stat_weights[k]
					vars[k] = get_stat(k, 0.0)
				final_speed = fh.evaluate(enemy_resource, enemy_resource.speed_equation, vars, final_speed)
				
	if move_component:
		move_component.move_speed = max(0, final_speed)

func _on_staggered(_duration: float) -> void:
	is_staggered = true
	if current_state != State.RAGDOLL: velocity = Vector3.ZERO
func _on_recovered() -> void: is_staggered = false
func _on_died(_node):
	_drop_loot()
	queue_free()
	
func _drop_loot() -> void:
	if not enemy_resource: return
	for drop in enemy_resource.drops:
		if drop.has("pool"):
			var pool_name = drop["pool"]
			var pool = GameManager.get_item_pool(pool_name)
			var item_pick = GameManager.pick_from_weighted_pool(pool)
			if not item_pick.is_empty() and randf() <= drop.get("chance", 1.0):
				var item_id = item_pick.get("item", "")
				_spawn_item(item_id, item_pick.get("min", 1), item_pick.get("max", 1))
		else:
			if randf() <= drop.get("chance", 1.0):
				var item_id = drop.get("item", "")
				_spawn_item(item_id, drop.get("min", 1), drop.get("max", 1))

func _spawn_item(item_id: String, min_amt: int, max_amt: int) -> void:
	if item_id == "": return
	var path = "res://resources/items/%s.tres" % item_id
	if ResourceLoader.exists(path):
		var item = load(path)
		var count = randi_range(min_amt, max_amt)
		if PlayerManager.game_inventory:
			PlayerManager.game_inventory.add_item(item, count)
			
func _on_health_changed(new_val, old_val):
	if new_val < old_val: _tint_timer = TINT_DURATION
	if is_field_enemy and not current_attack_target and current_state != State.RAGDOLL:
		_scan_for_targets()
func _apply_tint(color: Color):
	for s in _tint_sprites:
		if is_instance_valid(s): s.modulate = color
	for m in _tint_materials:
		if m: m.albedo_color = color
func take_damage(amount: float, element: ElementResource = null, source: Node = null) -> void:
	if is_field_enemy and source and source != self and source.is_in_group("allies"):
		if source.get("is_dead") == true:
			pass
		elif not current_attack_target:
			current_attack_target = source
			current_state = State.AGGRO
			set_path([])
	if health_component:
		if element: ElementManager.apply_element(self, element, source, amount)
		health_component.take_damage(amount, element, source)
func get_lane_id() -> int: return _registered_lane_id
