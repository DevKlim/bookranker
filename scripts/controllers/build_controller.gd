class_name BuildController extends Node

var main: Node3D
var _last_build_time: int = 0
var _last_build_coord: Vector2i = Vector2i(-1, -1)
var _hovered_for_deletion: Node = null

func setup(main_node: Node3D) -> void:
	main = main_node
	BuildManager.build_mode_changed.connect(_on_build_state_changed)
	BuildManager.selected_buildable_changed.connect(_on_build_state_changed)
	BuildManager.build_rotation_changed.connect(_on_build_rotation_changed)

func update(mouse_world_pos: Vector3) -> void:
	if BuildManager.is_building:
		update_build_preview(mouse_world_pos)
		_handle_delete_highlight(mouse_world_pos)
		
		if not main.is_mouse_over_ui():
			var cell = BuildManager.get_grid_cell(mouse_world_pos)
			var current_coord = Vector2i(cell.x, cell.z)
			if Input.is_action_just_pressed("build_place"):
				_perform_build(mouse_world_pos, current_coord)
			elif Input.is_action_pressed("build_place"):
				var cooldown_ok = (Time.get_ticks_msec() - _last_build_time > main.build_cooldown_ms)
				var moved_tile = (current_coord != _last_build_coord)
				if cooldown_ok or moved_tile:
					_perform_build(mouse_world_pos, current_coord)
	else:
		_clear_delete_highlight()
		
	_update_arrow_indicator()

func _perform_build(pos: Vector3, coord: Vector2i) -> void:
	_last_build_time = Time.get_ticks_msec()
	_last_build_coord = coord
	BuildManager.place_buildable(pos)

func _on_build_state_changed(_arg = null) -> void:
	_clear_preview()
	_clear_delete_highlight()
	main.selection_controller.deselect_all()
	main.game_ui.hide_network_stats()
	
	if BuildManager.is_building and BuildManager.selected_buildable:
		main.build_preview_container.visible = true
		var buildable = BuildManager.selected_buildable
		if buildable.scene:
			var temp = buildable.scene.instantiate()
			temp.process_mode = Node.PROCESS_MODE_DISABLED
			temp.set_meta("is_preview", true)
			main.build_preview_container.add_child(temp)
			if temp.has_method("set_build_rotation"): temp.set_build_rotation(BuildManager.current_rotation_index)
		elif buildable.layer == BuildableResource.BuildLayer.TOOL:
			var s = Sprite3D.new()
			s.texture = buildable.icon; s.axis = Vector3.AXIS_Y; s.pixel_size = 0.03; s.modulate = Color(1, 0.5, 0.5, 0.7)
			s.render_priority = 10 # Fixes ordering against screen-space shaders
			main.build_preview_container.add_child(s)

func _clear_preview() -> void:
	for child in main.build_preview_container.get_children(): child.queue_free()
	main.build_preview_container.visible = false

func _on_build_rotation_changed(rotation_val: Variant) -> void:
	if main.build_preview_container.get_child_count() > 0:
		var preview_node = main.build_preview_container.get_child(0)
		if is_instance_valid(preview_node) and preview_node.has_method("set_build_rotation"):
			preview_node.set_build_rotation(rotation_val)

func update_build_preview(world_pos: Vector3):
	if main.is_mouse_over_ui():
		main.build_preview_container.visible = false; return
	var buildable = BuildManager.selected_buildable
	if not buildable: return
	main.build_preview_container.visible = true
	var cell = BuildManager.get_grid_cell(world_pos)
	var tile_pos = LaneManager.tile_to_world(Vector2i(cell.x, cell.z))
	var layer_name = "building"
	if buildable.layer == BuildableResource.BuildLayer.WIRING: layer_name = "wire"
	var layer_offset = LaneManager.get_layer_offset(layer_name)
	var final_pos = tile_pos + layer_offset
	var display_offset_3d = Vector3(buildable.display_offset.x, buildable.display_offset.y, 0)
	main.build_preview_container.global_position = final_pos + display_offset_3d
	var can_build = BuildManager.can_build_at(world_pos)
	var tint = Color(0.4, 1.0, 0.4, 0.6) if can_build else Color(1.0, 0.4, 0.4, 0.6)
	
	if buildable.layer == BuildableResource.BuildLayer.TOOL:
		var has_target = BuildManager.has_removable_at(world_pos)
		for c in main.build_preview_container.get_children():
			if c is Sprite3D: c.modulate = Color(1, 0.5, 0.5, 0.7) if has_target else Color(0.5, 0.5, 0.5, 0.5)
	else:
		if main.build_preview_container.get_child_count() > 0:
			var preview_node = main.build_preview_container.get_child(0)
			_apply_ghost_visuals(preview_node, tint)
			if preview_node.has_method("update_preview_visuals"): preview_node.update_preview_visuals()

