extends Node

## Reusable component logic separating calculation and visual spawning from state logic

signal attacked(target, damage)

func _get_source_forward(source: Node3D) -> Vector3:
	if not is_instance_valid(source): return Vector3.FORWARD
	if "facing_direction" in source:
		return source.facing_direction.normalized()
	elif "output_direction" in source:
		match int(source.get("output_direction")):
			0: return Vector3(0, 0, 1)
			1: return Vector3(-1, 0, 0)
			2: return Vector3(0, 0, -1)
			3: return Vector3(1, 0, 0)
	return -source.global_transform.basis.z.normalized()

func calculate_damage(source: Node, atk: AttackResource) -> float:
	# --- LIGHT BLIND MECHANIC ---
	var ec = source.get_node_or_null("ElementalComponent")
	if ec and ec.has_element("light"):
		var miss_chance = source.get_meta("light_miss_chance") if source.has_meta("light_miss_chance") else 5.0
		if randf() * 100.0 < miss_chance:
			return 0.0 # Miss!
			
	var dmg = atk.base_damage
	var stat_val = 0.0
	
	if atk.scaling_stat != "":
		if source.has_method("get_stat"):
			stat_val = source.get_stat(atk.scaling_stat, 0.0)
			
	dmg += (stat_val * atk.scaling_factor)
	
	var d_mult = 0.0
	if source.has_method("get_stat"):
		d_mult = source.get_stat("damage_mult", 0.0)
		
	dmg *= (1.0 + d_mult)
		
	if get_tree().root.has_node("GameManager"):
		if GameManager.has_method("get_global_stat"):
			dmg += GameManager.get_global_stat("global_flat_damage", 0.0)
			
	if "active_weapon_item" in source and source.active_weapon_item:
		var artifact = source.active_weapon_item.get_artifact_instance()
		if artifact and artifact.has_method("modify_damage"):
			dmg = artifact.modify_damage(dmg, source, atk)
			
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

func spawn_visuals(source: Node3D, target: Node3D, t_pos: Vector3, atk: AttackResource) -> void:
	if not atk.visual_scene: return
	
	var vis = atk.visual_scene.instantiate()
	var target_valid = is_instance_valid(target)
	var final_t_pos = target.global_position if target_valid else t_pos
	var start_pos = source.global_position if is_instance_valid(source) else final_t_pos
	
	if atk.attach_visual_to_source and atk.visual_spawn_point == 0:
		if is_instance_valid(source):
			source.add_child(vis)
			vis.position = atk.visual_offset
		else:
			get_tree().root.add_child(vis)
			vis.global_position = final_t_pos + atk.visual_offset
	else:
		get_tree().root.add_child(vis)
		var pos = start_pos
		match atk.visual_spawn_point:
			0: pos = start_pos
			1: pos = final_t_pos
			2: pos = (start_pos.lerp(final_t_pos, 0.5))
		vis.global_position = pos + atk.visual_offset
	
	if atk.orient_to_source_direction and is_instance_valid(source) and source is Node3D:
		var fwd = _get_source_forward(source)
		if fwd.length_squared() > 0.001:
			vis.global_basis = Basis.looking_at(fwd.normalized(), Vector3.UP)
		else:
			vis.global_basis = source.global_transform.basis.orthonormalized()
	else:
		if target_valid and final_t_pos != vis.global_position:
			var look_dir = final_t_pos - vis.global_position
			look_dir.y = 0
			if look_dir.length_squared() > 0.001:
				vis.look_at(final_t_pos, Vector3.UP)
		elif t_pos != Vector3.INF and t_pos != vis.global_position:
			var look_dir = t_pos - vis.global_position
			look_dir.y = 0
			if look_dir.length_squared() > 0.001:
				vis.global_basis = Basis.looking_at(look_dir.normalized(), Vector3.UP)
		else:
			vis.global_basis = Basis.looking_at(Vector3.RIGHT, Vector3.UP)
		
	var size_mult = 1.0
	if is_instance_valid(source) and source.has_method("get_stat"):
		size_mult = source.get_stat("scale", 1.0)
	vis.scale = Vector3(size_mult, size_mult, size_mult)

	if atk.visual_duration > 0 and not vis.has_method("_on_finished"):
		get_tree().create_timer(atk.visual_duration).timeout.connect(func(): if is_instance_valid(vis): vis.queue_free())

