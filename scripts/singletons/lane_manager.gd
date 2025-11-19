extends Node

## Manages all lane data, including paths, buildables, coordinate transformations, AND RESOURCES.

@export_range(0.0, 1.0) var ore_rarity: float = 0.12
@export var generation_offset: Vector2i = Vector2i(0, 0)

var tile_map: TileMapLayer
var ore_layer: TileMapLayer

var lane_paths: Dictionary = {}
var _tile_to_buildable_map: Dictionary = {}
var _tile_to_logical_map: Dictionary = {}

# Ore Grid Storage
# Maps tile coordinates to the specific Ore ItemResource (excluding Stone/Base tile)
var _ore_data: Dictionary = {} # { Vector2i: ItemResource }

# Resource Registry
var ores: Dictionary = {} # { "name": ItemResource }
var ore_atlas_coords: Dictionary = {} # { "name": Vector2i }

const NUM_LANES = 5
const LANE_LENGTH = 30

func _ready() -> void:
	print("LaneManager Initialized.")
	_initialize_resources()
	call_deferred("_initialize")

func _initialize_resources() -> void:
	var basic_icon = preload("res://icon.svg") # Placeholder icon
	
	# Elements
	var fire_elem = preload("res://resources/elements/fire.tres")
	
	var stone = ItemResource.new()
	stone.item_name = "Stone"
	stone.icon = basic_icon
	stone.color = Color.GRAY
	stone.damage = 5.0
	ores["Stone"] = stone
	
	var iron = ItemResource.new()
	iron.item_name = "Iron"
	iron.icon = basic_icon
	iron.color = Color.SILVER
	iron.damage = 15.0
	ores["Iron"] = iron
	ore_atlas_coords["Iron"] = Vector2i(0, 0)
	
	var coal = ItemResource.new()
	coal.item_name = "Coal"
	coal.icon = basic_icon
	coal.color = Color.BLACK
	coal.element = fire_elem
	coal.damage = 10.0
	ores["Coal"] = coal
	ore_atlas_coords["Coal"] = Vector2i(1, 0)
	
	var copper = ItemResource.new()
	copper.item_name = "Copper"
	copper.icon = basic_icon
	copper.color = Color(0.72, 0.45, 0.2) # Copper color
	copper.damage = 12.0
	ores["Copper"] = copper
	ore_atlas_coords["Copper"] = Vector2i(2, 0)
	
	var lux = ItemResource.new()
	lux.item_name = "Lux Ore"
	lux.icon = basic_icon
	lux.color = Color.CYAN
	lux.damage = 25.0
	ores["Lux"] = lux
	ore_atlas_coords["Lux"] = Vector2i(3, 0)


func _initialize() -> void:
	var main_scene = get_tree().current_scene
	if main_scene:
		tile_map = main_scene.get_node_or_null("TileMapLayer")
		ore_layer = main_scene.get_node_or_null("OreLayer")
		
	if not is_instance_valid(tile_map):
		printerr("LaneManager could not find TileMapLayer!")
		return
	if not is_instance_valid(ore_layer):
		printerr("LaneManager could not find OreLayer!")
	
	_generate_lane_data()
	_generate_ores()
	print("LaneManager: Lane paths, logical mappings, and ores generated.")

func _generate_lane_data() -> void:
	_tile_to_logical_map.clear()
	lane_paths.clear()

	for lane_id in range(NUM_LANES):
		var physical_path: Array[Vector2i] = []
		
		for depth in range(LANE_LENGTH):
			var tile = _calculate_physical_coord(lane_id, depth)
			physical_path.append(tile)
		
		lane_paths[lane_id] = physical_path

		for depth in range(LANE_LENGTH):
			var tile_coord = physical_path[depth]
			_tile_to_logical_map[tile_coord] = Vector2i(lane_id, depth)

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
	
	_ore_data.clear()
	ore_layer.clear()
	
	var available_ores = ore_atlas_coords.keys()
	
	# Ore Generation Range:
	# Lane: 1 to 5 (Include lane 5, Exclude lane 0) - Adjusted per request to swap direction.
	# Depth: -1 to 29 (Include boundary -1)
	for lane in range(1, 6):
		for depth in range(-1, LANE_LENGTH):
			if randf() < ore_rarity:
				var tile_coord = _calculate_physical_coord(lane, depth)
				var key = available_ores.pick_random()
				add_ore_at(tile_coord, key)

func add_ore_at(tile_coord: Vector2i, ore_key: String) -> void:
	# Only check dictionary if within valid item keys
	if not ores.has(ore_key): return
	
	# 1. Map Data
	_ore_data[tile_coord] = ores[ore_key]
	
	# 2. Set Tile on OreLayer
	if is_instance_valid(ore_layer) and ore_atlas_coords.has(ore_key):
		var atlas_coord = ore_atlas_coords[ore_key]
		# Source ID 0 is assumed to be the atlas source in ore_tileset.tres
		ore_layer.set_cell(tile_coord, 0, atlas_coord)

func remove_ore_at(tile_coord: Vector2i) -> void:
	if _ore_data.has(tile_coord):
		_ore_data.erase(tile_coord)
	
	if is_instance_valid(ore_layer):
		ore_layer.set_cell(tile_coord, -1) # Remove tile

func get_ore_at(tile_coord: Vector2i) -> ItemResource:
	# 1. If a specific ore deposit exists (e.g. Coal, Iron), return it.
	if _ore_data.has(tile_coord):
		return _ore_data[tile_coord]
	
	# 2. Fallback: If it's a valid tile in the lane system, it yields Stone by default.
	if _tile_to_logical_map.has(tile_coord):
		return ores.get("Stone")
		
	return null


func get_tile_from_logical(lane_id: int, depth: int) -> Vector2i:
	if not lane_paths.has(lane_id):
		return Vector2i(-1, -1)
	var path = lane_paths[lane_id]
	if depth >= 0 and depth < path.size():
		return path[depth]
	return Vector2i(-1, -1)

func get_logical_from_tile(tile_coord: Vector2i) -> Vector2i:
	return _tile_to_logical_map.get(tile_coord, Vector2i(-1, -1))

func is_valid_tile(tile_coord: Vector2i) -> bool:
	return _tile_to_logical_map.has(tile_coord)

func register_buildable_at_tile(buildable: Node2D, tile_coord: Vector2i):
	_tile_to_buildable_map[tile_coord] = buildable

func unregister_buildable_at_tile(tile_coord: Vector2i):
	if _tile_to_buildable_map.has(tile_coord):
		_tile_to_buildable_map.erase(tile_coord)

func get_buildable_at(tile_coord: Vector2i) -> Node2D:
	return _tile_to_buildable_map.get(tile_coord, null)

func get_path_for_lane(lane_id: int) -> Array:
	return lane_paths.get(lane_id, [])

func get_lane_start_world_pos(lane_id: int) -> Vector2:
	if not tile_map: return Vector2.ZERO
	if lane_paths.has(lane_id) and not lane_paths[lane_id].is_empty():
		return tile_map.map_to_local(lane_paths[lane_id][-1])
	return Vector2.ZERO

func get_lane_end_world_pos(lane_id: int) -> Vector2:
	if not tile_map: return Vector2.ZERO
	if lane_paths.has(lane_id) and not lane_paths[lane_id].is_empty():
		return tile_map.map_to_local(lane_paths[lane_id][0])
	return Vector2.ZERO
