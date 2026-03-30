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
var base_active_attack: AttackResource = null

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
	base_active_attack = specific_attack if specific_attack else basic_attack
	current_attack = base_active_attack
	
	if not current_attack: return
	
	if attack_timer.is_stopped():
		_perform_attack()

func start_attacking_position(target_pos: Vector3, specific_attack: AttackResource = null) -> void:
	current_target = null
	current_target_pos = target_pos
	current_target_dir = Vector3.ZERO
	base_active_attack = specific_attack if specific_attack else basic_attack
	current_attack = base_active_attack
	
	if not current_attack: return
	
	if attack_timer.is_stopped():
		_perform_attack()

func start_attacking_direction(dir: Vector3, specific_attack: AttackResource = null) -> void:
	current_target = null
	current_target_pos = Vector3.INF
	current_target_dir = dir
	base_active_attack = specific_attack if specific_attack else basic_attack
	current_attack = base_active_attack
	
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
	var ammo_item: Resource = null
	
	# Ammo override (Allows buildings/resources to act as ammo if supported)
	if source is Node3D and source.has_node("InventoryComponent"):
		var inv = source.get_node("InventoryComponent")
		var is_ammo_user = ("infinite_ammo" in source) or (inv.can_receive and not inv.can_output)
		if is_ammo_user and inv.has_item():
			var first_item = inv.get_first_item()
			if first_item:
				ammo_item = first_item
				var infinite = source.get("infinite_ammo") if "infinite_ammo" in source else false
				if not infinite:
					inv.remove_item(ammo_item, 1)
			
	var base_attack = current_attack
	if ammo_item and ammo_item.get("attack_config"):
		current_attack = ammo_item.get("attack_config")

	var final_damage = _calculate_damage(source, current_attack)
	var safe_target = current_target if target_valid else null
	
	emit_signal("attack_started", safe_target, current_attack)
	_spawn_visuals(source, safe_target, current_target_pos)

	if current_attack.spawn_projectile or ammo_item != null:
		var proj_damage = final_damage
		if ammo_item and "damage" in ammo_item and float(ammo_item.get("damage")) > 0:
			proj_damage += float(ammo_item.get("damage"))
		_spawn_projectile(source, proj_damage, current_attack, ammo_item)
	else:
		_apply_hit(safe_target, current_target_pos, final_damage, current_attack, source)

	if base_attack != current_attack and not base_attack.spawn_projectile:
		var base_dmg = _calculate_damage(source, base_attack)
		_apply_hit(safe_target, current_target_pos, base_dmg, base_attack, source)

	if current_attack.chain_next:
		var next = current_attack.chain_next
		var delay = current_attack.chain_delay
		get_tree().create_timer(delay).timeout.connect(func(): 
			current_attack = next
			_perform_attack()
		)
	else:
		current_attack = base_active_attack
			
	var cd = current_attack.cooldown
	var spd_mult = 0.0
	
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
			
	if "active_weapon_item" in source and source.active_weapon_item:
		var artifact = source.active_weapon_item.get_artifact_instance()
		if artifact and artifact.has_method("modify_cooldown"):
			cd = artifact.modify_cooldown(cd, source, current_attack)
	
	cd /= max(0.1, (1.0 + spd_mult))
	attack_timer.start(cd)

func _calculate_damage(source: Node, atk: AttackResource) -> float:
	var dmg = atk.base_damage
	var stat_val = 0.0
	
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
		
	if get_tree().root.has_node("GameManager"):
		if GameManager.has_method("get_global_stat"):
			dmg += GameManager.get_global_stat("global_flat_damage", 0.0)
			
	if "active_weapon_item" in source and source.active_weapon_item:
		var artifact = source.active_weapon_item.get_artifact_instance()
		if artifact and artifact.has_method("modify_damage"):
			dmg = artifact.modify_damage(dmg, source, atk)
			
	# FORMULA EVALUATION OVERRIDE
	if atk.damage_equation != "":
		var vars = {
			"base_damage": atk.base_damage,
			"damage_mult": d_mult,
			"scaling_stat_val": stat_val,
			"global_flat_damage": GameManager.get_global_stat("global_flat_damage", 0.0) if get_tree().root.has_node("GameManager") else 0.0
		}
		for k in atk.stat_weights.keys():
			vars[k+"_weight"] = atk.stat_weights[k]
			var val = 0.0
			if source.has_method("get_stat"): val = source.get_stat(k, 0.0)
			elif source.get(k) != null: val = float(source.get(k))
			vars[k] = val
		
		if ClassDB.class_exists("FormulaHelper") or ResourceLoader.exists("res://scripts/utils/formula_helper.gd"):
			var fh = load("res://scripts/utils/formula_helper.gd")
			if fh: dmg = fh.evaluate(atk, atk.damage_equation, vars, dmg)
		
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
	
	vis.global_basis = Basis.looking_at(Vector3.RIGHT, Vector3.UP)
		
	if current_attack.visual_duration > 0 and not vis.has_method("_on_finished"):
		get_tree().create_timer(current_attack.visual_duration).timeout.connect(func(): if is_instance_valid(vis): vis.queue_free())

