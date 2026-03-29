class_name SelectionController extends Node

var main: Node3D
var selected_ally = null # CHANGED: Untyped Variant prevents assignment crashes when nodes are freed
var selected_allies: Array =[] 
var selected_mech_coords: Vector2i = Vector2i(-1, -1)
var selected_wire_coords: Vector2i = Vector2i(-1, -1)

var cursor_highlight: MeshInstance3D
var cursor_material: StandardMaterial3D
var selection_indicator: MeshInstance3D

func setup(main_node: Node3D) -> void:
	main = main_node
	
	cursor_highlight = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(1.0, 1.0, 1.0)
	cursor_highlight.mesh = mesh
	
	cursor_material = StandardMaterial3D.new()
	cursor_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cursor_material.albedo_color = Color(0.0, 0.5, 1.0, 0.3)
	cursor_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cursor_material.render_priority = 10 # Fixes ordering against screen-space shaders
	cursor_highlight.material_override = cursor_material
	cursor_highlight.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	main.add_child(cursor_highlight)

	selection_indicator = MeshInstance3D.new()
	var sel_mesh = BoxMesh.new()
	sel_mesh.size = Vector3(1.05, 0.2, 1.05)
	selection_indicator.mesh = sel_mesh
	var sel_mat = StandardMaterial3D.new()
	sel_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sel_mat.albedo_color = Color(1.0, 1.0, 0.0, 0.4)
	sel_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sel_mat.render_priority = 10 # Fixes ordering against screen-space shaders
	selection_indicator.material_override = sel_mat
	selection_indicator.visible = false
	main.add_child(selection_indicator)

