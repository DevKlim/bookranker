extends Node

## Manages all lane data, grid state, and resource mappings in 3D.
## Acts as the central Grid Authority and Pathfinding Server.

@export_range(0.0, 1.0) var ore_rarity: float = 0.12 
@export var generation_offset: Vector2i = Vector2i(0, 0)

@export_group("Visual Corrections (World Units)")
@export var ore_offset: Vector3 = Vector3(0, 0, 0)
@export var wire_offset: Vector3 = Vector3(0, 0.05, 0)
@export var building_offset: Vector3 = Vector3(0, 0.0, 0)

const GRID_SCALE: float = 1.0
const Y_LAYERS = {
	"ore": 1.0,      
	"wire": 1.0,     
	"building": 1.0,  
	"projectile": 1.5 
}

var grid_map: GridMap
var lane_paths: Dictionary = {}
var grid_state: Dictionary = {} # { Vector2i: { "building": Node, "wire": Node } }
var _tile_to_logical_map: Dictionary = {}

# Pathfinding
var astar: AStarGrid2D

var spawners_by_lane: Dictionary = {}
var ores: Array[ItemResource] = []
var clutter_types: Array[ClutterResource] = []
var block_id_to_item_map: Dictionary = {}
var block_name_to_id_map: Dictionary = {}

var enemies_by_lane: Dictionary = {}
var enemy_spatial_map: Dictionary = {}

const NUM_LANES = 5
# Increased length to support field enemies spawning deeper in the map
const LANE_LENGTH = 100

func _ready() -> void:
	_init_astar()
	for i in range(NUM_LANES):
		enemies_by_lane[i] = []
	_load_resources()

func _init_astar() -> void:
	astar = AStarGrid2D.new()
	var x_start = -50 + generation_offset.x
	var x_size = 200 
	astar.region = Rect2i(x_start, generation_offset.y, x_size, NUM_LANES)
	astar.cell_size = Vector2(GRID_SCALE, GRID_SCALE)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER 
	astar.update()

