extends Node

## Manages all lane data, grid state, and resource mappings.
## Acts as the central Grid Authority.

@export_range(0.0, 1.0) var ore_rarity: float = 0.12

# Generation offset determines logical grid placement in the physical world.
@export var generation_offset: Vector2i = Vector2i(0, 0)

@export_group("Visual Corrections (Logical Units)")
## Visual offset for the Ore TileMapLayer.
## X = Lane Shift (Width), Y = Depth Shift (Length).
## Default (0,0) now maps to the legacy (1,1) position internally.
@export var ore_offset: Vector2 = Vector2(0, 0)

## Visual offset for Wiring entities.
## X = Lane Shift (Width), Y = Depth Shift (Length).
## Default (0,0) maps to the internal base offset (0.5, 0.5) for tile centering.
@export var wire_offset: Vector2 = Vector2(0, 0)

## Visual offset for Building entities.
## X = Lane Shift (Width), Y = Depth Shift (Length).
@export var building_offset: Vector2 = Vector2(0, 0)

# Layer Z-Indices (Base values)
const Z_LAYERS = {
	"ore": 0,
	"wire": 1,
	"building": 5, 
	"projectile": 20
}

var tile_map: TileMapLayer
var ore_layer: TileMapLayer

var lane_paths: Dictionary = {}
var grid_state: Dictionary = {}
var _tile_to_logical_map: Dictionary = {}

var ores: Dictionary = {} 
var ore_tile_data: Dictionary = {} 

const NUM_LANES = 5
const LANE_LENGTH = 30

# Cache for basis vectors to avoid recalculating every frame
var _lane_basis_vec: Vector2 = Vector2.ZERO
var _depth_basis_vec: Vector2 = Vector2.ZERO

func _ready() -> void:
	print("LaneManager Initialized.")
	_load_resources()
	call_deferred("_initialize")

