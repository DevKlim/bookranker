class_name AttackerComponent
extends Node

signal attack_started(target, attack_res)
signal attacked(target, damage)

@export var basic_attack: AttackResource
@export var available_attacks: Array[AttackResource] =[]
@export var show_debug_hitboxes: bool = true

var attack_timer: Timer 
var current_target: Node3D = null
var current_target_pos: Vector3 = Vector3.INF
var current_target_dir: Vector3 = Vector3.ZERO
var current_attack: AttackResource = null

func _ready() -> void:
	attack_timer = Timer.new()
	attack_timer.name = "AttackTimer"
	attack_timer.one_shot = true
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	add_child(attack_timer)

func initialize(damage: float, p_attack_speed: float, element: ElementResource) -> void:
	if not basic_attack:
		basic_attack = AttackResource.new()
		basic_attack.base_damage = damage
		basic_attack.cooldown = 1.0 / max(0.1, p_attack_speed)
		basic_attack.element = element

func start_attacking(target: Node3D, specific_attack: AttackResource = null) -> void:
	if not is_instance_valid(target): return
	current_target = target
	current_target_pos = target.global_position
	current_target_dir = Vector3.ZERO
	current_attack = specific_attack if specific_attack else basic_attack
	
	if not current_attack: return
	
	if attack_timer.is_stopped():
		_perform_attack()

func start_attacking_position(target_pos: Vector3, specific_attack: AttackResource = null) -> void:
	current_target = null
	current_target_pos = target_pos
	current_target_dir = Vector3.ZERO
	current_attack = specific_attack if specific_attack else basic_attack
	
	if not current_attack: return
	
	if attack_timer.is_stopped():
		_perform_attack()

func start_attacking_direction(dir: Vector3, specific_attack: AttackResource = null) -> void:
	current_target = null
	current_target_pos = Vector3.INF
	current_target_dir = dir
	current_attack = specific_attack if specific_attack else basic_attack
	
	if not current_attack: return
	
	if attack_timer.is_stopped():
		_perform_attack()

func stop_attacking() -> void:
	current_target = null
	current_target_pos = Vector3.INF
	current_target_dir = Vector3.ZERO
	attack_timer.stop()

func _on_attack_timer_timeout() -> void:
	var target_valid = is_instance_valid(current_target)
	if target_valid or current_target_pos != Vector3.INF or current_target_dir != Vector3.ZERO:
		if target_valid:
			current_target_pos = current_target.global_position
		_perform_attack()
	else:
		stop_attacking()

