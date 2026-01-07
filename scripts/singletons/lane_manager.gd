extends Node

## Manages all lane data, grid state, and resource mappings in 3D.
## Acts as the central Grid Authority.

@export_range(0.0, 1.0) var ore_rarity: float = 0.12 # Legacy override, items now control own rarity

# Generation offset determines logical grid placement.
@export var generation_offset: Vector2i = Vector2i(0, 0)

@export_group("Visual Corrections (World Units)")
@export var ore_offset: Vector3 = Vector3(0, 0, 0)
@export var wire_offset: Vector3 = Vector3(0, 0.05, 0)
@export var building_offset: Vector3 = Vector3(0, 0.0, 0)

# World Grid Scale (1 Unit = 1 Tile)
const GRID_SCALE: float = 1.0

# Layer Y-Indices (Height)
# Relative to floor (Y=0). 
# GridMap Blocks are 1.0 high (0 to 1). Objects should sit on top (1.0).
const Y_LAYERS = {
	"ore": 1.0,      
	"wire": 1.0,     
	"building": 1.0,  
	"projectile": 1.5 
}

var grid_map: GridMap
var lane_paths: Dictionary = {}
var grid_state: Dictionary = {}
var _tile_to_logical_map: Dictionary = {}

# Stores world positions of "Spawner" blocks found in DevMap
var spawn_points: Array[Vector3] = []

var ores: Array[ItemResource] = [] 
# Caches Map: Block ID (int) -> ItemResource
var block_id_to_item_map: Dictionary = {}
var block_name_to_id_map: Dictionary = {}

const NUM_LANES = 5
const LANE_LENGTH = 30

func _ready() -> void:
	print("LaneManager 3D Initialized.")
	_load_resources()

