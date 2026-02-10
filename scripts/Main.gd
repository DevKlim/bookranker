extends Node3D

## The main script for the primary game scene in 3D.

@export var camera_speed: float = 10.0
@export var zoom_step: float = 1.0
@export var min_zoom: float = 5.0
@export var max_zoom: float = 30.0
@export var build_cooldown_ms: int = 150 

@export_group("Grid Visual Offsets")
@export var ore_offset: Vector3 = Vector3(0, 0, 0)
@export var wire_offset: Vector3 = Vector3(0, 0.05, 0)
@export var building_offset: Vector3 = Vector3(0, 0.0, 0) 

@onready var camera: Camera3D = $Camera3D
@onready var game_ui: GameUI = $GameUI
@onready var buildings_container: Node3D = $Buildings
@onready var wiring_container: Node3D = $Wiring
@onready var grid_map: GridMap = $GridMap
@onready var dev_map: GridMap = $DevMap
@onready var core: Core = $Core

# Typed as CharacterBody3D to avoid assignment errors during hot-reload class resolution
var player: CharacterBody3D 
const PLAYER_SCENE = preload("res://scenes/allies/player.tscn")

var build_preview_container: Node3D
var indicator_container: Node3D
var selected_mech_coords: Vector2i = Vector2i(-1, -1)
var selected_wire_coords: Vector2i = Vector2i(-1, -1)

# Selection State
var selected_ally: Node = null # Primary selection for UI
var selected_allies: Array[Node] = [] # List of all selected allies

var _hovered_for_deletion: Node = null
var _last_build_time: int = 0
var _last_build_coord: Vector2i = Vector2i(-1, -1) 

var cursor_highlight: MeshInstance3D
var cursor_material: StandardMaterial3D
var selection_indicator: MeshInstance3D

enum LayerMode { ALL, BUILDING_ONLY, WIRE_ONLY }
var current_layer_mode: LayerMode = LayerMode.ALL

var camera_locked: bool = false
var camera_offset: Vector3 = Vector3(10, 10, 10)

func _ready() -> void:
	if not has_node("ToolManager"):
		var tm = ToolManager.new()
		tm.name = "ToolManager"
		add_child(tm)
	
	if camera:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 20.0
		if is_instance_valid(core):
			camera_offset = camera.global_position - core.global_position
	
	LaneManager.ore_offset = ore_offset
	LaneManager.wire_offset = wire_offset
	LaneManager.building_offset = building_offset
	
	if grid_map:
		BuildManager.initialize_grid(grid_map)
		LaneManager.initialize_grid(grid_map)

	if dev_map:
		var debug_lib_path = "res://resources/debug_mesh_library.tres"
		if ResourceLoader.exists(debug_lib_path):
			dev_map.mesh_library = load(debug_lib_path)
			LaneManager.scan_for_spawners(dev_map)
			dev_map.collision_layer = 0
			dev_map.collision_mask = 0

	var old_preview = get_node_or_null("BuildPreview")
	if old_preview: old_preview.queue_free()
		
	build_preview_container = Node3D.new()
	build_preview_container.name = "PreviewContainer"
	build_preview_container.visible = false
	add_child(build_preview_container)
	
	indicator_container = Node3D.new()
	indicator_container.name = "IndicatorContainer"
	add_child(indicator_container)
	
	cursor_highlight = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(1.0, 1.0, 1.0)
	cursor_highlight.mesh = mesh
	
	cursor_material = StandardMaterial3D.new()
	cursor_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cursor_material.albedo_color = Color(0.0, 0.5, 1.0, 0.3)
	cursor_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cursor_highlight.material_override = cursor_material
	cursor_highlight.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cursor_highlight)

	selection_indicator = MeshInstance3D.new()
	var sel_mesh = BoxMesh.new()
	sel_mesh.size = Vector3(1.05, 0.2, 1.05)
	selection_indicator.mesh = sel_mesh
	var sel_mat = StandardMaterial3D.new()
	sel_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sel_mat.albedo_color = Color(1.0, 1.0, 0.0, 0.4)
	sel_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	selection_indicator.material_override = sel_mat
	selection_indicator.visible = false
	add_child(selection_indicator)
	
	BuildManager.build_mode_changed.connect(_on_build_state_changed)
	BuildManager.selected_buildable_changed.connect(_on_build_state_changed)
	BuildManager.build_rotation_changed.connect(_on_build_rotation_changed)
	PlayerManager.equipped_item_changed.connect(_on_equipped_item_changed)
	
	_update_layer_visibility()
	_spawn_player()