func _perform_attack() -> void:
	if not current_attack:
		stop_attacking()
		return
		
	var target_valid = is_instance_valid(current_target)
	if not target_valid and current_target_pos == Vector3.INF and current_target_dir == Vector3.ZERO:
		stop_attacking()
		return
		
	var source = get_parent()
	var ammo_item: ItemResource = null
	
	# Ammo override
	if source is Node3D and source.has_node("InventoryComponent"):
		var inv = source.get_node("InventoryComponent")
		if inv.can_receive and not inv.can_output and inv.has_item():
			var first_item = inv.get_first_item()
			if first_item is ItemResource:
				ammo_item = first_item
				inv.remove_item(ammo_item, 1)
		elif current_attack.id == "fan_blow":
			# Fan cannot blow without ammo to propel
			stop_attacking()
			return
			
	var base_attack = current_attack
	if ammo_item and ammo_item.attack_config:
		current_attack = ammo_item.attack_config

	var final_damage = _calculate_damage(source, current_attack)
	
	emit_signal("attack_started", current_target, current_attack)
	_spawn_visuals(source, current_target, current_target_pos)

	if current_attack.spawn_projectile or ammo_item != null:
		var proj_damage = final_damage
		if ammo_item and ammo_item.damage > 0:
			proj_damage += ammo_item.damage
		_spawn_projectile(source, proj_damage, current_attack, ammo_item)
	else:
		_apply_hit(current_target, current_target_pos, final_damage, current_attack, source)

	# Apply base attack's hit if it was overridden and was meant to be an AOE/hit 
	# Example: The Box Fan applies Aero AOE but still fires the overridden fold ammo logic forwards!
	if base_attack != current_attack and not base_attack.spawn_projectile:
		var base_dmg = _calculate_damage(source, base_attack)
		_apply_hit(current_target, current_target_pos, base_dmg, base_attack, source)

	if current_attack.chain_next:
		var next = current_attack.chain_next
		var delay = current_attack.chain_delay
		get_tree().create_timer(delay).timeout.connect(func(): 
			current_attack = next
			_perform_attack()
		)
	else:
		current_attack = basic_attack
			
	var cd = current_attack.cooldown
	var spd_mult = 0.0
	
	# Try to fetch global speed stat from BaseBuilding logic
	if source.has_method("get_stat"):
		spd_mult += source.get_stat("attack_speed_mult", 0.0)
	else:
		if source.has_node("ElementalComponent"):
			var ec = source.get_node("ElementalComponent")
			if ec.has_method("get_stat_modifier"):
				spd_mult += ec.get_stat_modifier("attack_speed_mult")
				
		var s_spd_mult = source.get("attack_speed_mult")
		if s_spd_mult != null:
			spd_mult += float(s_spd_mult)
			
	# Apply dynamic artifact overrides (e.g., Picasso charge time)
	if "active_weapon_item" in source and source.active_weapon_item:
		var artifact = source.active_weapon_item.get_artifact_instance()
		if artifact and artifact.has_method("modify_cooldown"):
			cd = artifact.modify_cooldown(cd, source, current_attack)
	
	cd /= max(0.1, (1.0 + spd_mult))
	
	attack_timer.start(cd)

func _calculate_damage(source: Node, atk: AttackResource) -> float:
	var dmg = atk.base_damage
	var stat_val = 0.0
	
	# Safely extract scaling stats utilizing BaseBuilding's integrated stat system
	if atk.scaling_stat != "":
		if source.has_method("get_stat"):
			stat_val = source.get_stat(atk.scaling_stat, 0.0)
		else:
			var s_val = source.get(atk.scaling_stat)
			if s_val != null:
				stat_val = float(s_val)
			else:
				var stats_dict = source.get("stats")
				if stats_dict != null and stats_dict is Dictionary and stats_dict.has(atk.scaling_stat):
					stat_val = float(stats_dict.get(atk.scaling_stat))
			
	dmg += (stat_val * atk.scaling_factor)
	
	var d_mult = 0.0
	if source.has_method("get_stat"):
		d_mult = source.get_stat("damage_mult", 0.0)
	else:
		if source.has_node("ElementalComponent"):
			var ec = source.get_node("ElementalComponent")
			if ec.has_method("get_stat_modifier"):
				d_mult += ec.get_stat_modifier("damage_mult")
				
		var s_d_mult = source.get("damage_mult")
		if s_d_mult != null:
			d_mult += float(s_d_mult)
		
	dmg *= (1.0 + d_mult)
		
	if is_instance_valid(GameManager):
		if GameManager.has_method("get_global_stat"):
			dmg += GameManager.get_global_stat("global_flat_damage", 0.0)
			
	# Hook for dynamic overrides (e.g. Picasso variable damage)
	if "active_weapon_item" in source and source.active_weapon_item:
		var artifact = source.active_weapon_item.get_artifact_instance()
		if artifact and artifact.has_method("modify_damage"):
			dmg = artifact.modify_damage(dmg, source, atk)
		
	return dmg