func update(selection_ray: Dictionary, terrain_ray: Dictionary, mouse_world_pos: Vector3, cursor_target: Vector3) -> void:
	var cell = BuildManager.get_grid_cell(mouse_world_pos)
	if LaneManager.fog_manager and cell.x >= LaneManager.fog_manager.current_fog_depth:
		cursor_highlight.visible = false
		_update_selection_indicator()
		if Input.is_action_just_pressed("build_place") or Input.is_action_just_pressed("use"):
			deselect_all()
		return

	_update_cursor_highlight(cursor_target)
	_update_selection_indicator()

	if not BuildManager.is_building:
		if Input.is_action_just_pressed("use"):
			if is_instance_valid(selected_ally) and not selected_ally.is_queued_for_deletion() and selected_ally.has_method("activate_mode"):
				selected_ally.activate_mode()
		
		if PlayerManager.equipped_item and PlayerManager.equipped_item.is_tool:
			pass
		else:
			if Input.is_action_just_pressed("build_place"):
				if not main.is_mouse_over_ui():
					var collider = selection_ray.get("collider") if selection_ray else null
					
					# Hard scrub the collider: if it's dead/freed, pretend we didn't click it
					if collider and (not is_instance_valid(collider) or collider.is_queued_for_deletion()):
						collider = null
					
					var clicked_unit = false
					var is_shift_held = Input.is_key_pressed(KEY_SHIFT)
					
					_clean_selected_allies()
					
					if collider and collider == main.player:
						if not is_shift_held: deselect_all()
						
						if not selected_allies.has(main.player):
							selected_allies.append(main.player)
							PlayerManager.is_player_selected = true
							if is_instance_valid(main.player) and main.player.has_method("set_selected"):
								main.player.set_selected(true)
						elif is_shift_held:
							selected_allies.erase(main.player)
							PlayerManager.is_player_selected = false
							if is_instance_valid(main.player) and main.player.has_method("set_selected"):
								main.player.set_selected(false)
						
						if not selected_allies.is_empty():
							selected_ally = selected_allies.back()
							if main.game_ui: main.game_ui.set_selected_ally(selected_ally)
						else:
							selected_ally = null
							if main.game_ui: main.game_ui.set_selected_ally(null)
							
						clicked_unit = true

					elif collider and collider.is_in_group("allies"):
						if not is_shift_held: deselect_all()
						
						if not selected_allies.has(collider):
							selected_allies.append(collider)
							if collider.has_method("set_selected"): collider.set_selected(true)
						elif is_shift_held:
							selected_allies.erase(collider)
							if collider.has_method("set_selected"): collider.set_selected(false)
						
						if not selected_allies.is_empty():
							selected_ally = selected_allies.back()
							if main.game_ui: main.game_ui.set_selected_ally(selected_ally)
							
							if selected_allies.size() == 1:
								if "inventory_component" in selected_ally and selected_ally.inventory_component:
									var d_name = "Ally"
									if "display_name" in selected_ally: d_name = selected_ally.display_name
									elif "ally_name" in selected_ally: d_name = selected_ally.ally_name
									if main.game_ui: main.game_ui.open_inventory(selected_ally.inventory_component, d_name, selected_ally)
						else:
							selected_ally = null
							if main.game_ui: main.game_ui.set_selected_ally(null)
						
						clicked_unit = true
						
					elif collider and collider is Core:
						deselect_all()
						selected_mech_coords = Vector2i(-1, -1)
						if main.game_ui: main.game_ui.open_inventory(collider.mod_inventory, "Core System", collider)
						clicked_unit = true
					
					if not clicked_unit:
						if not is_shift_held:
							var cell2 = BuildManager.get_grid_cell(mouse_world_pos)
							var tile_coord = Vector2i(cell2.x, cell2.z)
							if main.current_layer_mode == main.LayerMode.WIRE_ONLY:
								_handle_wire_click(tile_coord)
								deselect_all()
							else:
								var mech = BuildManager.get_mech_at(tile_coord)
								if mech and is_instance_valid(mech) and not mech.is_queued_for_deletion():
									selected_mech_coords = tile_coord
									deselect_all()
									var inventory = null
									if "inventory_component" in mech: inventory = mech.inventory_component
									if not inventory: inventory = mech.get("inventory")
									if not inventory: inventory = mech.get("input_inventory")
									
									# Even if it lacks a standard inventory, we want to see mods
									if (inventory and inventory is InventoryComponent) or ("mod_inventory" in mech):
										var title = mech.name.rstrip("0123456789")
										if "display_name" in mech and mech.display_name != "": title = mech.display_name
										if main.game_ui: main.game_ui.open_inventory(inventory, title, mech)
									else:
										if main.game_ui: main.game_ui.close_inventory()
								else:
									selected_mech_coords = Vector2i(-1, -1)
									if main.game_ui:
										main.game_ui.close_inventory()
										main.game_ui.hide_network_stats()
									deselect_all()

			elif Input.is_action_just_pressed("build_cancel"):
				if not main.is_mouse_over_ui():
					_clean_selected_allies()
					if not selected_allies.is_empty():
						var cell2 = BuildManager.get_grid_cell(mouse_world_pos)
						var tile_coord = Vector2i(cell2.x, cell2.z)
						if LaneManager.is_valid_tile(tile_coord):
							var target_pos = LaneManager.tile_to_world(tile_coord) 
							
							var entity = LaneManager.get_entity_at(tile_coord, "building")
							if entity is ClutterObject:
								_show_clutter_context_menu(entity)
								return

							for ally in selected_allies:
								if is_instance_valid(ally) and ally.has_method("command_move"):
									ally.command_move(target_pos)
					else:
						if main.game_ui and main.game_ui.is_pause_menu_open(): main.game_ui.toggle_pause_menu()
						elif main.game_ui and main.game_ui.is_any_menu_open():
							main.game_ui.close_all_menus()
							if selected_mech_coords != Vector2i(-1, -1): selected_mech_coords = Vector2i(-1, -1)

func _clean_selected_allies() -> void:
	var valid_allies =[]
	for a in selected_allies:
		if is_instance_valid(a) and not a.is_queued_for_deletion():
			valid_allies.append(a)
	selected_allies = valid_allies
	
	if selected_ally and (not is_instance_valid(selected_ally) or selected_ally.is_queued_for_deletion()):
		selected_ally = null