func spawn_projectile(source: Node, target: Node, t_pos: Vector3, t_dir: Vector3, damage: float, atk: AttackResource, ammo_item: Resource = null) -> void:
	var proj = null
	
	if ammo_item and ammo_item.get("projectile_scene"):
		proj = ammo_item.get("projectile_scene").instantiate()
	elif atk and atk.projectile_scene:
		proj = atk.projectile_scene.instantiate()
	else:
		var default_proj = load("res://scenes/entities/projectile.tscn")
		if default_proj: proj = default_proj.instantiate()
		else: return
			
	get_tree().root.add_child(proj)
	
	var start_pos = t_pos
	if is_instance_valid(source):
		start_pos = source.global_position + Vector3(0, 0.5, 0)
		if source.has_node("ProjectileOrigin"): start_pos = source.get_node("ProjectileOrigin").global_position
		elif source.has_node("Rotatable/ProjectileOrigin"): start_pos = source.get_node("Rotatable/ProjectileOrigin").global_position
		
	var dest = target.global_position if is_instance_valid(target) else t_pos
	var dir = Vector3.FORWARD
	
	var rotates = false
	if atk and "orient_to_source_direction" in atk:
		rotates = atk.orient_to_source_direction
	elif atk and atk.has_meta("rotates_with_source"):
		rotates = atk.get_meta("rotates_with_source")
		
	if rotates and is_instance_valid(source) and source is Node3D:
		var fwd = _get_source_forward(source)
		if fwd.length_squared() > 0.001:
			dir = fwd.normalized()
	elif t_dir != Vector3.ZERO:
		dir = t_dir.normalized()
	elif dest != Vector3.INF and is_instance_valid(source):
		dir = (dest - source.global_position).normalized()
	
	var tex = atk.get("projectile_texture") if atk != null else null
	var col = atk.projectile_color if atk != null else Color.WHITE
	var elem = atk.element if atk != null else null
	var units = atk.element_units if atk != null else 1
	var ignore_cd = atk.ignore_element_cd if atk != null else false
	
	var size_mult = 1.0
	if is_instance_valid(source) and source.has_method("get_stat"):
		size_mult = source.get_stat("scale", 1.0)
	proj.scale = Vector3(size_mult, size_mult, size_mult)
	
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
			for k in mods.keys(): params[k] = mods[k]

	var atk_speed = atk.projectile_speed if atk != null else 100.0
	if proj.has_method("initialize"):
		proj.initialize(start_pos, dir, atk_speed, damage, -1, elem, tex, col, false, params)