func _load_resources() -> void:
	ores.clear()
	var dir_path = "res://resources/items/"
	var dir = DirAccess.open(dir_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var item = load(dir_path + file_name) as ItemResource
				if item and item.is_ore:
					ores.append(item)
					print("LaneManager: Registered Ore '%s' (Block: %s)" % [item.item_name, item.ore_block_name])
			file_name = dir.get_next()
	else:
		printerr("LaneManager: Could not open items directory.")

func initialize_grid(map: GridMap) -> void:
	self.grid_map = map
	_build_block_cache()
	_initialize()

func _build_block_cache() -> void:
	if not grid_map or not grid_map.mesh_library: return
	
	block_id_to_item_map.clear()
	block_name_to_id_map.clear()
	
	var lib = grid_map.mesh_library
	for id in lib.get_item_list():
		var block_name = lib.get_item_name(id)
		block_name_to_id_map[block_name] = id
		
		# Reverse match against loaded ores
		for item in ores:
			if item.ore_block_name == block_name:
				block_id_to_item_map[id] = item
				break

func _initialize() -> void:
	_generate_lane_data()
	
	# Only generate ores if we have a valid GridMap
	if grid_map:
		print("LaneManager: Generating Ore Blocks...")
		_generate_ores()
	else:
		printerr("LaneManager: Cannot generate ores, GridMap reference missing.")

	print("LaneManager: Grid initialized.")

func _generate_lane_data() -> void:
	_tile_to_logical_map.clear()
	lane_paths.clear()

	# Lanes 0-4 are Z coordinates.
	# Depth starts at X=0 and increments.
	for lane_idx in range(NUM_LANES):
		var physical_path: Array[Vector2i] = []
		for depth in range(LANE_LENGTH):
			# X = Depth + Offset, Z = Lane + Offset
			var x = depth + generation_offset.x
			var z = lane_idx + generation_offset.y
			var tile = Vector2i(x, z)
			
			physical_path.append(tile)
		
		lane_paths[lane_idx] = physical_path
		
		for i in range(physical_path.size()):
			var tile_coord = physical_path[i]
			_tile_to_logical_map[tile_coord] = Vector2i(lane_idx, i)

func _calculate_grid_coord(lane_id: int, depth: int) -> Vector2i:
	var x = depth + generation_offset.x
	var z = lane_id + generation_offset.y
	return Vector2i(x, z)

func _generate_ores() -> void:
	if ores.is_empty(): return
	
	var count = 0
	for lane in range(NUM_LANES):
		for depth in range(0, LANE_LENGTH):
			var tile_coord = _calculate_grid_coord(lane, depth)
			
			# Find a valid ore for this depth
			var valid_ores = []
			for ore in ores:
				if depth >= ore.min_depth and depth <= ore.max_depth:
					valid_ores.append(ore)
			
			if valid_ores.is_empty(): continue
			
			# Roll for each valid ore (priority could be improved, but this works for now)
			# To prevent overlapping, we pick one success
			var picked_ore = null
			valid_ores.shuffle()
			
			for ore in valid_ores:
				if randf() < ore.rarity:
					picked_ore = ore
					break
			
			if picked_ore:
				_place_ore_block(tile_coord, picked_ore)
				count += 1
	
	print("LaneManager: Placed %d ore blocks." % count)

func _place_ore_block(coord: Vector2i, item: ItemResource) -> void:
	if not grid_map: return
	
	var block_name = item.ore_block_name
	if block_name_to_id_map.has(block_name):
		var id = block_name_to_id_map[block_name]
		# Set cell in GridMap. Y=0 is the floor.
		grid_map.set_cell_item(Vector3i(coord.x, 0, coord.y), id)
	else:
		printerr("LaneManager: Block '%s' not found in MeshLibrary for ore '%s'" % [block_name, item.item_name])

# --- Spawner Scanning ---

func scan_for_spawners(dev_map: GridMap) -> void:
	if not dev_map or not dev_map.mesh_library: return
	
	spawn_points.clear()
	var lib = dev_map.mesh_library
	var spawner_id = -1
	
	# Find ID for "Spawner" block
	for id in lib.get_item_list():
		if lib.get_item_name(id) == "Spawner":
			spawner_id = id
			break
			
	if spawner_id == -1:
		print("LaneManager: 'Spawner' block not found in MeshLibrary.")
		return
		
	var cells = dev_map.get_used_cells()
	for cell in cells:
		if dev_map.get_cell_item(cell) == spawner_id:
			# Convert grid coord to world position
			# DevMap usually aligned with Main GridMap
			var world_pos = dev_map.to_global(dev_map.map_to_local(cell))
			# Add offset to spawn on top of the block
			spawn_points.append(world_pos + Vector3(0, 1.0, 0))

	print("LaneManager: Found %d spawn points." % spawn_points.size())

# --- Entity Management ---

func register_entity(entity: Node, coord: Vector2i, layer: String) -> void:
	if not grid_state.has(coord):
		grid_state[coord] = {}
	grid_state[coord][layer] = entity

func unregister_entity(coord: Vector2i, layer: String) -> void:
	if grid_state.has(coord) and grid_state[coord].has(layer):
		grid_state[coord].erase(layer)
		if grid_state[coord].is_empty():
			grid_state.erase(coord)

func get_entity_at(coord: Vector2i, layer: String) -> Node:
	if grid_state.has(coord) and grid_state[coord].has(layer):
		var entity = grid_state[coord][layer]
		if is_instance_valid(entity):
			return entity
		else:
			grid_state[coord].erase(layer)
			if grid_state[coord].is_empty():
				grid_state.erase(coord)
	return null

# --- Coordinate Helpers (3D) ---

func get_layer_offset(layer: String) -> Vector3:
	var base = Vector3.ZERO
	match layer:
		"ore": base = ore_offset
		"wire": base = wire_offset
		"building": base = building_offset
	
	if Y_LAYERS.has(layer):
		base.y += Y_LAYERS[layer]
		
	return base

func tile_to_world(coord: Vector2i) -> Vector3:
	return Vector3(coord.x * GRID_SCALE + (0.5 * GRID_SCALE), 0.0, coord.y * GRID_SCALE + (0.5 * GRID_SCALE))

func world_to_tile(pos: Vector3) -> Vector2i:
	var x = int(floor(pos.x / GRID_SCALE))
	var z = int(floor(pos.z / GRID_SCALE))
	return Vector2i(x, z)

func snap_node_to_grid(node: Node3D, layer: String) -> void:
	var offset = get_layer_offset(layer)
	var tile = world_to_tile(node.global_position)
	var centered_pos = tile_to_world(tile)
	node.global_position = centered_pos + offset

# --- Resource Retrieval ---

## Returns the ItemResource associated with the GridMap block at this location (Y=0).
func get_ore_at_world_pos(world_pos: Vector3) -> ItemResource:
	if not grid_map: return null
	
	# Determine the map coordinate for the floor (Y=0)
	# world_pos usually comes from a building at Y=0.5, so we convert directly
	var local_pos = grid_map.to_local(world_pos)
	var cell = grid_map.local_to_map(local_pos)
	
	# Force check at Y=0
	var block_id = grid_map.get_cell_item(Vector3i(cell.x, 0, cell.z))
	
	if block_id != GridMap.INVALID_CELL_ITEM:
		return block_id_to_item_map.get(block_id, null)
		
	return null

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

func get_lane_start_world_pos(lane_id: int) -> Vector3:
	if not lane_paths.has(lane_id) or lane_paths[lane_id].is_empty(): return Vector3.ZERO
	var idx = 0 
	return tile_to_world(lane_paths[lane_id][idx]) + get_layer_offset("building")

func get_lane_end_world_pos(lane_id: int) -> Vector3:
	if not lane_paths.has(lane_id) or lane_paths[lane_id].is_empty(): return Vector3.ZERO
	return tile_to_world(lane_paths[lane_id][-1]) + get_layer_offset("building")

func get_path_for_lane(lane_id: int) -> Array[Vector2i]:
	if lane_paths.has(lane_id):
		return lane_paths[lane_id]
	return []
