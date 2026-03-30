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
var astar_field: AStarGrid2D
var astar_ally: AStarGrid2D

var spawners_by_lane: Dictionary = {}
var ores: Array[ItemResource] =[]
var clutter_types: Array[ClutterResource] =[]
var block_id_to_item_map: Dictionary = {}
var block_name_to_id_map: Dictionary = {}

var active_ore_deposits: Dictionary = {} # tile (Vector2i) -> remaining_count (int)

var enemies_by_lane: Dictionary = {}
var enemy_spatial_map: Dictionary = {}

var num_lanes: int = 9
# Increased length to support field enemies spawning deeper in the map
const LANE_LENGTH = 100

var current_generated_depth: int = 0
const CHUNK_SIZE: int = 25
const RENDER_AHEAD: int = 35

var grid_generator: Node
var fog_manager: Node

func _ready() -> void:
	grid_generator = load("res://scripts/managers/grid_generator.gd").new()
	grid_generator.name = "GridGenerator"
	add_child(grid_generator)
	grid_generator.setup(self)
	
	fog_manager = load("res://scripts/managers/fog_manager.gd").new()
	fog_manager.name = "FogManager"
	add_child(fog_manager)
	fog_manager.setup(self)

	_init_astar()
	for i in range(num_lanes):
		enemies_by_lane[i] =[]
	_load_resources()

func _init_astar() -> void:
	astar = AStarGrid2D.new()
	var x_start = -50 + generation_offset.x
	var x_size = 200 
	astar.region = Rect2i(x_start, generation_offset.y, x_size, num_lanes)
	astar.cell_size = Vector2(GRID_SCALE, GRID_SCALE)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER 
	astar.update()
	
	astar_field = AStarGrid2D.new()
	astar_field.region = astar.region
	astar_field.cell_size = astar.cell_size
	astar_field.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar_field.update()
	
	astar_ally = AStarGrid2D.new()
	astar_ally.region = astar.region
	astar_ally.cell_size = astar.cell_size
	astar_ally.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar_ally.update()

func add_lane() -> void:
	var new_lane_idx = num_lanes
	num_lanes += 1
	_generate_lane_data()
	_init_astar()
	enemies_by_lane[new_lane_idx] =[]
	
	if grid_map:
		grid_generator._generate_ores_for_lane_chunk(new_lane_idx, 0, current_generated_depth)
		grid_generator._generate_clutter_for_lane_chunk(new_lane_idx, 0, current_generated_depth)
		grid_generator._generate_loot_buildings_for_lane_chunk(new_lane_idx, 0, current_generated_depth)
		grid_generator._generate_terrain_for_lane_chunk(new_lane_idx, 0, current_generated_depth)
		
	# Update spawners for the new lane so pathfinding has a valid endpoint
	if fog_manager:
		var spawn_tile = Vector2i(fog_manager.current_fog_depth, new_lane_idx + generation_offset.y)
		spawners_by_lane[new_lane_idx] = tile_to_world(spawn_tile)
	elif spawners_by_lane.size() > 0:
		var existing = spawners_by_lane.values()[0]
		var new_tile = Vector2i(world_to_tile(existing).x, new_lane_idx + generation_offset.y)
		var new_world_pos = tile_to_world(new_tile)
		new_world_pos.y = existing.y
		new_world_pos.x = existing.x
		spawners_by_lane[new_lane_idx] = new_world_pos

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
	
	var path = "res://data/content/blocks.json"
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			var json = JSON.new()
			if json.parse(file.get_as_text()) == OK:
				var blocks_data = json.data
				for b in blocks_data:
					var b_name = b.get("name", "")
					var ore_item_id = b.get("ore_item", "")
					if ore_item_id != "" and block_name_to_id_map.has(b_name):
						var item_path = "res://resources/items/" + ore_item_id + ".tres"
						if ResourceLoader.exists(item_path):
							var b_id = block_name_to_id_map[b_name]
							block_id_to_item_map[b_id] = load(item_path)

func _initialize() -> void:
	_generate_lane_data()
	if grid_map: 
		grid_generator.generate_guaranteed_ores(GameManager.current_level_config.get("ores",[]))
		var root = get_tree().current_scene
		var parent_node = root.get_node_or_null("Buildings")
		if not parent_node: parent_node = root
		grid_generator.generate_guaranteed_clutter(GameManager.current_level_config.get("clutter",[]), parent_node)
		grid_generator.generate_guaranteed_loot_buildings(GameManager.current_level_config.get("loot_buildings",[]), parent_node)
		
		current_generated_depth = 0
		var end = min(CHUNK_SIZE, LANE_LENGTH)
		grid_generator.generate_chunk(0, end)
		current_generated_depth = end
		
		if fog_manager:
			fog_manager._update_fog_for_current_phase()