func _load_resources() -> void:
	ores.clear()
	var dir_path = "res://resources/items/"
	var dir = DirAccess.open(dir_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var full_path = dir_path + file_name
				if ResourceLoader.exists(full_path):
					var item = load(full_path) as ItemResource
					if item and item.is_ore:
						ores.append(item)
			file_name = dir.get_next()
	
	clutter_types.clear()
	var cl_path = "res://resources/clutter/"
	var c_dir = DirAccess.open(cl_path)
	if c_dir:
		c_dir.list_dir_begin()
		var file = c_dir.get_next()
		while file != "":
			if not c_dir.current_is_dir() and file.ends_with(".tres"):
				var res = load(cl_path + file) as ClutterResource
				if res: clutter_types.append(res)
			file = c_dir.get_next()

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
		for item in ores:
			if item.ore_block_name == block_name:
				block_id_to_item_map[id] = item
				break

func _initialize() -> void:
	_generate_lane_data()
	if grid_map: 
		_generate_ores()
		_generate_clutter()
		_generate_terrain()

func _generate_lane_data() -> void:
	_tile_to_logical_map.clear()
	lane_paths.clear()
	for lane_idx in range(NUM_LANES):
		var physical_path: Array[Vector2i] = []
		for depth in range(LANE_LENGTH):
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
	_generate_guaranteed_ores()
	for lane in range(NUM_LANES):
		for depth in range(0, LANE_LENGTH):
			var tile_coord = _calculate_grid_coord(lane, depth)
			var cell_pos = Vector3i(tile_coord.x, 0, tile_coord.y)
			if grid_map.get_cell_item(cell_pos) != GridMap.INVALID_CELL_ITEM: continue
			var valid_ores = []
			for ore in ores:
				if depth >= ore.min_depth and depth <= ore.max_depth:
					valid_ores.append(ore)
			if valid_ores.is_empty(): continue
			var picked_ore = null
			valid_ores.shuffle()
			for ore in valid_ores:
				if randf() < ore.rarity:
					picked_ore = ore
					break
			if picked_ore:
				_place_ore_block(tile_coord, picked_ore)

func _generate_guaranteed_ores() -> void:
	for ore in ores:
		if ore.guaranteed_spawns <= 0: continue
		var placed = 0
		var attempts = 0
		while placed < ore.guaranteed_spawns and attempts < 1000:
			attempts += 1
			var lane = randi() % NUM_LANES
			var max_d = min(ore.max_depth, LANE_LENGTH - 1)
			if max_d < ore.min_depth: continue
			var depth = randi_range(ore.min_depth, max_d)
			var coord = _calculate_grid_coord(lane, depth)
			var cell_pos = Vector3i(coord.x, 0, coord.y)
			if grid_map.get_cell_item(cell_pos) == GridMap.INVALID_CELL_ITEM:
				_place_ore_block(coord, ore)
				placed += 1

func _generate_terrain() -> void:
	if not grid_map: return
	var terrain_layers = [ { "depth": 5, "block": "Dirt" }, { "depth": LANE_LENGTH, "block": "Stone" } ]
	for lane in range(NUM_LANES):
		for depth in range(LANE_LENGTH):
			var tile_coord = _calculate_grid_coord(lane, depth)
			var cell_pos = Vector3i(tile_coord.x, 0, tile_coord.y)
			if grid_map.get_cell_item(cell_pos) != GridMap.INVALID_CELL_ITEM: continue
			var block_to_place = "Stone"
			for layer in terrain_layers:
				if depth <= layer.depth:
					block_to_place = layer.block
					break
			if block_name_to_id_map.has(block_to_place):
				grid_map.set_cell_item(cell_pos, block_name_to_id_map[block_to_place])

func _generate_clutter() -> void:
	if clutter_types.is_empty(): return
	var root = get_tree().current_scene
	var parent_node = root.get_node_or_null("Buildings")
	if not parent_node: parent_node = root
	_generate_guaranteed_clutter(parent_node)
	for lane in range(NUM_LANES):
		for depth in range(0, LANE_LENGTH):
			var tile_coord = _calculate_grid_coord(lane, depth)
			if get_entity_at(tile_coord, "building"): continue
			if get_ore_at_world_pos(tile_to_world(tile_coord)): continue
			var valid_clutter = []
			for c in clutter_types:
				if depth >= c.min_depth and depth <= c.max_depth:
					valid_clutter.append(c)
			if valid_clutter.is_empty(): continue
			valid_clutter.shuffle()
			var picked = null
			for c in valid_clutter:
				if randf() < c.rarity:
					picked = c
					break
			if picked:
				_spawn_clutter_at(tile_coord, picked, parent_node)

func _generate_guaranteed_clutter(parent_node: Node) -> void:
	for clutter in clutter_types:
		if clutter.guaranteed_spawns <= 0: continue
		var placed = 0
		var attempts = 0
		while placed < clutter.guaranteed_spawns and attempts < 1000:
			attempts += 1
			var lane = randi() % NUM_LANES
			var max_d = min(clutter.max_depth, LANE_LENGTH - 1)
			if max_d < clutter.min_depth: continue
			var depth = randi_range(clutter.min_depth, max_d)
			var tile_coord = _calculate_grid_coord(lane, depth)
			if get_entity_at(tile_coord, "building"): continue
			if get_ore_at_world_pos(tile_to_world(tile_coord)): continue
			_spawn_clutter_at(tile_coord, clutter, parent_node)
			placed += 1

func _spawn_clutter_at(coord: Vector2i, clutter: ClutterResource, parent: Node) -> void:
	var inst = clutter.scene.instantiate()
	if inst is ClutterObject:
		inst.clutter_resource = clutter
	parent.add_child(inst)
	inst.global_position = tile_to_world(coord) + building_offset + Vector3(0, 1.0, 0)

func _place_ore_block(coord: Vector2i, item: ItemResource) -> void:
	if not grid_map: return
	var block_name = item.ore_block_name
	if block_name_to_id_map.has(block_name):
		var id = block_name_to_id_map[block_name]
		grid_map.set_cell_item(Vector3i(coord.x, 0, coord.y), id)

func register_entity(entity: Node, coord: Vector2i, layer: String) -> void:
	if not grid_state.has(coord): grid_state[coord] = {}
	grid_state[coord][layer] = entity
	if layer == "building":
		astar.set_point_solid(coord, true)

func unregister_entity(coord: Vector2i, layer: String) -> void:
	if grid_state.has(coord) and grid_state[coord].has(layer):
		grid_state[coord].erase(layer)
		if grid_state[coord].is_empty(): grid_state.erase(coord)
	if layer == "building":
		astar.set_point_solid(coord, false)

func get_entity_at(coord: Vector2i, layer: String) -> Node:
	if grid_state.has(coord) and grid_state[coord].has(layer):
		var entity = grid_state[coord][layer]
		if is_instance_valid(entity): return entity
		else:
			grid_state[coord].erase(layer)
			if grid_state[coord].is_empty(): grid_state.erase(coord)
			if layer == "building": astar.set_point_solid(coord, false)
	return null

func get_path_world(from_pos: Vector3, to_pos: Vector3) -> Array[Vector3]:
	var start_tile = world_to_tile(from_pos)
	var end_tile = world_to_tile(to_pos)
	
	# Prevent pathing to self
	if start_tile == end_tile:
		return []
	
	if not astar.region.has_point(start_tile): start_tile = _clamp_to_bounds(start_tile)
	if not astar.region.has_point(end_tile): end_tile = _clamp_to_bounds(end_tile)
	
	var id_path = astar.get_id_path(start_tile, end_tile)
	var world_path: Array[Vector3] = []
	for point in id_path:
		world_path.append(tile_to_world(point))
	return world_path

func get_path_for_enemy(lane_id: int, start_pos: Vector3) -> Array[Vector3]:
	var target_tile = _calculate_grid_coord(lane_id, 0)
	var target_pos = tile_to_world(target_tile)
	return get_path_world(start_pos, target_pos)

func _clamp_to_bounds(tile: Vector2i) -> Vector2i:
	var r = astar.region
	var x = clamp(tile.x, r.position.x, r.end.x - 1)
	var y = clamp(tile.y, r.position.y, r.end.y - 1)
	return Vector2i(x, y)

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

func get_layer_offset(layer: String) -> Vector3:
	var base = Vector3.ZERO
	match layer:
		"ore": base = ore_offset
		"wire": base = wire_offset
		"building": base = building_offset
	if Y_LAYERS.has(layer): base.y += Y_LAYERS[layer]
	return base

func get_ore_at_world_pos(world_pos: Vector3) -> ItemResource:
	if not grid_map: return null
	var local_pos = grid_map.to_local(world_pos)
	var cell = grid_map.local_to_map(local_pos)
	var block_id = grid_map.get_cell_item(Vector3i(cell.x, 0, cell.z))
	if block_id != GridMap.INVALID_CELL_ITEM:
		return block_id_to_item_map.get(block_id, null)
	return null

func scan_for_spawners(dev_map: GridMap) -> void:
	if not dev_map or not dev_map.mesh_library: return
	spawners_by_lane.clear()
	var lib = dev_map.mesh_library
	var spawner_id = -1
	for id in lib.get_item_list():
		if lib.get_item_name(id) == "Spawner":
			spawner_id = id
			break
	if spawner_id == -1: return
	var cells = dev_map.get_used_cells()
	for cell in cells:
		if dev_map.get_cell_item(cell) == spawner_id:
			var world_pos = dev_map.to_global(dev_map.map_to_local(cell))
			world_pos.y += 0.5
			var tile = world_to_tile(world_pos)
			var lane_id = tile.y
			spawners_by_lane[lane_id] = world_pos

func register_enemy(enemy: Node, lane_id: int) -> void:
	if not enemies_by_lane.has(lane_id): enemies_by_lane[lane_id] = []
	if not enemies_by_lane[lane_id].has(enemy): enemies_by_lane[lane_id].append(enemy)
	var tile = world_to_tile(enemy.global_position)
	update_enemy_position(enemy, Vector2i(-9999, -9999), tile)

func unregister_enemy(enemy: Node, lane_id: int) -> void:
	if enemies_by_lane.has(lane_id): enemies_by_lane[lane_id].erase(enemy)
	for tile in enemy_spatial_map:
		if enemy_spatial_map[tile].has(enemy):
			enemy_spatial_map[tile].erase(enemy)
			if enemy_spatial_map[tile].is_empty(): enemy_spatial_map.erase(tile)
			break

func update_enemy_position(enemy: Node, old_tile: Vector2i, new_tile: Vector2i) -> void:
	if enemy_spatial_map.has(old_tile):
		if enemy_spatial_map[old_tile].has(enemy): enemy_spatial_map[old_tile].erase(enemy)
		if enemy_spatial_map[old_tile].is_empty(): enemy_spatial_map.erase(old_tile)
	if not enemy_spatial_map.has(new_tile): enemy_spatial_map[new_tile] = []
	enemy_spatial_map[new_tile].append(enemy)

func get_enemies_at(tile: Vector2i) -> Array: return enemy_spatial_map.get(tile, [])
func get_enemies_in_lane(lane_id: int) -> Array: return enemies_by_lane.get(lane_id, [])
func is_valid_tile(tile_coord: Vector2i) -> bool: return _tile_to_logical_map.has(tile_coord)

## Returns the X coordinate of the building placed deepest into the level.
func get_furthest_building_depth() -> int:
	var max_x = 0
	for coord in grid_state.keys():
		if grid_state[coord].has("building"):
			if coord.x > max_x:
				max_x = coord.x
	return max_x

## Returns a random world position for a field spawn that does not collide with existing buildings.
func get_valid_field_spawn_pos(min_d: int, max_d: int, safe_buffer: int) -> Vector3:
	var limit = get_furthest_building_depth() + safe_buffer
	# Ensure we spawn deeper than the furthest building (+buffer)
	var start = max(min_d, limit)
	
	if start >= max_d: 
		# No room between buildings and max depth
		return Vector3.ZERO 
	
	# Attempt to find a clear tile
	for i in range(10):
		var depth = randi_range(start, max_d)
		var lane = randi() % NUM_LANES
		var tile = _calculate_grid_coord(lane, depth)
		
		# Check if occupied by building
		if not get_entity_at(tile, "building"):
			return tile_to_world(tile)
			
	return Vector3.ZERO