func _spawn_visuals(source: Node3D, target: Node3D, t_pos: Vector3) -> void:
	if not current_attack.visual_scene: return
	
	var vis = current_attack.visual_scene.instantiate()
	var target_valid = is_instance_valid(target)
	var final_t_pos = target.global_position if target_valid else t_pos
	
	if current_attack.attach_visual_to_source and current_attack.visual_spawn_point == 0:
		source.add_child(vis)
		vis.position = current_attack.visual_offset
	else:
		get_tree().root.add_child(vis)
		var pos = source.global_position
		match current_attack.visual_spawn_point:
			0: pos = source.global_position
			1: pos = final_t_pos
			2: pos = source.global_position.lerp(final_t_pos, 0.5)
		vis.global_position = pos + current_attack.visual_offset
	
	if current_attack.visual_spawn_point == 0:
		if not current_attack.attach_visual_to_source and final_t_pos != Vector3.INF:
			vis.look_at(Vector3(final_t_pos.x, vis.global_position.y, final_t_pos.z), Vector3.UP)
		
	if current_attack.visual_duration > 0 and not vis.has_method("_on_finished"):
		get_tree().create_timer(current_attack.visual_duration).timeout.connect(func(): if is_instance_valid(vis): vis.queue_free())

func _spawn_projectile(source: Node, damage: float, atk: AttackResource, ammo_item: ItemResource = null) -> void:
	var proj = null
	
	# Prefer projectile scenes specific to the Ammo Item (e.g., customized Folds)
	if ammo_item and ammo_item.projectile_scene:
		proj = ammo_item.projectile_scene.instantiate()
	elif atk and atk.projectile_scene:
		proj = atk.projectile_scene.instantiate()
	else:
		var default_proj = load("res://scenes/entities/projectile.tscn")
		if default_proj:
			proj = default_proj.instantiate()
		else:
			return
			
	get_tree().root.add_child(proj)
	
	var target_valid = is_instance_valid(current_target)
	var dest = current_target.global_position if target_valid else current_target_pos
	
	var dir = Vector3.FORWARD
	if current_target_dir != Vector3.ZERO:
		dir = current_target_dir.normalized()
	elif dest != Vector3.INF:
		dir = (dest - source.global_position).normalized()
	
	var start_pos = source.global_position + Vector3(0, 0.5, 0)
	if source.has_node("ProjectileOrigin"):
		start_pos = source.get_node("ProjectileOrigin").global_position
	elif source.has_node("Rotatable/ProjectileOrigin"):
		start_pos = source.get_node("Rotatable/ProjectileOrigin").global_position
	
	var tex = atk.get("projectile_texture") if atk != null else null
	var col = atk.projectile_color if atk != null else Color.WHITE
	var elem = atk.element if atk != null else null
	var units = atk.element_units if atk != null else 1
	var ignore_cd = atk.ignore_element_cd if atk != null else false
	
	var params = {
		"source": source,
		"element_units": units,
		"ignore_element_cd": ignore_cd,
		"attack_resource": atk
	}
	
	if ammo_item:
		if ammo_item.icon and tex == null: tex = ammo_item.icon
		if ammo_item.element: elem = ammo_item.element
		col = ammo_item.color
		params["element_units"] = ammo_item.element_units
		params["ignore_element_cd"] = ammo_item.ignore_element_cooldown
		
		# Transfer item modifiers directly to the projectile params (e.g., piercing, sea_borne)
		for k in ammo_item.modifiers.keys():
			params[k] = ammo_item.modifiers[k]

	var atk_speed = atk.projectile_speed if atk != null else 100.0
	
	if proj.has_method("initialize"):
		proj.initialize(start_pos, dir, atk_speed, damage, -1, elem, tex, col, false, params)