func _process(_delta: float) -> void:
	if not grid_map: return
	
	var cam_x = 0
	var cam = get_viewport().get_camera_3d()
	if cam:
		cam_x = int(cam.global_position.x / GRID_SCALE)
		
	var fog_depth = 0
	if fog_manager:
		fog_depth = fog_manager.current_fog_depth
		
	var max_x = max(get_furthest_building_depth(), max(cam_x, fog_depth))
	var target_depth = max_x + RENDER_AHEAD
	
	if target_depth > current_generated_depth and current_generated_depth < LANE_LENGTH:
		var end = min(current_generated_depth + CHUNK_SIZE, LANE_LENGTH)
		grid_generator.generate_chunk(current_generated_depth, end)
		current_generated_depth = end

func _generate_lane_data() -> void:
	_tile_to_logical_map.clear()
	lane_paths.clear()
	active_ore_deposits.clear()
	
	for lane_idx in range(num_lanes):
		var physical_path: Array[Vector2i] =[]
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

func register_entity(entity: Node, coord: Vector2i, layer: String) -> void:
	if not grid_state.has(coord): grid_state[coord] = {}
	grid_state[coord][layer] = entity
	if layer == "building":
		var is_clutter = entity.is_in_group("clutter")
		if not is_clutter:
			astar.set_point_solid(coord, true)
		astar_field.set_point_solid(coord, true)

func unregister_entity(coord: Vector2i, layer: String) -> void:
	if grid_state.has(coord) and grid_state[coord].has(layer):
		grid_state[coord].erase(layer)
		if grid_state[coord].is_empty(): grid_state.erase(coord)
	if layer == "building":
		var should_be_solid_astar = false
		var should_be_solid_field = false
		if grid_state.has(coord) and grid_state[coord].has("building"):
			var e = grid_state[coord]["building"]
			if is_instance_valid(e):
				should_be_solid_field = true
				if not e.is_in_group("clutter"):
					should_be_solid_astar = true
		astar.set_point_solid(coord, should_be_solid_astar)
		astar_field.set_point_solid(coord, should_be_solid_field)

func get_entity_at(coord: Vector2i, layer: String) -> Node:
	if grid_state.has(coord) and grid_state[coord].has(layer):
		var entity = grid_state[coord][layer]
		if is_instance_valid(entity): return entity
		else:
			grid_state[coord].erase(layer)
			if grid_state[coord].is_empty(): grid_state.erase(coord)
			if layer == "building":
				var should_be_solid_astar = false
				var should_be_solid_field = false
				if grid_state.has(coord) and grid_state[coord].has("building"):
					var e = grid_state[coord]["building"]
					if is_instance_valid(e):
						should_be_solid_field = true
						if not e.is_in_group("clutter"):
							should_be_solid_astar = true
				astar.set_point_solid(coord, should_be_solid_astar)
				astar_field.set_point_solid(coord, should_be_solid_field)
	return null

func get_path_world(from_pos: Vector3, to_pos: Vector3, is_ally: bool = false) -> Array[Vector3]:
	var start_tile = world_to_tile(from_pos)
	var end_tile = world_to_tile(to_pos)
	
	if start_tile == end_tile:
		return[]
	
	var nav = astar_ally if is_ally and astar_ally else astar_field
	
	if not nav.region.has_point(start_tile): start_tile = _clamp_to_bounds(start_tile)
	if not nav.region.has_point(end_tile): end_tile = _clamp_to_bounds(end_tile)
	
	var id_path = nav.get_id_path(start_tile, end_tile)
	var world_path: Array[Vector3] =[]
	for point in id_path:
		world_path.append(tile_to_world(point))
	return world_path

func get_path_for_enemy(lane_id: int, start_pos: Vector3) -> Array[Vector3]:
	var start_tile = world_to_tile(start_pos)
	var target_tile = Vector2i(-1, lane_id + generation_offset.y)
	
	if not astar.region.has_point(start_tile): start_tile = _clamp_to_bounds(start_tile)
	if not astar.region.has_point(target_tile): target_tile = _clamp_to_bounds(target_tile)
	
	var was_solid = astar.is_point_solid(target_tile)
	if was_solid: astar.set_point_solid(target_tile, false)
	
	var id_path = astar.get_id_path(start_tile, target_tile)
	
	if was_solid: astar.set_point_solid(target_tile, true)
	
	var world_path: Array[Vector3] =[]
	for point in id_path:
		world_path.append(tile_to_world(point))
	return world_path

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