func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate()
	player.name = "Player"
	add_child(player)
	player.global_position = Vector3(0, 1.0, 0)

func _process(delta: float) -> void:
	handle_camera_movement(delta)
	handle_debug_display()
	
	# Determine transparency for Core
	var ray_for_transparency = get_mouse_raycast()
	var hovering_core = false
	if ray_for_transparency and ray_for_transparency.get("collider") == core:
		hovering_core = true
	if is_instance_valid(core):
		core.set_transparent(hovering_core)

	var interaction_exclude = []
	if is_instance_valid(core): interaction_exclude.append(core.get_rid())

	if BuildManager.is_building:
		if BuildManager.selected_buildable:
			if BuildManager.selected_buildable.layer != BuildableResource.BuildLayer.TOOL:
				for child in buildings_container.get_children():
					if child is CollisionObject3D:
						interaction_exclude.append(child.get_rid())
	
	# --- SPLIT RAYCAST LOGIC ---
	# 1. Selection Ray: Standard mask (Hits Entities, Units, Buildings, Terrain) for clicking
	var selection_ray = get_mouse_raycast(interaction_exclude) 
	
	# 2. Terrain Ray: Mask 1 only (Hits Terrain/GridMap and Static Buildings) for cursor positioning
	# This effectively ignores Allies (Layer 3) and Enemies (Layer 2) for the cursor highlight
	var terrain_ray = get_mouse_raycast(interaction_exclude, 1)

	var mouse_world_pos = Vector3.ZERO
	if terrain_ray: 
		mouse_world_pos = terrain_ray.position + (terrain_ray.normal * 0.5)
	else: 
		mouse_world_pos = get_plane_intersection()
	
	var cursor_target = mouse_world_pos
	if PlayerManager.equipped_item and PlayerManager.equipped_item.tool_type == "drill":
		if is_instance_valid(player): cursor_target = player.global_position

	update_cursor_highlight(cursor_target)
	_update_selection_indicator()
	
	if BuildManager.is_building:
		update_build_preview(mouse_world_pos)
		_handle_delete_highlight(mouse_world_pos)
		
		if not _is_mouse_over_ui():
			var cell = BuildManager.get_grid_cell(mouse_world_pos)
			var current_coord = Vector2i(cell.x, cell.z)
			if Input.is_action_just_pressed("build_place"):
				_perform_build(mouse_world_pos, current_coord)
			elif Input.is_action_pressed("build_place"):
				var cooldown_ok = (Time.get_ticks_msec() - _last_build_time > build_cooldown_ms)
				var moved_tile = (current_coord != _last_build_coord)
				if cooldown_ok or moved_tile:
					_perform_build(mouse_world_pos, current_coord)
	else:
		_clear_delete_highlight()
		if Input.is_action_just_pressed("use"):
			if selected_ally and is_instance_valid(selected_ally) and selected_ally.has_method("activate_mode"):
				selected_ally.activate_mode()
		
		if PlayerManager.equipped_item and PlayerManager.equipped_item.is_tool:
			pass
		else:
			if Input.is_action_just_pressed("build_place"):
				if not _is_mouse_over_ui():
					# Use SELECTION RAY for clicking units/entities
					var collider = selection_ray.get("collider") if selection_ray else null
					var clicked_unit = false
					var is_shift_held = Input.is_key_pressed(KEY_SHIFT)
					
					# Special handling for Player entity selection
					if collider == player:
						if not is_shift_held: _deselect_all()
						
						if not selected_allies.has(player):
							selected_allies.append(player)
							PlayerManager.is_player_selected = true
							player.set_selected(true)
						elif is_shift_held:
							# Toggle off if Shift held and clicked on player
							selected_allies.erase(player)
							PlayerManager.is_player_selected = false
							player.set_selected(false)
						
						# Update Primary
						if not selected_allies.is_empty():
							selected_ally = selected_allies.back()
							game_ui.set_selected_ally(selected_ally)
						else:
							selected_ally = null
							game_ui.set_selected_ally(null)
							
						clicked_unit = true

					elif collider and collider.is_in_group("allies"):
						if not is_shift_held: _deselect_all()
						
						if not selected_allies.has(collider):
							selected_allies.append(collider)
							if collider.has_method("set_selected"): collider.set_selected(true)
						elif is_shift_held:
							selected_allies.erase(collider)
							if collider.has_method("set_selected"): collider.set_selected(false)
						
						# Update Primary
						if not selected_allies.is_empty():
							selected_ally = selected_allies.back()
							game_ui.set_selected_ally(selected_ally)
							
							# If just one selected, show inventory immediately
							if selected_allies.size() == 1:
								if "inventory_component" in selected_ally and selected_ally.inventory_component:
									var d_name = "Ally"
									if "display_name" in selected_ally: d_name = selected_ally.display_name
									elif "ally_name" in selected_ally: d_name = selected_ally.ally_name
									game_ui.open_inventory(selected_ally.inventory_component, d_name, selected_ally)
						else:
							selected_ally = null
							game_ui.set_selected_ally(null)
						
						clicked_unit = true
					
					if not clicked_unit:
						# If we clicked ground without shift, deselect all.
						# Use mouse_world_pos (Grid) to determine which tile was clicked
						if not is_shift_held:
							var cell = BuildManager.get_grid_cell(mouse_world_pos)
							var tile_coord = Vector2i(cell.x, cell.z)
							if current_layer_mode == LayerMode.WIRE_ONLY:
								_handle_wire_click(tile_coord)
								_deselect_all()
							else:
								var mech = BuildManager.get_mech_at(tile_coord)
								if mech:
									selected_mech_coords = tile_coord
									_deselect_all()
									var inventory = null
									if "inventory_component" in mech: inventory = mech.inventory_component
									if not inventory: inventory = mech.get("inventory")
									if not inventory: inventory = mech.get("input_inventory")
									if inventory and inventory is InventoryComponent:
										var title = mech.name.rstrip("0123456789")
										game_ui.open_inventory(inventory, title, mech)
									else:
										game_ui.close_inventory()
								else:
									selected_mech_coords = Vector2i(-1, -1)
									game_ui.close_inventory()
									game_ui.hide_network_stats()
									_deselect_all()

			elif Input.is_action_just_pressed("build_cancel"):
				# Right click
				if not _is_mouse_over_ui():
					if not selected_allies.is_empty():
						var cell = BuildManager.get_grid_cell(mouse_world_pos)
						var tile_coord = Vector2i(cell.x, cell.z)
						if LaneManager.is_valid_tile(tile_coord):
							var target_pos = LaneManager.tile_to_world(tile_coord) # Center of tile
							
							# Context Menu check
							var entity = LaneManager.get_entity_at(tile_coord, "building")
							if entity is ClutterObject:
								_show_clutter_context_menu(entity)
								return

							for ally in selected_allies:
								if is_instance_valid(ally) and ally.has_method("command_move"):
									ally.command_move(target_pos)
					else:
						if game_ui.is_pause_menu_open(): game_ui.toggle_pause_menu()
						elif game_ui.is_any_menu_open():
							game_ui.close_all_menus()
							if selected_mech_coords != Vector2i(-1, -1): selected_mech_coords = Vector2i(-1, -1)

	update_arrow_indicator()