func _apply_hit(target: Node, t_pos: Vector3, damage: float, atk: AttackResource, source: Node) -> void:
	var targets_to_hit =[]
	var center_pos = target.global_position if is_instance_valid(target) else t_pos
	if center_pos == Vector3.INF: return # Can't apply hitbox without location
	
	if atk.is_aoe:
		var center_tile = LaneManager.world_to_tile(center_pos)
		var is_source_ally = source.is_in_group("allies") or source.is_in_group("player") or source.is_in_group("core") or source.is_in_group("buildings")
		
		for w in range(-atk.range_width, atk.range_width + 1):
			var tile = center_tile + Vector2i(0, w)
			
			if is_source_ally:
				var enemies = LaneManager.get_enemies_at(tile)
				for e in enemies:
					if e != target and is_instance_valid(e) and not targets_to_hit.has(e):
						targets_to_hit.append(e)
			else:
				var building = LaneManager.get_entity_at(tile, "building")
				if building and building != target and is_instance_valid(building) and not building.is_in_group("clutter") and not targets_to_hit.has(building):
					targets_to_hit.append(building)
				
				var all_allies = get_tree().get_nodes_in_group("allies")
				for a in all_allies:
					if a != target and is_instance_valid(a) and not targets_to_hit.has(a):
						if LaneManager.world_to_tile(a.global_position) == tile:
							targets_to_hit.append(a)
		if is_instance_valid(target) and not targets_to_hit.has(target):
			targets_to_hit.append(target)
	elif atk.hitbox_extents != Vector3.ZERO:
		var space_state = source.get_world_3d().direct_space_state
		var query = PhysicsShapeQueryParameters3D.new()
		var shape = BoxShape3D.new()
		shape.size = atk.hitbox_extents
		query.shape = shape
		query.transform = Transform3D(Basis(), center_pos + Vector3(0, atk.hitbox_extents.y / 2.0, 0))
		query.collision_mask = 2 if (source.is_in_group("allies") or source.is_in_group("player")) else 5
		var results = space_state.intersect_shape(query)
		for res in results:
			var col = res.collider
			if is_instance_valid(col) and not targets_to_hit.has(col) and col != source:
				targets_to_hit.append(col)
		if is_instance_valid(target) and not targets_to_hit.has(target):
			targets_to_hit.append(target)
	else:
		if is_instance_valid(target):
			targets_to_hit.append(target)
							
	if show_debug_hitboxes:
		_spawn_debug_hitbox(center_pos, atk)
	
	for t in targets_to_hit:
		if not is_instance_valid(t): continue
		
		if atk.element:
			ElementManager.apply_element(t, atk.element, source, damage, atk.element_units, atk.ignore_element_cd)
		
		if t.has_method("take_damage"):
			t.take_damage(damage, atk.element, source)
		elif t.has_node("HealthComponent"):
			t.get_node("HealthComponent").take_damage(damage, atk.element, source)
			
		if "active_weapon_item" in source and source.active_weapon_item:
			var artifact = source.active_weapon_item.get_artifact_instance()
			if artifact and artifact.has_method("on_attack"):
				artifact.on_attack(source, t, source.active_weapon_item, damage)
		
		emit_signal("attacked", t, damage)

func _spawn_debug_hitbox(target_pos: Vector3, atk: AttackResource) -> void:
	if not Engine.has_singleton("LaneManager") and not get_tree().root.has_node("LaneManager"): return
	var mesh_inst = MeshInstance3D.new()
	var box = BoxMesh.new()
	
	if atk.is_aoe:
		var s = LaneManager.GRID_SCALE if "GRID_SCALE" in LaneManager else 2.0
		var width = (atk.range_width * 2 + 1) * s
		box.size = Vector3(s, 1.0, width)
	elif atk.hitbox_extents != Vector3.ZERO:
		box.size = atk.hitbox_extents
	else:
		box.size = Vector3(0.5, 0.5, 0.5)
		
	mesh_inst.mesh = box
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.2, 0.2, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_inst.material_override = mat
	
	get_tree().root.add_child(mesh_inst)
	
	if atk.is_aoe:
		var tile = LaneManager.world_to_tile(target_pos)
		var tile_center = LaneManager.tile_to_world(tile)
		tile_center.y = target_pos.y + 0.5
		mesh_inst.global_position = tile_center
	else:
		var offset_y = (atk.hitbox_extents.y / 2.0) if atk.hitbox_extents != Vector3.ZERO else 0.5
		mesh_inst.global_position = target_pos + Vector3(0, offset_y, 0)
		
	var tween = create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.3)
	tween.tween_callback(mesh_inst.queue_free)