func _update_cursor_highlight(world_pos: Vector3) -> void:
	if not main.grid_map or main.is_mouse_over_ui():
		cursor_highlight.visible = false
		return
	
	var cell = BuildManager.get_grid_cell(world_pos)
	if cell.x < 0:
		cursor_highlight.visible = false
		return
		
	var tile_pos = LaneManager.tile_to_world(Vector2i(cell.x, cell.z))
	var y_offset = 1.5 
	var target_color = Color(0.0, 0.5, 1.0, 0.3)
	
	if BuildManager.is_building and BuildManager.selected_buildable:
		if BuildManager.selected_buildable.layer == BuildableResource.BuildLayer.WIRING: y_offset = 0.5 
	elif main.current_layer_mode == main.LayerMode.WIRE_ONLY: y_offset = 0.5
	
	if PlayerManager.equipped_item and PlayerManager.equipped_item.is_tool:
		var item = PlayerManager.equipped_item
		var h_offset = item.highlight_offset
		y_offset = 0.1 + h_offset.y
		tile_pos += Vector3(h_offset.x, 0, h_offset.z)
		if main.has_node("ToolManager") and main.get_node("ToolManager").has_mineable_at(world_pos):
			target_color = Color(0.4, 1.0, 0.4, 0.6)
		else:
			target_color = Color(1.0, 0.4, 0.4, 0.6)
			
	cursor_material.albedo_color = target_color
	cursor_highlight.global_position = tile_pos + Vector3(0, y_offset, 0) 
	cursor_highlight.visible = true

func _update_selection_indicator() -> void:
	if main.current_layer_mode == main.LayerMode.WIRE_ONLY and selected_wire_coords != Vector2i(-1, -1):
		selection_indicator.visible = true
		var tile_pos = LaneManager.tile_to_world(selected_wire_coords)
		selection_indicator.global_position = tile_pos + Vector3(0, 0.1, 0)
	else:
		selection_indicator.visible = false

func _handle_wire_click(tile_coord: Vector2i) -> void:
	var has_wire = WiringManager.has_wire(tile_coord)
	if has_wire:
		selected_wire_coords = tile_coord
		var stats = WiringManager.get_network_stats(tile_coord)
		if main.game_ui: main.game_ui.show_network_stats(stats)
	else:
		selected_wire_coords = Vector2i(-1, -1)
		if main.game_ui: main.game_ui.hide_network_stats()

func deselect_all() -> void:
	PlayerManager.is_player_selected = false
	_clean_selected_allies()
	for ally in selected_allies:
		if is_instance_valid(ally) and not ally.is_queued_for_deletion():
			if ally.has_method("set_selected"):
				ally.set_selected(false)
	
	selected_allies.clear()
	selected_ally = null
	
	if main.game_ui:
		main.game_ui.set_selected_ally(null)
	
	selected_mech_coords = Vector2i(-1, -1)
	selected_wire_coords = Vector2i(-1, -1)
	if main.game_ui:
		main.game_ui.close_inventory()
		main.game_ui.hide_context_menu()

func has_selection() -> bool:
	_clean_selected_allies()
	return not selected_allies.is_empty() or selected_mech_coords != Vector2i(-1, -1) or selected_wire_coords != Vector2i(-1, -1)

func _show_clutter_context_menu(clutter: ClutterObject) -> void:
	if selected_allies.is_empty(): return
	var lead_ally = selected_allies[0]
	if not is_instance_valid(lead_ally): return
	
	var options =[]
	
	options.append({
		"label": "Move Here",
		"callback": func():
			var t = _find_best_stand_pos(clutter, lead_ally)
			lead_ally.command_move(t)
	})
	
	if clutter.clutter_resource and clutter.clutter_resource.id == "rock":
		options.append({
			"label": "Pick up %s" % clutter.clutter_resource.id.capitalize(),
			"callback": func():
				lead_ally.set_interaction(clutter, "pickup_clutter")
		})
	
	if main.game_ui:
		main.game_ui.show_context_menu(main.get_viewport().get_mouse_position(), options)

func _find_best_stand_pos(target_node: Node3D, seeker: Node3D) -> Vector3:
	var target_tile = LaneManager.world_to_tile(target_node.global_position)
	var seeker_pos = seeker.global_position
	var candidates =[]
	
	var neighbors =[
		Vector2i(0, 1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0)
	]
	
	for offset in neighbors:
		var n_tile = target_tile + offset
		if LaneManager.is_valid_tile(n_tile):
			var building = LaneManager.get_entity_at(n_tile, "building")
			if not building:
				var world_pos = LaneManager.tile_to_world(n_tile)
				var dist = world_pos.distance_squared_to(seeker_pos)
				candidates.append({ "pos": world_pos, "dist": dist })
	
	if candidates.is_empty():
		return target_node.global_position
	
	candidates.sort_custom(func(a, b): return a.dist < b.dist)
	return candidates[0].pos