func _spawn_projectile(source: Node, damage: float, atk: AttackResource, ammo_item: Resource = null) -> void:
	var proj = null
	
	if ammo_item and ammo_item.get("projectile_scene"):
		proj = ammo_item.get("projectile_scene").instantiate()
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
		if ammo_item.get("icon") and tex == null: tex = ammo_item.get("icon")
		if ammo_item.get("element"): elem = ammo_item.get("element")
		if "color" in ammo_item: col = ammo_item.get("color")
		if "element_units" in ammo_item: params["element_units"] = int(ammo_item.get("element_units"))
		if "ignore_element_cooldown" in ammo_item: params["ignore_element_cd"] = bool(ammo_item.get("ignore_element_cooldown"))
		
		var mods = ammo_item.get("modifiers")
		if mods and typeof(mods) == TYPE_DICTIONARY:
			for k in mods.keys():
				params[k] = mods[k]

	var atk_speed = atk.projectile_speed if atk != null else 100.0
	
	if proj.has_method("initialize"):
		proj.initialize(start_pos, dir, atk_speed, damage, -1, elem, tex, col, false, params)

func _apply_hit(target: Node, t_pos: Vector3, damage: float, atk: AttackResource, source: Node) -> void:
	var targets_to_hit =[]
	var source_valid = is_instance_valid(source) and source.is_inside_tree()
	var center_pos = source.global_position if (source_valid and source is Node3D) else t_pos
	if center_pos == Vector3.INF: return
	
	var hit_tiles =[]
	var rotates = atk.get("rotates_with_source") == true or (atk.has_meta("rotates_with_source") and atk.get_meta("rotates_with_source"))
	var targets_b = atk.get("targets_buildings") == true or (atk.has_meta("targets_buildings") and atk.get_meta("targets_buildings"))
	var is_source_ally = source_valid and (source.is_in_group("allies") or source.is_in_group("player") or source.is_in_group("core") or source.is_in_group("buildings"))
	
	if atk.is_aoe:
		var center_tile = LaneManager.world_to_tile(center_pos)
		
		if not atk.custom_aoe_tiles.is_empty():
			var fx = 1
			var fz = 0
			if rotates and source_valid and source is Node3D:
				if "output_direction" in source:
					match source.get("output_direction"):
						0: # DOWN (+Z)
							fx = 0; fz = 1
						1: # LEFT (-X)
							fx = -1; fz = 0
						2: # UP (-Z)
							fx = 0; fz = -1
						3: # RIGHT (+X)
							fx = 1; fz = 0
				else:
					var fwd = -source.global_transform.basis.z
					if abs(fwd.x) > abs(fwd.z):
						fx = sign(fwd.x); fz = 0
					else:
						fx = 0; fz = sign(fwd.z)
			else:
				fx = 1 if is_source_ally else -1
				fz = 0
					
			for offset in atk.custom_aoe_tiles:
				var world_x = offset.x * fx - offset.y * fz
				var world_z = offset.x * fz + offset.y * fx
				hit_tiles.append(center_tile + Vector2i(world_x, world_z))
		else:
			var dir_x = 1 if is_source_ally else -1
			var dir_z = 0
			
			if rotates and source_valid and source is Node3D:
				if "output_direction" in source:
					match source.get("output_direction"):
						0: dir_x = 0; dir_z = 1
						1: dir_x = -1; dir_z = 0
						2: dir_x = 0; dir_z = -1
						3: dir_x = 1; dir_z = 0
				else:
					var fwd = -source.global_transform.basis.z
					if abs(fwd.x) > abs(fwd.z):
						dir_x = sign(fwd.x); dir_z = 0
					else:
						dir_x = 0; dir_z = sign(fwd.z)
			
			for r in range(atk.min_range, atk.max_range + 1):
				for w in range(-atk.range_width, atk.range_width + 1):
					var world_x = r * dir_x - w * dir_z
					var world_z = r * dir_z + w * dir_x
					hit_tiles.append(center_tile + Vector2i(world_x, world_z))
		
		for tile in hit_tiles:
			if is_source_ally:
				var enemies = LaneManager.get_enemies_at(tile)
				for e in enemies:
					if e != target and is_instance_valid(e) and not targets_to_hit.has(e):
						targets_to_hit.append(e)
				
				if targets_b:
					var building = LaneManager.get_entity_at(tile, "building")
					if building and is_instance_valid(building) and not building.is_in_group("clutter") and building != source and not targets_to_hit.has(building):
						targets_to_hit.append(building)
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
		var space_node = source if source_valid else get_tree().root
		var space_state = space_node.get_world_3d().direct_space_state if space_node.is_inside_tree() else null
		if space_state:
			var query = PhysicsShapeQueryParameters3D.new()
			var shape = BoxShape3D.new()
			shape.size = atk.hitbox_extents
			query.shape = shape
			
			var start_pos = source.global_position if (source_valid and source is Node3D) else center_pos
			var basis = Basis()
			if rotates and source_valid and source is Node3D:
				basis = source.global_transform.basis.orthonormalized()
			else:
				if not is_source_ally:
					basis = basis.rotated(Vector3.UP, PI)
					
			var source_transform = Transform3D(basis, start_pos)
			var local_offset_transform = Transform3D(Basis(), Vector3(0, atk.hitbox_extents.y / 2.0, -atk.hitbox_extents.z / 2.0))
			query.transform = source_transform * local_offset_transform
			
			query.collision_mask = 2 if is_source_ally else 5
			var results = space_state.intersect_shape(query)
			for res in results:
				var col = res.collider
				if is_instance_valid(col) and not targets_to_hit.has(col) and col != source:
					var is_b = col.is_in_group("buildings")
					if is_b and is_source_ally and not targets_b: continue
					targets_to_hit.append(col)
		if is_instance_valid(target) and not targets_to_hit.has(target):
			targets_to_hit.append(target)
	else:
		if is_instance_valid(target):
			targets_to_hit.append(target)
							
	if show_debug_hitboxes:
		_spawn_debug_hitbox(center_pos, atk, source, hit_tiles)
		
	for t in targets_to_hit:
		if not is_instance_valid(t): continue
		
		if atk.element:
			ElementManager.apply_element(t, atk.element, source if source_valid else null, damage, atk.element_units, atk.ignore_element_cd)
		
		if t.has_method("take_damage"):
			t.take_damage(damage, atk.element, source if source_valid else null)
		elif t.has_node("HealthComponent"):
			t.get_node("HealthComponent").take_damage(damage, atk.element, source if source_valid else null)
			
		if source_valid and "active_weapon_item" in source and source.active_weapon_item:
			var artifact = source.active_weapon_item.get_artifact_instance()
			if artifact and artifact.has_method("on_attack"):
				artifact.on_attack(source, t, source.active_weapon_item, damage)
		
		emit_signal("attacked", t, damage)

