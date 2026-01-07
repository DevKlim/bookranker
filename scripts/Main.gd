extends Node3D

## The main script for the primary game scene in 3D.

@export var camera_speed: float = 10.0
@export var zoom_step: float = 1.0
@export var min_zoom: float = 5.0
@export var max_zoom: float = 30.0

@export_group("Grid Visual Offsets")
@export var ore_offset: Vector3 = Vector3(0, 0, 0)
@export var wire_offset: Vector3 = Vector3(0, 0.05, 0)
# Changed default to 0.0 as generated meshes are bottom-aligned
@export var building_offset: Vector3 = Vector3(0, 0.0, 0) 

@onready var camera: Camera3D = $Camera3D
@onready var game_ui: CanvasLayer = $GameUI
@onready var buildings_container: Node3D = $Buildings
@onready var grid_map: GridMap = $GridMap
@onready var dev_map: GridMap = $DevMap
@onready var core: Core = $Core

# Container for the 3D preview
var build_preview_container: Node3D

# Arrows
var arrow_indicator: Node3D
var input_arrow_indicator: Node3D
var selected_mech_coords: Vector2i = Vector2i(-1, -1)
var _hovered_for_deletion: Node = null

# Highlight Cursor for GridMap
var cursor_highlight: MeshInstance3D

# Ghost Material for Preview
var ghost_material: StandardMaterial3D

func _ready() -> void:
	print("Main 3D scene initialized.")
	
	ghost_material = StandardMaterial3D.new()
	ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_material.albedo_color = Color(0.4, 0.8, 0.4, 0.5) 
	ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	if camera:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 20.0
	
	LaneManager.ore_offset = ore_offset
	LaneManager.wire_offset = wire_offset
	LaneManager.building_offset = building_offset
	
	if grid_map:
		BuildManager.initialize_grid(grid_map)
		LaneManager.initialize_grid(grid_map)
	else:
		printerr("Main: GridMap node not found or not assigned.")

	# Initialize DevMap with Debug Library
	if dev_map:
		var debug_lib_path = "res://resources/debug_mesh_library.tres"
		if ResourceLoader.exists(debug_lib_path):
			dev_map.mesh_library = load(debug_lib_path)
			# Scan for spawners using the dedicated library
			LaneManager.scan_for_spawners(dev_map)
			# Disable collision on DevMap to prevent enemies colliding with spawners
			dev_map.collision_layer = 0
			dev_map.collision_mask = 0
		else:
			print("Main: Debug Mesh Library not found at %s. Spawner detection skipped." % debug_lib_path)

	var old_preview = get_node_or_null("BuildPreview")
	if old_preview: old_preview.queue_free()
		
	build_preview_container = Node3D.new()
	build_preview_container.name = "PreviewContainer"
	build_preview_container.visible = false
	add_child(build_preview_container)
	
	arrow_indicator = _create_arrow_mesh(Color(0.2, 1.0, 0.2, 0.8)) # Green for Output
	arrow_indicator.visible = false
	add_child(arrow_indicator)
	
	input_arrow_indicator = _create_arrow_mesh(Color(1.0, 0.2, 0.2, 0.8)) # Red for Input
	input_arrow_indicator.visible = false
	add_child(input_arrow_indicator)
	
	cursor_highlight = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = Vector3(1.0, 1.0, 1.0)
	cursor_highlight.mesh = mesh
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.0, 0.5, 1.0, 0.3)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cursor_highlight.material_override = mat
	cursor_highlight.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cursor_highlight)
	
	BuildManager.build_mode_changed.connect(_on_build_state_changed)
	BuildManager.selected_buildable_changed.connect(_on_build_state_changed)
	BuildManager.build_rotation_changed.connect(_on_build_rotation_changed)

func _create_arrow_mesh(color: Color) -> Node3D:
	var container = Node3D.new()
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	
	var prism = PrismMesh.new()
	prism.size = Vector3(0.5, 0.5, 0.1) 
	
	var mesh_inst = MeshInstance3D.new()
	mesh_inst.mesh = prism
	mesh_inst.material_override = mat
	mesh_inst.rotation.x = deg_to_rad(-90)
	
	container.add_child(mesh_inst)
	return container