func _find_best_stand_pos(target_node: Node3D, seeker: Node3D) -> Vector3:
	var target_tile = LaneManager.world_to_tile(target_node.global_position)
	var seeker_pos = seeker.global_position
	var candidates = []
	
	# Neighbors: Down, Up, Left, Right
	var neighbors = [
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

func _show_clutter_context_menu(clutter: ClutterObject) -> void:
	if selected_allies.is_empty(): return
	var lead_ally = selected_allies[0]
	if not is_instance_valid(lead_ally): return
	
	var options = []
	
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
				# Ally logic handles if it needs to move or not
				lead_ally.set_interaction(clutter, "pickup_clutter")
		})
	
	game_ui.show_context_menu(get_viewport().get_mouse_position(), options)

func _deselect_all() -> void:
	PlayerManager.is_player_selected = false
	
	for ally in selected_allies:
		if is_instance_valid(ally) and ally.has_method("set_selected"):
			ally.set_selected(false)
	
	selected_allies.clear()
	selected_ally = null
	
	if game_ui:
		game_ui.set_selected_ally(null)
	
	selected_mech_coords = Vector2i(-1, -1)
	selected_wire_coords = Vector2i(-1, -1)
	game_ui.close_inventory()
	game_ui.hide_context_menu()

func _update_selection_indicator() -> void:
	if current_layer_mode == LayerMode.WIRE_ONLY and selected_wire_coords != Vector2i(-1, -1):
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
		game_ui.show_network_stats(stats)
	else:
		selected_wire_coords = Vector2i(-1, -1)
		game_ui.hide_network_stats()

