extends Node3D
class_name MainLevel

## The main script for the primary game scene in 3D.
## Refactored into separate controllers for camera, building, and selection.

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

var player: CharacterBody3D 
const PLAYER_SCENE = preload("res://scenes/allies/player.tscn")

var build_preview_container: Node3D
var indicator_container: Node3D
var fog_mesh: MeshInstance3D

enum LayerMode { ALL, BUILDING_ONLY, WIRE_ONLY }
var current_layer_mode: LayerMode = LayerMode.ALL

var camera_controller
var build_controller
var selection_controller

func _ready() -> void:
	if not has_node("ToolManager"):
		var tm = ToolManager.new()
		tm.name = "ToolManager"
		add_child(tm)
	
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
	
	_setup_fog()
	_update_layer_visibility()
	_spawn_player()
	
	# Initialize controllers
	camera_controller = load("res://scripts/controllers/camera_controller.gd").new()
	camera_controller.setup(self)
	add_child(camera_controller)
	
	build_controller = load("res://scripts/controllers/build_controller.gd").new()
	build_controller.setup(self)
	add_child(build_controller)
	
	selection_controller = load("res://scripts/controllers/selection_controller.gd").new()
	selection_controller.setup(self)
	add_child(selection_controller)
	
	PlayerManager.equipped_item_changed.connect(_on_equipped_item_changed)

func _setup_fog() -> void:
	fog_mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	var unexplored_length = LaneManager.LANE_LENGTH - 15
	box.size = Vector3(unexplored_length * LaneManager.GRID_SCALE, 2.0, LaneManager.num_lanes * LaneManager.GRID_SCALE)
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0, 0, 0, 0.85)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	box.material = mat
	fog_mesh.mesh = box
	
	var start_x = 15 * LaneManager.GRID_SCALE
	var center_x = start_x + (unexplored_length * LaneManager.GRID_SCALE) / 2.0
	var center_z = (LaneManager.num_lanes * LaneManager.GRID_SCALE) / 2.0
	
	fog_mesh.global_position = Vector3(center_x, 1.0, center_z)
	add_child(fog_mesh)

func _spawn_player() -> void:
	player = PLAYER_SCENE.instantiate()
	player.name = "Player"
	add_child(player)
	
	var target_pos = LaneManager.get_valid_ally_spawn_pos()
	player.global_position = target_pos

func _process(delta: float) -> void:
	camera_controller.handle_camera_movement(delta)
	
	# Determine transparency for Core
	var ray_for_transparency = get_mouse_raycast()
	var hovering_core = false
	if ray_for_transparency and ray_for_transparency.get("collider") == core:
		hovering_core = true
	if is_instance_valid(core):
		core.set_transparent(hovering_core)

	var interaction_exclude =[]
	if is_instance_valid(core): interaction_exclude.append(core.get_rid())

	if BuildManager.is_building:
		if BuildManager.selected_buildable:
			if BuildManager.selected_buildable.layer != BuildableResource.BuildLayer.TOOL:
				for child in buildings_container.get_children():
					if child is CollisionObject3D:
						interaction_exclude.append(child.get_rid())
	
	# 1. Selection Ray: Standard mask
	var selection_ray = get_mouse_raycast(interaction_exclude) 
	
	# 2. Terrain Ray: Mask 1 only
	var terrain_ray = get_mouse_raycast(interaction_exclude, 1)

	var mouse_world_pos = Vector3.ZERO
	if terrain_ray: 
		mouse_world_pos = terrain_ray.position + (terrain_ray.normal * 0.5)
	else: 
		mouse_world_pos = get_plane_intersection()
	
	var cursor_target = mouse_world_pos
	if PlayerManager.equipped_item and PlayerManager.equipped_item.tool_type == "drill":
		if is_instance_valid(player): cursor_target = player.global_position

	selection_controller.update(selection_ray, terrain_ray, mouse_world_pos, cursor_target)
	build_controller.update(mouse_world_pos)
	handle_debug_display(terrain_ray, selection_ray, mouse_world_pos)

func get_mouse_raycast(exclude: Array =[], mask: int = 4294967295) -> Dictionary:
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
		if not is_mouse_over_ui():
			camera_controller.handle_zoom(event)
	
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
		elif selection_controller.has_selection():
			selection_controller.deselect_all(); handled = true
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
		selection_controller.selected_wire_coords = Vector2i(-1, -1)
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

func is_mouse_over_ui() -> bool:
	var mouse_pos = get_viewport().get_mouse_position()
	for ui_rect in game_ui.get_ui_rects():
		if ui_rect.has_point(mouse_pos): return true
	return false

func handle_debug_display(terrain_ray: Dictionary, sel_ray: Dictionary, world_pos: Vector3) -> void:
	var cell = Vector3i.ZERO
	var ore_info = "None"
	var entity_info = ""
	
	var tm = get_node_or_null("ToolManager")
	var is_player_mining = false
	if tm and is_instance_valid(player) and tm.active_miners.has(player): is_player_mining = true

	if not is_player_mining:
		if grid_map:
			var snapped_pos = terrain_ray.position + (terrain_ray.normal * 0.5) if terrain_ray else world_pos
			cell = grid_map.local_to_map(grid_map.to_local(snapped_pos))
			var tile_center = LaneManager.tile_to_world(Vector2i(cell.x, cell.z))
			var ore = LaneManager.get_ore_at_world_pos(tile_center)
			if ore: ore_info = ore.item_name
		
		if sel_ray and sel_ray.get("collider"):
			var col = sel_ray.get("collider")
			if col is BaseBuilding:
				entity_info += "\n[Entity: %s]" % col.name
		
		var mode_name = LayerMode.keys()[current_layer_mode]
		var debug_str = "Layer Mode: %s\nTile(X,Z): %d, %d\nOre: %s%s" %[mode_name, cell.x, cell.z, ore_info, entity_info]
		if game_ui: game_ui.set_debug_text(debug_str)

func _on_equipped_item_changed(item: ItemResource) -> void:
	if item and item.is_tool: Input.set_custom_mouse_cursor(item.icon)
	else: Input.set_custom_mouse_cursor(null)