func _process(delta: float) -> void:
	handle_camera_movement(delta)
	handle_debug_display()
	
	var ray = get_mouse_raycast()
	var mouse_world_pos = Vector3.ZERO
	
	# Logic to handle Core transparency and building "through" it
	var hovering_core = false
	if ray and ray.get("collider") == core:
		hovering_core = true
		if is_instance_valid(core):
			core.set_transparent(true)
			
		# If building, we want to look BEHIND the core
		if BuildManager.is_building:
			# Re-cast excluding the Core
			var ray_ex = get_mouse_raycast([core])
			if ray_ex:
				if ray_ex.get("collider") is GridMap:
					mouse_world_pos = ray_ex.position + (ray_ex.normal * 0.5)
				else:
					mouse_world_pos = ray_ex.position - (ray_ex.normal * 0.1)
			else:
				mouse_world_pos = get_plane_intersection()
		else:
			mouse_world_pos = ray.position
	else:
		if is_instance_valid(core):
			core.set_transparent(false)
			
		if ray:
			if BuildManager.is_building:
				var collider = ray.get("collider")
				if collider is GridMap:
					mouse_world_pos = ray.position + (ray.normal * 0.5)
				else:
					mouse_world_pos = ray.position - (ray.normal * 0.1)
			else:
				mouse_world_pos = ray.position - (ray.normal * 0.1)
		else:
			mouse_world_pos = get_plane_intersection()

	update_cursor_highlight(mouse_world_pos)
	
	if BuildManager.is_building:
		update_build_preview(mouse_world_pos)
		_handle_delete_highlight(mouse_world_pos)
		
		if Input.is_action_pressed("build_place") or (BuildManager.selected_buildable.layer == BuildableResource.BuildLayer.TOOL and Input.is_action_just_pressed("build_place")):
			if not _is_mouse_over_ui():
				BuildManager.place_buildable(mouse_world_pos)
	else:
		_clear_delete_highlight()
		if Input.is_action_just_pressed("build_place"):
			if not _is_mouse_over_ui():
				var cell = BuildManager.get_grid_cell(mouse_world_pos)
				var tile_coord = Vector2i(cell.x, cell.z)
				
				var mech = BuildManager.get_mech_at(tile_coord)
				
				if mech:
					selected_mech_coords = tile_coord
					
					# Attempt to find an inventory
					var inventory = null
					
					# 1. Standard Component (New System)
					if "inventory_component" in mech:
						inventory = mech.inventory_component
					
					# 2. Legacy / Fallbacks
					if not inventory:
						inventory = mech.get("inventory")
					if not inventory:
						inventory = mech.get("input_inventory")
						
					if inventory and inventory is InventoryComponent:
						var title = mech.name.rstrip("0123456789")
						game_ui.open_inventory(inventory, title, mech)
					else:
						game_ui.close_inventory()
				else:
					selected_mech_coords = Vector2i(-1, -1)
					game_ui.close_inventory()
	
	if selected_mech_coords != Vector2i(-1, -1):
		# Adjust indicator position using LaneManager logic
		var world_pos = LaneManager.tile_to_world(selected_mech_coords) + LaneManager.get_layer_offset("building")
		world_pos.y += 1.0 # Float UI above building
		var screen_pos = camera.unproject_position(world_pos)
		game_ui.set_inventory_screen_position(screen_pos)

	update_arrow_indicator()