func _perform_build(pos: Vector3, coord: Vector2i) -> void:
	_last_build_time = Time.get_ticks_msec()
	_last_build_coord = coord
	BuildManager.place_buildable(pos)

## Updated to optionally accept a collision mask for filtering raycasts.
## mask default is 0xFFFFFFFF (All layers).
func get_mouse_raycast(exclude: Array = [], mask: int = 4294967295) -> Dictionary:
	var mouse_pos = get_viewport().get_mouse_position()
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000.0
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = mask
	if not exclude.is_empty(): query.exclude = exclude
	return space_state.intersect_ray(query)

func get_plane_intersection() -> Vector3:
	var mouse_pos = get_viewport().get_mouse_position()
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000.0
	var plane = Plane(Vector3.UP, 0)
	var intersect = plane.intersects_ray(from, to)
	return intersect if intersect else Vector3.ZERO

func _input(event: InputEvent) -> void:
	if get_viewport().is_input_handled(): return

	if event is InputEventMouseButton:
		if not _is_mouse_over_ui():
			if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
				camera.size = clamp(camera.size - zoom_step, min_zoom, max_zoom)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
				camera.size = clamp(camera.size + zoom_step, min_zoom, max_zoom)
	
	if event.is_action_pressed("switch_layer"): _toggle_layer_view()

	if event.is_action_pressed("ui_cancel"):
		var handled = false
		if game_ui.is_pause_menu_open():
			game_ui.toggle_pause_menu(); handled = true
		elif game_ui.is_any_menu_open():
			game_ui.close_all_menus(); handled = true
		elif BuildManager.is_building:
			BuildManager.exit_build_mode(); handled = true
		elif PlayerManager.equipped_item and PlayerManager.equipped_item.is_tool:
			PlayerManager.set_equipped_item(null); handled = true
		elif not selected_allies.is_empty():
			_deselect_all(); handled = true
		else:
			game_ui.toggle_pause_menu(); handled = true
		
		if handled: get_viewport().set_input_as_handled()
		
	elif BuildManager.is_building and Input.is_action_just_pressed("build_rotate"):
		BuildManager.rotate_buildable()
		get_viewport().set_input_as_handled()

func _toggle_layer_view() -> void:
	match current_layer_mode:
		LayerMode.ALL: current_layer_mode = LayerMode.BUILDING_ONLY
		LayerMode.BUILDING_ONLY: current_layer_mode = LayerMode.WIRE_ONLY
		LayerMode.WIRE_ONLY: current_layer_mode = LayerMode.ALL
	if current_layer_mode != LayerMode.WIRE_ONLY:
		selected_wire_coords = Vector2i(-1, -1)
		game_ui.hide_network_stats()
	_update_layer_visibility()