func apply_hit(source: Node, target: Node, t_pos: Vector3, damage: float, atk: AttackResource, show_debug: bool) -> void:
	if damage < 0.0: damage = 0.0 # Clamp negative damage but allow 0 damage attacks to pass for elements/hitboxes
	
	var targets_to_hit =[]
	var source_valid = is_instance_valid(source) and source.is_inside_tree()
	var center_pos = source.global_position if (source_valid and source is Node3D) else t_pos
	if center_pos == Vector3.INF: return
	
	var hit_tiles =[]
	
	var rotates = false
	if "orient_to_source_direction" in atk:
		rotates = atk.orient_to_source_direction
	elif atk.has_meta("rotates_with_source"):
		rotates = atk.get_meta("rotates_with_source")
		
	var targets_b = false
	if atk.has_meta("targets_buildings"):
		targets_b = atk.get_meta("targets_buildings")
		
	var is_source_ally = source_valid and (source.is_in_group("allies") or source.is_in_group("player") or source.is_in_group("core") or source.is_in_group("buildings"))
	
	if atk.is_aoe:
		var center_tile = LaneManager.world_to_tile(center_pos)
		
		if not atk.custom_aoe_tiles.is_empty():
			var fx = 1
			var fz = 0
			if rotates and source_valid and source is Node3D:
				var fwd = _get_source_forward(source)
				if abs(fwd.x) > abs(fwd.z):
					fx = sign(fwd.x); fz = 0
				else:
					fx = 0; fz = sign(fwd.z)
			else:
				fx = 1 if is_source_ally else -1
				fz = 0
					
			for offset in atk.custom_aoe_tiles:
				var r = offset.y # forward/depth
				var w = offset.x # right/width
				var world_x = r * fx - w * fz
				var world_z = r * fz + w * fx
				hit_tiles.append(center_tile + Vector2i(world_x, world_z))
		else:
			var dir_x = 1 if is_source_ally else -1
			var dir_z = 0
			
			if rotates and source_valid and source is Node3D:
				var fwd = _get_source_forward(source)
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
		var size_mult = 1.0
		if source_valid and source.has_method("get_stat"):
			size_mult = source.get_stat("scale", 1.0)
			
		var space_node = source if source_valid else get_tree().root
		var space_state = space_node.get_world_3d().direct_space_state if space_node.is_inside_tree() else null
		if space_state:
			var query = PhysicsShapeQueryParameters3D.new()
			var shape = BoxShape3D.new()
			shape.size = atk.hitbox_extents * size_mult
			query.shape = shape
			
			var start_pos = source.global_position if (source_valid and source is Node3D) else center_pos
			var basis = Basis()
			
			if rotates and source_valid and source is Node3D:
				var fwd = _get_source_forward(source)
				if fwd.length_squared() > 0.001:
					basis = Basis.looking_at(fwd.normalized(), Vector3.UP)
				else:
					basis = source.global_transform.basis.orthonormalized()
			else:
				if not is_source_ally:
					basis = basis.rotated(Vector3.UP, PI)
					
			var source_transform = Transform3D(basis, start_pos)
			var local_offset_transform = Transform3D(Basis(), Vector3(atk.hitbox_offset.x * size_mult, (atk.hitbox_extents.y * size_mult) / 2.0 + atk.hitbox_offset.y * size_mult, -(atk.hitbox_extents.z * size_mult) / 2.0 + atk.hitbox_offset.z * size_mult))
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
							
	if show_debug:
		_spawn_debug_hitbox(center_pos, atk, source, hit_tiles)
		
	if get_tree().root.has_node("GameManager"):
		var gm = get_tree().root.get_node("GameManager")
		if gm.get("vfx_manager"):
			gm.vfx_manager.play_vfx("attack", center_pos, target.global_position if is_instance_valid(target) else Vector3.INF)
		
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

	var size_mult = 1.0
	if source_valid and source.has_method("get_stat"):
		size_mult = source.get_stat("scale", 1.0)

	if atk.is_aoe:
		var s = LaneManager.GRID_SCALE if "GRID_SCALE" in LaneManager else 2.0
		for tile in hit_tiles:
			var mesh_inst = MeshInstance3D.new()
			var box = BoxMesh.new()
			box.size = Vector3(s * 0.95, 1.0, s * 0.95)
			mesh_inst.mesh = box
			get_tree().root.add_child(mesh_inst) 
			
			var tile_center = LaneManager.tile_to_world(tile)
			tile_center.y = target_pos.y + 0.5
			mesh_inst.global_position = tile_center
			meshes_to_spawn.append(mesh_inst)
			
	elif atk.hitbox_extents != Vector3.ZERO:
		var mesh_inst = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = atk.hitbox_extents * 0.95 * size_mult
		mesh_inst.mesh = box
		get_tree().root.add_child(mesh_inst)
		
		var start_pos = target_pos
		var basis = Basis()
		
		var rotates = false
		if "orient_to_source_direction" in atk:
			rotates = atk.orient_to_source_direction
		elif atk.has_meta("rotates_with_source"):
			rotates = atk.get_meta("rotates_with_source")
			
		var is_ally = false
		if source_valid:
			is_ally = source.is_in_group("allies") or source.is_in_group("player") or source.is_in_group("core") or source.is_in_group("buildings")
			
		if rotates and source_valid and source is Node3D:
			var fwd = _get_source_forward(source)
			if fwd.length_squared() > 0.001:
				basis = Basis.looking_at(fwd.normalized(), Vector3.UP)
			else:
				basis = source.global_transform.basis.orthonormalized()
			start_pos = source.global_position
		else:
			if not is_ally:
				basis = basis.rotated(Vector3.UP, PI)
				
		var source_transform = Transform3D(basis, start_pos)
		var local_offset_transform = Transform3D(Basis(), Vector3(atk.hitbox_offset.x * size_mult, (atk.hitbox_extents.y * size_mult) / 2.0 + atk.hitbox_offset.y * size_mult, -(atk.hitbox_extents.z * size_mult) / 2.0 + atk.hitbox_offset.z * size_mult))
		mesh_inst.global_transform = source_transform * local_offset_transform
		
		meshes_to_spawn.append(mesh_inst)
		
	else:
		var mesh_inst = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(0.45 * size_mult, 0.45 * size_mult, 0.45 * size_mult)
		mesh_inst.mesh = box
		get_tree().root.add_child(mesh_inst)
		
		mesh_inst.global_position = target_pos + Vector3(0, 0.5, 0)
		meshes_to_spawn.append(mesh_inst)
		
	for mesh_inst in meshes_to_spawn:
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.2, 0.2, 0.5)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.render_priority = 11
		mesh_inst.material_override = mat
		
		var tween = mesh_inst.create_tween()
		tween.tween_property(mat, "albedo_color:a", 0.0, 0.3)
		tween.tween_callback(mesh_inst.queue_free)
