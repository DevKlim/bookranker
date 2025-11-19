extends Node

## Manages the state of the wire network, including power propagation and visuals.

signal network_updated

# { tile_coord: WireInstance }
var _wires: Dictionary = {}

@onready var lane_manager = get_node("/root/LaneManager")

func _ready() -> void:
	print("WiringManager Initialized.")

func add_wire(coord: Vector2i, instance: Node) -> void:
	if not _wires.has(coord):
		_wires[coord] = instance
		update_network()

func remove_wire(coord: Vector2i) -> void:
	if _wires.has(coord):
		_wires.erase(coord)
		# The instance that was at this coord is being freed from the scene.
		# This function is called by its `tree_exiting` signal.
		# We just need to update the network state.
		update_network()

func has_wire(coord: Vector2i) -> bool:
	return _wires.has(coord)

func get_wire_instance(coord: Vector2i) -> Node:
	return _wires.get(coord, null)

func is_powered(coord: Vector2i) -> bool:
	if _wires.has(coord):
		var wire_instance = _wires[coord]
		if is_instance_valid(wire_instance):
			return wire_instance.is_powered
	return false

## Propagates power through the wire network using a breadth-first search on LOGICAL coordinates.
## Power is sourced strictly from a wire located at Logical [2, 0].
func update_network() -> void:
	# 1. Reset power state for all wires.
	for wire_instance in _wires.values():
		if is_instance_valid(wire_instance):
			wire_instance.set_powered(false)

	# 2. Determine Source: Power strictly comes from a wire at Logical [2, 0].
	#    Note: Lane 2, Depth 0 is usually where the Core connects.
	var source_logical = Vector2i(2, 0)
	var source_physical = lane_manager.get_tile_from_logical(source_logical.x, source_logical.y)
	
	# If no wire exists at [2, 0], the entire grid receives no power from the core.
	if not has_wire(source_physical):
		_update_all_visuals()
		emit_signal("network_updated")
		return

	# 3. Flood-fill power from source.
	var queue: Array[Vector2i] = []
	var visited: Dictionary = {}

	# Start BFS from source
	queue.push_back(source_physical)
	visited[source_physical] = true
	
	while not queue.is_empty():
		var current_phys_coord = queue.pop_front()
		
		# Power this wire
		if has_wire(current_phys_coord):
			_wires[current_phys_coord].set_powered(true)
		
		var current_log_coord = lane_manager.get_logical_from_tile(current_phys_coord)
		if current_log_coord == Vector2i(-1, -1): continue

		var neighbors_logical = [
			current_log_coord + Vector2i(0, -1),  # down (depth - 1)
			current_log_coord + Vector2i(1, 0),   # left (lane + 1)
			current_log_coord + Vector2i(0, 1),   # up (depth + 1)
			current_log_coord + Vector2i(-1, 0)   # right (lane - 1)
		]

		for neighbor_log_coord in neighbors_logical:
			var neighbor_phys_coord = lane_manager.get_tile_from_logical(neighbor_log_coord.x, neighbor_log_coord.y)
			if neighbor_phys_coord == Vector2i(-1, -1): continue
			
			if has_wire(neighbor_phys_coord) and not visited.has(neighbor_phys_coord):
				visited[neighbor_phys_coord] = true
				queue.push_back(neighbor_phys_coord)
	
	# 4. Update visuals for all wires.
	_update_all_visuals()

	# 5. Notify other systems that the network has changed.
	emit_signal("network_updated")

func _update_all_visuals() -> void:
	for coord in _wires:
		_update_single_wire_visual(coord)

func _update_single_wire_visual(coord: Vector2i) -> void:
	var wire_instance = _wires.get(coord)
	if not is_instance_valid(wire_instance): return

	var logical_coord = lane_manager.get_logical_from_tile(coord)
	var connections: Array[int] = []
	
	if logical_coord != Vector2i(-1, -1):
		var ln = logical_coord.x
		var d = logical_coord.y
		
		# Connections are numbered clockwise from bottom: 1:down, 2:left, 3:up, 4:right
		
		# Check neighbor towards the camera (decreasing depth) -> VISUALLY DOWN (1)
		var neighbor_down_phys = lane_manager.get_tile_from_logical(ln, d - 1)
		if has_wire(neighbor_down_phys): connections.append(1)

		# Check neighbor for logical right (lane+1) -> VISUALLY LEFT (2)
		var neighbor_left_phys = lane_manager.get_tile_from_logical(ln + 1, d)
		if has_wire(neighbor_left_phys): connections.append(2)

		# Check neighbor towards the horizon (increasing depth) -> VISUALLY UP (3)
		var neighbor_up_phys = lane_manager.get_tile_from_logical(ln, d + 1)
		if has_wire(neighbor_up_phys): connections.append(3)

		# Check neighbor for logical left (lane-1) -> VISUALLY RIGHT (4)
		var neighbor_right_phys = lane_manager.get_tile_from_logical(ln - 1, d)
		if has_wire(neighbor_right_phys): connections.append(4)
	
	wire_instance.set_connections(connections)