func _update_layer_visibility() -> void:
	match current_layer_mode:
		LayerMode.ALL:
			buildings_container.visible = true; _set_collision_enabled(buildings_container, true)
			wiring_container.visible = true
			if is_instance_valid(dev_map): dev_map.visible = false
		LayerMode.BUILDING_ONLY:
			buildings_container.visible = true; _set_collision_enabled(buildings_container, true)
			wiring_container.visible = false
		LayerMode.WIRE_ONLY:
			buildings_container.visible = true; _set_container_transparency(buildings_container, 0.2); _set_collision_enabled(buildings_container, false)
			wiring_container.visible = true
	if current_layer_mode != LayerMode.WIRE_ONLY: _set_container_transparency(buildings_container, 1.0)

func _set_collision_enabled(parent: Node, enabled: bool) -> void:
	for child in parent.get_children():
		if child is CollisionObject3D:
			child.input_ray_pickable = enabled
			child.collision_layer = 1 if enabled else 0

func _set_container_transparency(parent: Node, alpha: float) -> void:
	for child in parent.get_children(): _apply_transparency_recursive(child, alpha)

func _apply_transparency_recursive(node: Node, alpha: float) -> void:
	if node is MeshInstance3D:
		node.transparency = 1.0 - alpha if alpha < 1.0 else 0.0
	elif node is Sprite3D:
		node.modulate.a = alpha
	for c in node.get_children(): _apply_transparency_recursive(c, alpha)

func handle_camera_movement(delta: float) -> void:
	if Input.is_action_just_pressed("ui_accept"): camera_locked = !camera_locked
	
	if camera_locked and is_instance_valid(player):
		var target = player.global_position + camera_offset
		camera.global_position = camera.global_position.lerp(target, delta * 5.0)
		return
	
	var dir = Vector3.ZERO
	if Input.is_action_pressed("move_up"): dir.z -= 1
	if Input.is_action_pressed("move_down"): dir.z += 1
	if Input.is_action_pressed("move_left"): dir.x -= 1
	if Input.is_action_pressed("move_right"): dir.x += 1
	
	if dir != Vector3.ZERO:
		dir = dir.rotated(Vector3.UP, camera.rotation.y).normalized()
		camera.position += dir * camera_speed * delta

func update_cursor_highlight(world_pos: Vector3) -> void:
	if not grid_map or _is_mouse_over_ui():
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
	elif current_layer_mode == LayerMode.WIRE_ONLY: y_offset = 0.5
	
	if PlayerManager.equipped_item and PlayerManager.equipped_item.is_tool:
		var item = PlayerManager.equipped_item
		var h_offset = item.highlight_offset
		y_offset = 0.1 + h_offset.y
		tile_pos += Vector3(h_offset.x, 0, h_offset.z)
		if has_node("ToolManager") and get_node("ToolManager").has_mineable_at(world_pos):
			target_color = Color(0.4, 1.0, 0.4, 0.6)
		else:
			target_color = Color(1.0, 0.4, 0.4, 0.6)
			
	cursor_material.albedo_color = target_color
	cursor_highlight.global_position = tile_pos + Vector3(0, y_offset, 0) 
	cursor_highlight.visible = true

func handle_debug_display() -> void:
	# Use the specific terrain ray here for accurate grid info, not the selection ray
	var ray = get_mouse_raycast([], 1)
	var world_pos = (ray.position - ray.normal * 0.1) if ray else get_plane_intersection()
	var cell = Vector3i.ZERO
	var ore_info = "None"
	var entity_info = ""
	
	var tm = get_node_or_null("ToolManager")
	var is_player_mining = false
	if tm and is_instance_valid(player) and tm.active_miners.has(player): is_player_mining = true

	if not is_player_mining:
		if grid_map:
			var snapped_pos = ray.position + (ray.normal * 0.5) if ray else world_pos
			cell = grid_map.local_to_map(grid_map.to_local(snapped_pos))
			var tile_center = LaneManager.tile_to_world(Vector2i(cell.x, cell.z))
			var ore = LaneManager.get_ore_at_world_pos(tile_center)
			if ore: ore_info = ore.item_name
		
		# Use selection ray for entity debug info
		var sel_ray = get_mouse_raycast()
		if sel_ray and sel_ray.get("collider"):
			var col = sel_ray.get("collider")
			if col is BaseBuilding:
				entity_info += "\n[Entity: %s]" % col.name
		
		var mode_name = LayerMode.keys()[current_layer_mode]
		var debug_str = "Layer Mode: %s\nTile(X,Z): %d, %d\nOre: %s%s" % [mode_name, cell.x, cell.z, ore_info, entity_info]
		if game_ui: game_ui.set_debug_text(debug_str)