func get_mouse_raycast(exclude: Array = []) -> Dictionary:
	var mouse_pos = get_viewport().get_mouse_position()
	var from = camera.project_ray_origin(mouse_pos)
	var to = from + camera.project_ray_normal(mouse_pos) * 1000.0
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	if not exclude.is_empty():
		query.exclude = exclude
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
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			camera.size = clamp(camera.size - zoom_step, min_zoom, max_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			camera.size = clamp(camera.size + zoom_step, min_zoom, max_zoom)

	if Input.is_action_just_pressed("build_cancel"):
		if BuildManager.is_building:
			BuildManager.exit_build_mode()
		selected_mech_coords = Vector2i(-1, -1)
		game_ui.close_inventory()
		get_viewport().set_input_as_handled()
	elif BuildManager.is_building and Input.is_action_just_pressed("build_rotate"):
		BuildManager.rotate_buildable()
		get_viewport().set_input_as_handled()

func handle_camera_movement(delta: float) -> void:
	var input_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_vector != Vector2.ZERO:
		var dir = Vector3(input_vector.x, 0, input_vector.y)
		if camera:
			dir = dir.rotated(Vector3.UP, camera.rotation.y)
		camera.position += dir * camera_speed * delta

func update_cursor_highlight(world_pos: Vector3) -> void:
	if not grid_map or _is_mouse_over_ui():
		cursor_highlight.visible = false
		return
	
	# Use LaneManager logic for floor alignment
	var cell = BuildManager.get_grid_cell(world_pos)
	var tile_pos = LaneManager.tile_to_world(Vector2i(cell.x, cell.z))
	# Highlight sits 1 block higher (at Y=1.5 if block center is 0.5)
	cursor_highlight.global_position = tile_pos + Vector3(0, 1.5, 0) 
	cursor_highlight.visible = true

func handle_debug_display() -> void:
	var ray = get_mouse_raycast()
	var world_pos = (ray.position - ray.normal * 0.1) if ray else get_plane_intersection()
	
	var cell = Vector3i.ZERO
	var ore_info = "None"
	
	if grid_map:
		cell = grid_map.local_to_map(grid_map.to_local(world_pos))
		
		# Query LaneManager using the specific tile center to be precise
		var tile_center = LaneManager.tile_to_world(Vector2i(cell.x, cell.z))
		# Check slightly above floor (Y=0.5) to match Drill query logic
		var check_pos = tile_center + Vector3(0, 0.5, 0)
		
		var ore = LaneManager.get_ore_at_world_pos(check_pos)
		if ore:
			ore_info = ore.item_name
			
	if game_ui:
		game_ui.set_debug_text("Cell: %s\nOre: %s" % [str(cell), ore_info])

func update_arrow_indicator() -> void:
	arrow_indicator.visible = false
	input_arrow_indicator.visible = false
	
	var out_dir = -1
	var in_dir = -1
	var base_pos = Vector3.ZERO
	var show_arrows = false
	var show_input = false
	var show_output = false
	
	if BuildManager.is_building and build_preview_container.visible and BuildManager.selected_buildable:
		if BuildManager.selected_buildable.layer == BuildableResource.BuildLayer.MECH:
			base_pos = build_preview_container.global_position
			show_arrows = true
			show_input = BuildManager.selected_buildable.has_input
			show_output = BuildManager.selected_buildable.has_output
			
			var rot = BuildManager.current_rotation_index
			match rot:
				0: # DOWN
					out_dir = 0; in_dir = 2
				1: # LEFT
					out_dir = 1; in_dir = 3
				2: # UP
					out_dir = 2; in_dir = 0
				3: # RIGHT
					out_dir = 3; in_dir = 1

	elif selected_mech_coords != Vector2i(-1, -1):
		var mech = BuildManager.get_mech_at(selected_mech_coords)
		if is_instance_valid(mech):
			base_pos = LaneManager.tile_to_world(selected_mech_coords) + LaneManager.get_layer_offset("building")
			show_arrows = true
			if "has_input" in mech: show_input = mech.has_input
			if "has_output" in mech: show_output = mech.has_output
			if "output_direction" in mech: out_dir = mech.output_direction
			if "input_direction" in mech: in_dir = mech.input_direction
		else:
			selected_mech_coords = Vector2i(-1, -1)

	if show_arrows:
		var height_offset = Vector3(0, 0.8, 0)
		if show_output and out_dir != -1:
			arrow_indicator.visible = true
			_apply_arrow_transform(arrow_indicator, base_pos + height_offset, out_dir, false)
			
		if show_input and in_dir != -1:
			input_arrow_indicator.visible = true
			_apply_arrow_transform(input_arrow_indicator, base_pos + height_offset, in_dir, true)

func _apply_arrow_transform(node: Node3D, center_pos: Vector3, dir_idx: int, is_input: bool) -> void:
	var offset = Vector3.ZERO
	var y_rot = 0.0
	
	# Godot 3D Directions:
	# 0: DOWN (Back/+Z)
	# 1: LEFT (Left/-X)
	# 2: UP (Fwd/-Z)
	# 3: RIGHT (Right/+X)
	
	match dir_idx:
		0: 
			offset = Vector3(0, 0, 0.5)
			y_rot = deg_to_rad(180) 
		1:
			offset = Vector3(-0.5, 0, 0)
			y_rot = deg_to_rad(90)
		2:
			offset = Vector3(0, 0, -0.5)
			y_rot = 0
		3:
			offset = Vector3(0.5, 0, 0)
			y_rot = deg_to_rad(-90)
	
	if is_input:
		y_rot += deg_to_rad(180)
		
	node.global_position = center_pos + offset
	node.rotation.y = y_rot

func _on_build_state_changed(_arg = null) -> void:
	_clear_preview()
	_clear_delete_highlight()
	selected_mech_coords = Vector2i(-1, -1) 
	game_ui.close_inventory()
	
	if BuildManager.is_building and BuildManager.selected_buildable:
		build_preview_container.visible = true
		var buildable = BuildManager.selected_buildable
		
		if buildable.scene:
			var temp = buildable.scene.instantiate()
			temp.process_mode = Node.PROCESS_MODE_DISABLED
			temp.set_meta("is_preview", true)
			build_preview_container.add_child(temp)
			_apply_ghost_material(temp)
			if temp.has_method("set_build_rotation"):
				temp.set_build_rotation(BuildManager.current_rotation_index)

		elif buildable.layer == BuildableResource.BuildLayer.TOOL:
			var s = Sprite3D.new()
			s.texture = buildable.icon
			s.axis = Vector3.AXIS_Y
			s.pixel_size = 0.03
			s.modulate = Color(1, 0.5, 0.5, 0.7)
			build_preview_container.add_child(s)

func _apply_ghost_material(node: Node) -> void:
	if not is_instance_valid(node): return
	
	if node is MeshInstance3D:
		node.material_override = ghost_material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	for child in node.get_children():
		_apply_ghost_material(child)

func _clear_preview() -> void:
	for child in build_preview_container.get_children():
		child.queue_free()
	build_preview_container.visible = false

func _on_build_rotation_changed(rotation_val: Variant) -> void:
	if build_preview_container.get_child_count() > 0:
		var preview_node = build_preview_container.get_child(0)
		if is_instance_valid(preview_node) and preview_node.has_method("set_build_rotation"):
			preview_node.set_build_rotation(rotation_val)

func _is_mouse_over_ui() -> bool:
	var mouse_pos = get_viewport().get_mouse_position()
	for ui_rect in game_ui.get_ui_rects():
		if ui_rect.has_point(mouse_pos):
			return true
	return false

func update_build_preview(world_pos: Vector3):
	if _is_mouse_over_ui():
		build_preview_container.visible = false
		return
	
	var buildable = BuildManager.selected_buildable
	if not buildable: return
	
	build_preview_container.visible = true
	
	# 1. Snap Logic using LaneManager
	var cell = BuildManager.get_grid_cell(world_pos)
	var tile_pos = LaneManager.tile_to_world(Vector2i(cell.x, cell.z))
	
	# 2. Layer Offset (Building vs Wire vs Tool)
	var layer_name = "building"
	if buildable.layer == BuildableResource.BuildLayer.WIRING:
		layer_name = "wire"
	
	var layer_offset = LaneManager.get_layer_offset(layer_name)
	
	# 3. Apply
	var final_pos = tile_pos + layer_offset
	
	# 4. Apply Display Offset from Resource (Vector2 to X/Y in 3D?)
	# Actually display_offset.x -> x, display_offset.y -> y visually.
	var display_offset_3d = Vector3(buildable.display_offset.x, buildable.display_offset.y, 0)
	
	build_preview_container.global_position = final_pos + display_offset_3d

	var can_build = BuildManager.can_build_at(world_pos)
	var col = Color(0.4, 1.0, 0.4, 0.5) if can_build else Color(1.0, 0.4, 0.4, 0.5)
	ghost_material.albedo_color = col
	
	if buildable.layer == BuildableResource.BuildLayer.TOOL:
		var has_target = BuildManager.has_removable_at(world_pos)
		for c in build_preview_container.get_children():
			if c is Sprite3D:
				c.modulate = Color(1, 0.5, 0.5, 0.7) if has_target else Color(0.5, 0.5, 0.5, 0.5)

func _handle_delete_highlight(world_pos: Vector3) -> void:
	if not BuildManager.is_building or \
	   not BuildManager.selected_buildable or \
	   BuildManager.selected_buildable.layer != BuildableResource.BuildLayer.TOOL:
		_clear_delete_highlight()
		return

	var cell = BuildManager.get_grid_cell(world_pos)
	var tile = Vector2i(cell.x, cell.z)
	
	var target = BuildManager.get_mech_at(tile)
	if not target:
		target = BuildManager.wiring_manager.get_wire_instance(tile)

	if target != _hovered_for_deletion:
		_clear_delete_highlight()
		_hovered_for_deletion = target
		if is_instance_valid(_hovered_for_deletion):
			_highlight_node_tree(_hovered_for_deletion, Color(1, 0.3, 0.3, 1))

func _highlight_node_tree(node: Node, col: Color):
	if not is_instance_valid(node): return
	
	if node is MeshInstance3D:
		pass
	if node is CanvasItem: 
		node.modulate = col
	for child in node.get_children():
		_highlight_node_tree(child, col)

func _clear_delete_highlight() -> void:
	if is_instance_valid(_hovered_for_deletion):
		_highlight_node_tree(_hovered_for_deletion, Color.WHITE)
		if _hovered_for_deletion.has_method("_on_power_status_changed") and "is_active" in _hovered_for_deletion:
			_hovered_for_deletion._on_power_status_changed(_hovered_for_deletion.is_active)
	_hovered_for_deletion = null