func _apply_ghost_visuals(node: Node, color_tint: Color) -> void:
	if not is_instance_valid(node): return
	if node is MeshInstance3D and node.mesh:
		var surface_count = node.mesh.get_surface_count()
		for i in range(surface_count):
			var source_mat = node.get_active_material(i)
			if not source_mat: source_mat = node.mesh.surface_get_material(i)
			var target_mat = null
			var existing_override = node.get_surface_override_material(i)
			if existing_override and existing_override.has_meta("is_ghost"): target_mat = existing_override
			else:
				target_mat = source_mat.duplicate() if source_mat else StandardMaterial3D.new()
				target_mat.set_meta("is_ghost", true)
			if target_mat is StandardMaterial3D:
				target_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; target_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; target_mat.albedo_color = color_tint
				target_mat.render_priority = 10 # Fixes ordering against screen-space shaders
			node.set_surface_override_material(i, target_mat)
			
	for child in node.get_children(): _apply_ghost_visuals(child, color_tint)

func _handle_delete_highlight(world_pos: Vector3) -> void:
	if not BuildManager.is_building or not BuildManager.selected_buildable or BuildManager.selected_buildable.layer != BuildableResource.BuildLayer.TOOL:
		_clear_delete_highlight(); return
	var cell = BuildManager.get_grid_cell(world_pos)
	var tile = Vector2i(cell.x, cell.z)
	
	var target = null
	if BuildManager.current_remove_mode == BuildManager.RemoveMode.ALL or BuildManager.current_remove_mode == BuildManager.RemoveMode.BUILDING_ONLY:
		target = BuildManager.get_mech_at(tile)
	
	if not target and (BuildManager.current_remove_mode == BuildManager.RemoveMode.ALL or BuildManager.current_remove_mode == BuildManager.RemoveMode.WIRE_ONLY):
		target = BuildManager.wiring_manager.get_wire_instance(tile)
		
	if target != _hovered_for_deletion:
		_clear_delete_highlight()
		_hovered_for_deletion = target
		if is_instance_valid(_hovered_for_deletion): _highlight_node_tree(_hovered_for_deletion, Color(1, 0.3, 0.3, 1))

func _highlight_node_tree(node: Node, col: Color):
	if not is_instance_valid(node): return
	if node is CanvasItem: node.modulate = col
	for child in node.get_children(): _highlight_node_tree(child, col)

func _clear_delete_highlight() -> void:
	if is_instance_valid(_hovered_for_deletion):
		_highlight_node_tree(_hovered_for_deletion, Color.WHITE)
		if _hovered_for_deletion.has_method("_on_power_status_changed") and "is_active" in _hovered_for_deletion:
			_hovered_for_deletion._on_power_status_changed(_hovered_for_deletion.is_active)
	_hovered_for_deletion = null

