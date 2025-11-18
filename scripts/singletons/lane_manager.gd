extends Node

## Manages all lane data, including paths, buildables, and coordinate transformations.

var tile_map: TileMapLayer

var lane_paths: Dictionary = {}
var _tile_to_buildable_map: Dictionary = {}
var _tile_to_logical_map: Dictionary = {}


func _ready() -> void:
	print("LaneManager Initialized.")
	call_deferred("_initialize")

func _initialize() -> void:
	var main_scene = get_tree().current_scene
	if main_scene:
		tile_map = main_scene.get_node_or_null("TileMapLayer")
	if not is_instance_valid(tile_map):
		printerr("LaneManager could not find TileMapLayer!")
		return
	
	_generate_lane_data()
	print("LaneManager: Lane paths and logical mappings generated.")

func _generate_lane_data() -> void:
	_tile_to_logical_map.clear()
	lane_paths.clear()

	var num_lanes = 5
	var lane_length = 30

	for lane_id in range(num_lanes):
		var physical_path: Array[Vector2i] = []
		var start_y = -(7 + lane_id) # Adjusted from 7 to 6 to shift lanes up
		var start_x = 2 - floori(lane_id / 2.0)

		for col in range(lane_length):
			var x: int
			var y = start_y - col

			if lane_id % 2 == 0:
				x = start_x + int(ceil(col / 2.0))
			else:
				x = start_x + int(floor(col / 2.0))
			
			physical_path.append(Vector2i(x, y))
		
		# physical_path.reverse()
		lane_paths[lane_id] = physical_path

		for depth in range(lane_length):
			var tile_coord = physical_path[depth]
			_tile_to_logical_map[tile_coord] = Vector2i(lane_id, depth)

func get_tile_from_logical(lane_id: int, depth: int) -> Vector2i:
	if not lane_paths.has(lane_id):
		return Vector2i(-1, -1)
	var path = lane_paths[lane_id]
	if depth >= 0 and depth < path.size():
		return path[depth]
	return Vector2i(-1, -1)

func get_logical_from_tile(tile_coord: Vector2i) -> Vector2i:
	return _tile_to_logical_map.get(tile_coord, Vector2i(-1, -1))

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