func _spawn_debug_hitbox(target_pos: Vector3, atk: AttackResource, source: Node, hit_tiles: Array) -> void:
	if not get_tree().root.has_node("LaneManager"): return
	
	var source_valid = is_instance_valid(source) and source.is_inside_tree()
	var meshes_to_spawn =[]

	if atk.is_aoe:
		var s = LaneManager.GRID_SCALE if "GRID_SCALE" in LaneManager else 2.0
		for tile in hit_tiles:
			var mesh_inst = MeshInstance3D.new()
			var box = BoxMesh.new()
			# Shrink slightly to prevent overlapping faces/z-fighting
			box.size = Vector3(s * 0.95, 1.0, s * 0.95)
			mesh_inst.mesh = box
			get_tree().root.add_child(mesh_inst) # Added to tree BEFORE setting global_position
			
			var tile_center = LaneManager.tile_to_world(tile)
			tile_center.y = target_pos.y + 0.5
			mesh_inst.global_position = tile_center
			meshes_to_spawn.append(mesh_inst)
			
	elif atk.hitbox_extents != Vector3.ZERO:
		var mesh_inst = MeshInstance3D.new()
		var box = BoxMesh.new()
		# Shrink slightly to prevent overlapping faces/z-fighting
		box.size = atk.hitbox_extents * 0.95
		mesh_inst.mesh = box
		get_tree().root.add_child(mesh_inst) # Added to tree BEFORE setting global_transform
		
		var start_pos = target_pos
		var basis = Basis()
		var rotates = atk.get("rotates_with_source") == true or (atk.has_meta("rotates_with_source") and atk.get_meta("rotates_with_source"))
		var is_ally = false
		if source_valid:
			is_ally = source.is_in_group("allies") or source.is_in_group("player") or source.is_in_group("core") or source.is_in_group("buildings")
			
		if rotates and source_valid and source is Node3D:
			basis = source.global_transform.basis.orthonormalized()
			start_pos = source.global_position
		else:
			if not is_ally:
				basis = basis.rotated(Vector3.UP, PI)
				
		var source_transform = Transform3D(basis, start_pos)
		var local_offset_transform = Transform3D(Basis(), Vector3(0, atk.hitbox_extents.y / 2.0, -atk.hitbox_extents.z / 2.0))
		mesh_inst.global_transform = source_transform * local_offset_transform
		
		meshes_to_spawn.append(mesh_inst)
		
	else:
		var mesh_inst = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(0.45, 0.45, 0.45)
		mesh_inst.mesh = box
		get_tree().root.add_child(mesh_inst) # Added to tree BEFORE setting global_position
		
		mesh_inst.global_position = target_pos + Vector3(0, 0.5, 0)
		meshes_to_spawn.append(mesh_inst)
		
	for mesh_inst in meshes_to_spawn:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.2, 0.2, 0.5)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.render_priority = 11
		mesh_inst.material_override = mat
		
		# Bind the tween directly to the mesh_inst instead of the AttackerComponent.
		# This prevents the tween from crashing if the AttackerComponent is freed mid-animation.
		var tween = mesh_inst.create_tween()
		tween.tween_property(mat, "albedo_color:a", 0.0, 0.3)
		tween.tween_callback(mesh_inst.queue_free)