func _load_resources() -> void:
	# Scan for all items and register those that are Ores
	ores.clear()
	ore_tile_data.clear()
	
	var dir_path = "res://resources/items/"
	var dir = DirAccess.open(dir_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var item = load(dir_path + file_name) as ItemResource
				if item and item.is_ore:
					ores[item.item_name] = item
					# Source ID is assumed 0 for the main ore tileset
					ore_tile_data[item.item_name] = { "source": 0, "coords": item.ore_atlas_coords }
					print("LaneManager: Registered Ore '%s' at Atlas %s" % [item.item_name, item.ore_atlas_coords])
			file_name = dir.get_next()
	else:
		printerr("LaneManager: Could not open items directory.")
		
	# Fallback if no ores loaded (e.g. first run before import)
	if ores.is_empty():
		printerr("LaneManager: No Ores loaded! Please run DataImporter.")

func _initialize() -> void:
	var main_scene = get_tree().current_scene
	if main_scene:
		tile_map = main_scene.get_node_or_null("TileMapLayer")
		ore_layer = main_scene.get_node_or_null("OreLayer")
		
	if not is_instance_valid(tile_map):
		printerr("LaneManager could not find TileMapLayer!")
		return
	
	_calculate_basis_vectors()
	
	# Apply visual correction to the OreLayer node itself
	if is_instance_valid(ore_layer):
		ore_layer.position = get_layer_offset("ore")
	
	_generate_lane_data()
	_generate_ores()
	print("LaneManager: Grid initialized.")

func _calculate_basis_vectors() -> void:
	if not is_instance_valid(tile_map): return
	
	# To determine the visual direction of "Lane" (X) and "Depth" (Y),
	# we sample the physical layout of the grid generator.
	
	# Origin (Lane 0, Depth 0)
	var t0 = _calculate_physical_coord(0, 0)
	var p0 = tile_map.map_to_local(t0)
	
	# Lane Step (Lane 1, Depth 0)
	var t_lane = _calculate_physical_coord(1, 0)
	var p_lane = tile_map.map_to_local(t_lane)
	
	# Depth Step (Lane 0, Depth 1)
	var t_depth = _calculate_physical_coord(0, 1)
	var p_depth = tile_map.map_to_local(t_depth)
	
	_lane_basis_vec = p_lane - p0
	_depth_basis_vec = p_depth - p0
	
	print("LaneManager Basis Vectors Calculated:")
	print("  T0 (0,0): %s -> %s" % [t0, p0])
	print("  Lane (X) Vector: ", _lane_basis_vec)
	print("  Depth (Y) Vector: ", _depth_basis_vec)

func _generate_lane_data() -> void:
	_tile_to_logical_map.clear()
	lane_paths.clear()

	for lane_id in range(NUM_LANES):
		var physical_path: Array[Vector2i] = []
		for depth in range(LANE_LENGTH):
			var tile = _calculate_physical_coord(lane_id, depth)
			physical_path.append(tile)
		
		if not physical_path.is_empty():
			lane_paths[lane_id] = physical_path
			for i in range(physical_path.size()):
				var tile_coord = physical_path[i]
				_tile_to_logical_map[tile_coord] = Vector2i(lane_id, i)

func _calculate_physical_coord(lane_id: int, depth: int) -> Vector2i:
	var start_y = -(7 + lane_id) + generation_offset.y
	var start_x = 2 - floori(lane_id / 2.0) + generation_offset.x
	
	var x: int
	var y = start_y - depth
	
	if lane_id % 2 == 0:
		x = start_x + int(ceil(depth / 2.0))
	else:
		x = start_x + int(floor(depth / 2.0))
		
	return Vector2i(x, y)

func _generate_ores() -> void:
	if not is_instance_valid(ore_layer): return
	if ore_tile_data.is_empty(): return
	
	for coord in grid_state.keys():
		if grid_state[coord].has("ore"):
			grid_state[coord].erase("ore")
	ore_layer.clear()
	
	var available_keys = ore_tile_data.keys()
	
	# Calculate visual offset for data storage logic
	# We start with the full render offset (including the +1,1 shift)
	var render_offset = get_layer_offset("ore")
	# We calculate the vector corresponding to the (1,1) logical shift
	var shift_correction = (_lane_basis_vec * 1.0) + (_depth_basis_vec * 1.0)
	# We subtract it, because the user reports data is 1 unit "higher" than visual
	var data_offset = render_offset - shift_correction
	
	for lane in range(NUM_LANES):
		for depth in range(-1, LANE_LENGTH):
			if randf() < ore_rarity:
				var tile_coord = _calculate_physical_coord(lane, depth)
				if tile_map.get_cell_source_id(tile_coord) != -1:
					var key = available_keys.pick_random()
					
					# Determine Visual Tile for Data Storage
					# Use the corrected data_offset to align grid_state with visual appearance
					var visual_pos = tile_map.map_to_local(tile_coord) + data_offset
					var visual_tile = tile_map.local_to_map(visual_pos)
					
					add_ore_at(tile_coord, visual_tile, key)

func register_entity(entity: Node, coord: Vector2i, layer: String) -> void:
	if not grid_state.has(coord):
		grid_state[coord] = {}
	grid_state[coord][layer] = entity

func log_placement(entity: Node, coord: Vector2i, layer: String) -> void:
	if not entity is Node2D: return
	var logical = get_logical_from_tile(coord)
	var world_pos = entity.global_position
	var z_val = entity.z_index
	var log_str = "N/A"
	if logical != Vector2i(-1, -1):
		log_str = "[L:%d, D:%d]" % [logical.x, logical.y]
	print("GRID_PLACE: %s (%s) | Tile: %s | Logical: %s | Global: (%.1f, %.1f) | Z: %d" % 
		[entity.name, layer, coord, log_str, world_pos.x, world_pos.y, z_val])

func unregister_entity(coord: Vector2i, layer: String) -> void:
	if grid_state.has(coord) and grid_state[coord].has(layer):
		grid_state[coord].erase(layer)
		if grid_state[coord].is_empty():
			grid_state.erase(coord)

func get_entity_at(coord: Vector2i, layer: String) -> Node:
	if grid_state.has(coord) and grid_state[coord].has(layer):
		return grid_state[coord][layer]
	return null

# --- Coordinate Helpers (Adjusted for Visual Correction) ---

## Returns the pixel offset based on logical grid basis vectors.
func get_layer_offset(layer: String) -> Vector2:
	if not is_instance_valid(tile_map): return Vector2.ZERO
	if _lane_basis_vec == Vector2.ZERO: _calculate_basis_vectors()
	
	var logical_offset = Vector2.ZERO
	match layer:
		# BASE CORRECTION: (1, 1) is added to ore_offset to make (0,0) the new default that matches old behavior
		"ore": logical_offset = ore_offset + Vector2(1, 1)
		# BASE CORRECTION: (0.5, 0.5) is added to wire_offset to make (0,0) the new default
		"wire": logical_offset = wire_offset + Vector2(0.5, 0.5)
		"building": logical_offset = building_offset
	
	# Apply basis vectors: x -> lane, y -> depth
	return (_lane_basis_vec * logical_offset.x) + (_depth_basis_vec * logical_offset.y)

func tile_to_world(coord: Vector2i) -> Vector2:
	if is_instance_valid(tile_map):
		return tile_map.map_to_local(coord)
	return Vector2.ZERO

func world_to_tile(pos: Vector2) -> Vector2i:
	if is_instance_valid(tile_map):
		return tile_map.local_to_map(pos)
	return Vector2i.ZERO

func snap_node_to_grid(node: Node2D, layer: String) -> void:
	# Calculate tile based on raw position relative to grid
	# (Input pos assumed to be visual, so we subtract offset to find grid home)
	var offset = get_layer_offset(layer)
	var tile = world_to_tile(node.global_position - offset)
	
	# Get center of that tile
	var centered_pos = tile_to_world(tile)
	
	# Apply offset back for visual position
	node.global_position = centered_pos + offset
	
	if Z_LAYERS.has(layer):
		node.z_index = Z_LAYERS[layer]

# --- Resource Management ---

func add_ore_at(source_tile: Vector2i, visual_tile: Vector2i, ore_key: String) -> void:
	if not ores.has(ore_key): return
	
	# Store data at Visual Tile (where the player sees it, and where Drills look)
	if not grid_state.has(visual_tile): grid_state[visual_tile] = {}
	grid_state[visual_tile]["ore"] = ores[ore_key]
	
	# Render at Source Tile (because OreLayer position is shifted)
	if is_instance_valid(ore_layer) and ore_tile_data.has(ore_key):
		var data = ore_tile_data[ore_key]
		ore_layer.set_cell(source_tile, data.source, data.coords)

func get_ore_at(tile_coord: Vector2i) -> ItemResource:
	if grid_state.has(tile_coord) and grid_state[tile_coord].has("ore"):
		return grid_state[tile_coord]["ore"]
	return null

func get_ore_at_world_pos(world_pos: Vector2) -> ItemResource:
	# No offset subtraction! 
	# Data is now stored at the visual tile index directly.
	var tile = world_to_tile(world_pos)
	return get_ore_at(tile)

func is_valid_tile(tile_coord: Vector2i) -> bool:
	return _tile_to_logical_map.has(tile_coord)

func get_logical_from_tile(tile_coord: Vector2i) -> Vector2i:
	return _tile_to_logical_map.get(tile_coord, Vector2i(-1, -1))

func get_tile_from_logical(lane_id: int, depth: int) -> Vector2i:
	if not lane_paths.has(lane_id): return Vector2i(-1, -1)
	if depth >= 0 and depth < lane_paths[lane_id].size():
		return lane_paths[lane_id][depth]
	return Vector2i(-1, -1)

func get_buildable_at(coord: Vector2i) -> Node:
	return get_entity_at(coord, "building")

func get_lane_start_world_pos(lane_id: int) -> Vector2:
	if not lane_paths.has(lane_id) or lane_paths[lane_id].is_empty(): return Vector2.ZERO
	# Apply building offset so enemies spawn aligned with buildings
	return tile_to_world(lane_paths[lane_id][-1]) + get_layer_offset("building")

func get_lane_end_world_pos(lane_id: int) -> Vector2:
	if not lane_paths.has(lane_id) or lane_paths[lane_id].is_empty(): return Vector2.ZERO
	return tile_to_world(lane_paths[lane_id][0]) + get_layer_offset("building")

## Returns the path array for a given lane ID.
func get_path_for_lane(lane_id: int) -> Array[Vector2i]:
	if lane_paths.has(lane_id):
		return lane_paths[lane_id]
	return []