func update_arrow_indicator() -> void:
	if not is_inside_tree() or not is_instance_valid(indicator_container) or not indicator_container.is_inside_tree(): return 
	
	for child in indicator_container.get_children(): child.queue_free()
	
	var pivot_world_pos = Vector3.ZERO
	var show_arrows = false
	var input_mask = 0; var output_mask = 0
	var current_layout: Array[Vector2i] = [Vector2i.ZERO]
	var is_preview_mode = false; var rotation_index = 0
	
	if BuildManager.is_building and build_preview_container.visible and BuildManager.selected_buildable:
		if not build_preview_container.is_inside_tree(): return
		if BuildManager.selected_buildable.layer == BuildableResource.BuildLayer.MECH:
			is_preview_mode = true
			pivot_world_pos = build_preview_container.global_position
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

	elif selected_mech_coords != Vector2i(-1, -1):
		var mech = BuildManager.get_mech_at(selected_mech_coords)
		if is_instance_valid(mech):
			pivot_world_pos = LaneManager.tile_to_world(selected_mech_coords) + LaneManager.get_layer_offset("building")
			show_arrows = true
			if mech.get("has_input") and "input_mask" in mech: input_mask = mech.input_mask
			if mech.get("has_output") and "output_mask" in mech: output_mask = mech.output_mask
			if mech.has_method("get_occupied_cells"): current_layout = mech.get_occupied_cells()
		else:
			selected_mech_coords = Vector2i(-1, -1)

	if show_arrows:
		var height_offset = Vector3(0, 0.8, 0)
		if is_preview_mode:
			var dir_indicator = _create_direction_indicator()
			indicator_container.add_child(dir_indicator)
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
						indicator_container.add_child(in_arrow)
						_apply_arrow_transform(in_arrow, block_world_pos + height_offset - side_vec, i, true)
						var out_arrow = _create_arrow_mesh(Color(0.2, 1.0, 0.2, 0.8))
						indicator_container.add_child(out_arrow)
						_apply_arrow_transform(out_arrow, block_world_pos + height_offset + side_vec, i, false)
					elif is_in:
						var ind = _create_arrow_mesh(Color(1.0, 0.2, 0.2, 0.8)); indicator_container.add_child(ind)
						_apply_arrow_transform(ind, block_world_pos + height_offset, i, true)
					elif is_out:
						var ind = _create_arrow_mesh(Color(0.2, 1.0, 0.2, 0.8)); indicator_container.add_child(ind)
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
	if indicator_container.is_inside_tree(): node.position = indicator_container.to_local(center_pos + offset)
	else: node.position = center_pos + offset
	node.rotation.y = y_rot

func _create_arrow_mesh(color: Color) -> Node3D:
	var container = Node3D.new()
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color; mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var prism = PrismMesh.new(); prism.size = Vector3(0.3, 0.3, 0.1) 
	var mesh_inst = MeshInstance3D.new(); mesh_inst.mesh = prism; mesh_inst.material_override = mat; mesh_inst.rotation.x = deg_to_rad(-90)
	container.add_child(mesh_inst)
	return container

func _create_direction_indicator() -> Node3D:
	var container = Node3D.new()
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.8, 0.0, 0.8); mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var prism = PrismMesh.new(); prism.size = Vector3(0.6, 0.6, 0.1)
	var mesh = MeshInstance3D.new(); mesh.mesh = prism; mesh.material_override = mat; mesh.rotation.x = deg_to_rad(-90)
	container.add_child(mesh)
	return container