func consume_ore_at(tile: Vector2i) -> bool:
	if not grid_map: return true
	var cell_pos = Vector3i(tile.x, 0, tile.y)
	var block_id = grid_map.get_cell_item(cell_pos)
	
	if block_id == GridMap.INVALID_CELL_ITEM or not block_id_to_item_map.has(block_id):
		return true 
		
	if not active_ore_deposits.has(tile):
		active_ore_deposits[tile] = 5
		
	active_ore_deposits[tile] -= 1
	
	if active_ore_deposits[tile] <= 0:
		active_ore_deposits.erase(tile)
		
		var block_to_place = "Stone"
		var depth = tile.x - generation_offset.x
		var terrain_layers = GameManager.current_level_config.get("terrain_layers",[ { "depth": 5, "block": "Dirt" }, { "depth": LANE_LENGTH, "block": "Stone" } ])
		for layer in terrain_layers:
			if depth <= layer.get("depth", LANE_LENGTH):
				block_to_place = layer.get("block", "Stone")
				break
				
		var bg_id = block_name_to_id_map.get(block_to_place, 0)
		grid_map.set_cell_item(cell_pos, bg_id)
		return true 
		
	return false 

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
	var ref_x: float = -INF
	var ref_y: float = 0.5
	
	for cell in cells:
		if dev_map.get_cell_item(cell) == spawner_id:
			var world_pos = dev_map.to_global(dev_map.map_to_local(cell))
			world_pos.y += 0.5
			var tile = world_to_tile(world_pos)
			var lane_id = tile.y
			spawners_by_lane[lane_id] = world_pos
			
			if ref_x == -INF:
				ref_x = world_pos.x
				ref_y = world_pos.y
				
	if ref_x != -INF:
		for i in range(num_lanes):
			if not spawners_by_lane.has(i):
				var virtual_tile = Vector2i(0, i + generation_offset.y)
				var virtual_pos = tile_to_world(virtual_tile)
				virtual_pos.x = ref_x
				virtual_pos.y = ref_y
				spawners_by_lane[i] = virtual_pos

func register_enemy(enemy: Node, lane_id: int) -> void:
	if not enemies_by_lane.has(lane_id): enemies_by_lane[lane_id] =[]
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
	if not enemy_spatial_map.has(new_tile): enemy_spatial_map[new_tile] =[]
	enemy_spatial_map[new_tile].append(enemy)

func get_enemies_at(tile: Vector2i) -> Array: return enemy_spatial_map.get(tile,[])
func get_enemies_in_lane(lane_id: int) -> Array: return enemies_by_lane.get(lane_id,[])
func is_valid_tile(tile_coord: Vector2i) -> bool: return _tile_to_logical_map.has(tile_coord)

func get_furthest_building_depth() -> int:
	var max_x = 0
	for coord in grid_state.keys():
		if grid_state[coord].has("building"):
			if coord.x > max_x:
				max_x = coord.x
	return max_x

func get_valid_field_spawn_pos(min_d: int, max_d: int, safe_buffer: int) -> Vector3:
	var cam_x = 0
	var cam = get_viewport().get_camera_3d()
	if cam:
		cam_x = int(cam.global_position.x / GRID_SCALE)
		
	var limit = max(get_furthest_building_depth(), cam_x) + safe_buffer
	var start = max(min_d, limit)
	var active_max = min(max_d, start + 25) 
	
	if start >= max_d or start >= active_max: 
		return Vector3.ZERO 
	
	for i in range(10):
		var depth = randi_range(start, active_max)
		var lane = randi() % num_lanes
		var tile = _calculate_grid_coord(lane, depth)
		
		if not get_entity_at(tile, "building"):
			var world_pos = tile_to_world(tile)
			world_pos.y = 3.0
			return world_pos
			
	return Vector3.ZERO

func get_valid_ally_spawn_pos() -> Vector3:
	for x in range(0, 10):
		for z in range(max(1, num_lanes)):
			var tile = Vector2i(x, z)
			if not get_entity_at(tile, "building"):
				var world_pos = tile_to_world(tile)
				world_pos.y = 3.0
				return world_pos
	var world_base = tile_to_world(Vector2i(0, 0))
	world_base.y = 3.0
	return world_base

func get_nearby_valid_ally_spawn_pos(death_pos: Vector3) -> Vector3:
	var start_tile = world_to_tile(death_pos)
	var queue =[start_tile]
	var visited = {start_tile: true}
	
	while queue.size() > 0:
		var curr = queue.pop_front()
		if is_valid_tile(curr) and not get_entity_at(curr, "building"):
			var world_pos = tile_to_world(curr)
			world_pos.y = max(death_pos.y, 3.0)
			return world_pos
			
		for n in[Vector2i(0,1), Vector2i(0,-1), Vector2i(1,0), Vector2i(-1,0)]:
			var next_t = curr + n
			if not visited.has(next_t):
				visited[next_t] = true
				if is_valid_tile(next_t):
					queue.append(next_t)
					
	return get_valid_ally_spawn_pos()