func _update_arrow_indicator() -> void:
	if not main.is_inside_tree() or not is_instance_valid(main.indicator_container) or not main.indicator_container.is_inside_tree(): return 
	
	for child in main.indicator_container.get_children(): child.queue_free()
	
	var pivot_world_pos = Vector3.ZERO
	var show_arrows = false
	var input_mask = 0; var output_mask = 0
	var current_layout: Array[Vector2i] =[Vector2i.ZERO]
	var is_preview_mode = false; var rotation_index = 0
	
	if BuildManager.is_building and main.build_preview_container.visible and BuildManager.selected_buildable:
		if not main.build_preview_container.is_inside_tree(): return
		if BuildManager.selected_buildable.layer == BuildableResource.BuildLayer.MECH:
			is_preview_mode = true
			pivot_world_pos = main.build_preview_container.global_position
			var vo = BuildManager.selected_buildable.display_offset
			pivot_world_pos -= Vector3(vo.x, vo.y, 0)
			show_arrows = true
			var res = BuildManager.selected_buildable
			rotation_index = BuildManager.current_rotation_index
			if res.has_input: input_mask = res.default_input_mask
			if res.has_output: output_mask = res.default_output_mask
			var shift = (rotation_index + 2) % 4
			input_mask = _rotate_bitmask(input_mask, shift)
			output_mask = _rotate_bitmask(output_mask, shift)
			current_layout = BuildManager.get_current_layout()

	elif main.selection_controller.selected_mech_coords != Vector2i(-1, -1):
		var mech = BuildManager.get_mech_at(main.selection_controller.selected_mech_coords)
		if is_instance_valid(mech):
			pivot_world_pos = LaneManager.tile_to_world(main.selection_controller.selected_mech_coords) + LaneManager.get_layer_offset("building")
			show_arrows = true
			if mech.get("has_input") and "input_mask" in mech: input_mask = mech.input_mask
			if mech.get("has_output") and "output_mask" in mech: output_mask = mech.output_mask
			if mech.has_method("get_occupied_cells"): current_layout = mech.get_occupied_cells()
		else:
			main.selection_controller.selected_mech_coords = Vector2i(-1, -1)

	if show_arrows:
		var height_offset = Vector3(0, 0.8, 0)
		if is_preview_mode:
			var dir_indicator = _create_direction_indicator()
			main.indicator_container.add_child(dir_indicator)
			var forward_offset = Vector3.ZERO; var y_rot = 0.0
			match rotation_index:
				0: 
					forward_offset = Vector3(0, 0, 1.2); y_rot = deg_to_rad(180)
				1: 
					forward_offset = Vector3(-1.2, 0, 0); y_rot = deg_to_rad(90)
				2: 
					forward_offset = Vector3(0, 0, -1.2); y_rot = 0
				3: 
					forward_offset = Vector3(1.2, 0, 0); y_rot = deg_to_rad(-90)
			dir_indicator.global_position = pivot_world_pos + height_offset + forward_offset
			dir_indicator.rotation.y = y_rot

		var internal_set = {} 
		for offset in current_layout: internal_set[offset] = true
		for offset in current_layout:
			var block_world_pos = pivot_world_pos + Vector3(offset.x * LaneManager.GRID_SCALE, 0, offset.y * LaneManager.GRID_SCALE)
			for i in range(4):
				var neighbor_offset = offset
				match i:
					0: neighbor_offset += Vector2i(0, 1)
					1: neighbor_offset += Vector2i(-1, 0)
					2: neighbor_offset += Vector2i(0, -1)
					3: neighbor_offset += Vector2i(1, 0)
				if internal_set.has(neighbor_offset): continue
				var is_in = (input_mask & (1 << i)) != 0
				var is_out = (output_mask & (1 << i)) != 0
				if is_in or is_out:
					if is_in and is_out:
						var sep_offset = 0.15; var side_vec = Vector3.ZERO
						match i:
							0: side_vec = Vector3(-sep_offset, 0, 0) 
							1: side_vec = Vector3(0, 0, -sep_offset) 
							2: side_vec = Vector3(sep_offset, 0, 0)  
							3: side_vec = Vector3(0, 0, sep_offset)  
						var in_arrow = _create_arrow_mesh(Color(1.0, 0.2, 0.2, 0.8))
						main.indicator_container.add_child(in_arrow)
						_apply_arrow_transform(in_arrow, block_world_pos + height_offset - side_vec, i, true)
						var out_arrow = _create_arrow_mesh(Color(0.2, 1.0, 0.2, 0.8))
						main.indicator_container.add_child(out_arrow)
						_apply_arrow_transform(out_arrow, block_world_pos + height_offset + side_vec, i, false)
					elif is_in:
						var ind = _create_arrow_mesh(Color(1.0, 0.2, 0.2, 0.8)); main.indicator_container.add_child(ind)
						_apply_arrow_transform(ind, block_world_pos + height_offset, i, true)
					elif is_out:
						var ind = _create_arrow_mesh(Color(0.2, 1.0, 0.2, 0.8)); main.indicator_container.add_child(ind)
						_apply_arrow_transform(ind, block_world_pos + height_offset, i, false)

func _rotate_bitmask(mask: int, steps: int) -> int:
	var result = 0
	for i in range(4):
		if (mask & (1 << i)) != 0:
			var new_pos = (i + steps) % 4
			result |= (1 << new_pos)
	return result

func _apply_arrow_transform(node: Node3D, center_pos: Vector3, dir_idx: int, point_in: bool) -> void:
	var offset = Vector3.ZERO; var y_rot = 0.0
	match dir_idx:
		0: 
			offset = Vector3(0, 0, 0.5); y_rot = deg_to_rad(180) 
		1:
			offset = Vector3(-0.5, 0, 0); y_rot = deg_to_rad(90)
		2:
			offset = Vector3(0, 0, -0.5); y_rot = 0
		3:
			offset = Vector3(0.5, 0, 0); y_rot = deg_to_rad(-90)
	if point_in: y_rot += deg_to_rad(180)
	if main.indicator_container.is_inside_tree(): node.position = main.indicator_container.to_local(center_pos + offset)
	else: node.position = center_pos + offset
	node.rotation.y = y_rot

func _create_arrow_mesh(color: Color) -> Node3D:
	var container = Node3D.new()
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color; mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.render_priority = 10 # Fixes ordering against screen-space shaders
	var prism = PrismMesh.new(); prism.size = Vector3(0.3, 0.3, 0.1) 
	var mesh_inst = MeshInstance3D.new(); mesh_inst.mesh = prism; mesh_inst.material_override = mat; mesh_inst.rotation.x = deg_to_rad(-90)
	container.add_child(mesh_inst)
	return container

func _create_direction_indicator() -> Node3D:
	var container = Node3D.new()
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.8, 0.0, 0.8); mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.render_priority = 10 # Fixes ordering against screen-space shaders
	var prism = PrismMesh.new(); prism.size = Vector3(0.6, 0.6, 0.1)
	var mesh = MeshInstance3D.new(); mesh.mesh = prism; mesh.material_override = mat; mesh.rotation.x = deg_to_rad(-90)
	container.add_child(mesh)
	return container