func _on_build_state_changed(_arg = null) -> void:
	_clear_preview(); _clear_delete_highlight(); _deselect_all(); game_ui.hide_network_stats()
	if BuildManager.is_building and BuildManager.selected_buildable:
		build_preview_container.visible = true
		var buildable = BuildManager.selected_buildable
		if buildable.scene:
			var temp = buildable.scene.instantiate()
			temp.process_mode = Node.PROCESS_MODE_DISABLED
			temp.set_meta("is_preview", true)
			build_preview_container.add_child(temp)
			if temp.has_method("set_build_rotation"): temp.set_build_rotation(BuildManager.current_rotation_index)
		elif buildable.layer == BuildableResource.BuildLayer.TOOL:
			var s = Sprite3D.new()
			s.texture = buildable.icon; s.axis = Vector3.AXIS_Y; s.pixel_size = 0.03; s.modulate = Color(1, 0.5, 0.5, 0.7)
			build_preview_container.add_child(s)

func _clear_preview() -> void:
	for child in build_preview_container.get_children(): child.queue_free()
	build_preview_container.visible = false

func _on_build_rotation_changed(rotation_val: Variant) -> void:
	if build_preview_container.get_child_count() > 0:
		var preview_node = build_preview_container.get_child(0)
		if is_instance_valid(preview_node) and preview_node.has_method("set_build_rotation"):
			preview_node.set_build_rotation(rotation_val)

func _is_mouse_over_ui() -> bool:
	var mouse_pos = get_viewport().get_mouse_position()
	for ui_rect in game_ui.get_ui_rects():
		if ui_rect.has_point(mouse_pos): return true
	return false

func update_build_preview(world_pos: Vector3):
	if _is_mouse_over_ui():
		build_preview_container.visible = false; return
	var buildable = BuildManager.selected_buildable
	if not buildable: return
	build_preview_container.visible = true
	var cell = BuildManager.get_grid_cell(world_pos)
	var tile_pos = LaneManager.tile_to_world(Vector2i(cell.x, cell.z))
	var layer_name = "building"
	if buildable.layer == BuildableResource.BuildLayer.WIRING: layer_name = "wire"
	var layer_offset = LaneManager.get_layer_offset(layer_name)
	var final_pos = tile_pos + layer_offset
	var display_offset_3d = Vector3(buildable.display_offset.x, buildable.display_offset.y, 0)
	build_preview_container.global_position = final_pos + display_offset_3d
	var can_build = BuildManager.can_build_at(world_pos)
	var tint = Color(0.4, 1.0, 0.4, 0.6) if can_build else Color(1.0, 0.4, 0.4, 0.6)
	if buildable.layer == BuildableResource.BuildLayer.TOOL:
		var has_target = BuildManager.has_removable_at(world_pos)
		for c in build_preview_container.get_children():
			if c is Sprite3D: c.modulate = Color(1, 0.5, 0.5, 0.7) if has_target else Color(0.5, 0.5, 0.5, 0.5)
	else:
		if build_preview_container.get_child_count() > 0:
			var preview_node = build_preview_container.get_child(0)
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
			node.set_surface_override_material(i, target_mat)
	for child in node.get_children(): _apply_ghost_visuals(child, color_tint)

func _handle_delete_highlight(world_pos: Vector3) -> void:
	if not BuildManager.is_building or not BuildManager.selected_buildable or BuildManager.selected_buildable.layer != BuildableResource.BuildLayer.TOOL:
		_clear_delete_highlight(); return
	var cell = BuildManager.get_grid_cell(world_pos)
	var tile = Vector2i(cell.x, cell.z)
	var target = BuildManager.get_mech_at(tile)
	if not target: target = BuildManager.wiring_manager.get_wire_instance(tile)
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

func _on_equipped_item_changed(item: ItemResource) -> void:
	if item and item.is_tool: Input.set_custom_mouse_cursor(item.icon)
	else: Input.set_custom_mouse_cursor(null)
