extends Node

## Manages the state of the wire network, including power propagation and visuals.

signal network_updated

# { tile_coord: WireInstance }
var _wires: Dictionary = {}
var _power_sources: Array[Vector2i] = []

@onready var lane_manager = get_node("/root/LaneManager")

func _ready() -> void:
	print("WiringManager Initialized.")


func add_power_source(coord: Vector2i) -> void:
	if not _power_sources.has(coord):
		_power_sources.append(coord)
		update_network()


func add_wire(coord: Vector2i, instance: Node) -> void:
	if not _wires.has(coord):
		_wires[coord] = instance
		update_network()


func remove_wire(coord: Vector2i) -> void:
	if _wires.has(coord):
		var instance = _wires[coord]
		_wires.erase(coord)
		# The instance will be freed automatically by the tree_exiting signal connection
		# in BuildManager, so we don't need to queue_free here.
		# This prevents a potential double-free if the node is removed from the scene manually.
		update_network()


func has_wire(coord: Vector2i) -> bool:
	return _wires.has(coord)


func is_powered(coord: Vector2i) -> bool:
	if _wires.has(coord):
		var wire_instance = _wires[coord]
		if is_instance_valid(wire_instance):
			return wire_instance.is_powered
	return false


## Propagates power through the wire network using a breadth-first search on LOGICAL coordinates.
func update_network() -> void:
	# 1. Reset power state for all wires.
	for wire_instance in _wires.values():
		if is_instance_valid(wire_instance):
			wire_instance.set_powered(false)

	# 2. Flood-fill power from all sources.
	var queue: Array[Vector2i] = []
	var visited: Dictionary = {}

	for source_coord in _power_sources:
		queue.push_back(source_coord)
		visited[source_coord] = true
	
	while not queue.is_empty():
		var current_phys_coord = queue.pop_front()
		
		if has_wire(current_phys_coord):
			_wires[current_phys_coord].set_powered(true)
		
		var current_log_coord = lane_manager.get_logical_from_tile(current_phys_coord)
		if current_log_coord == Vector2i(-1, -1): continue

		var neighbors_logical = [
			current_log_coord + Vector2i(0, 1),  # down (depth + 1)
			current_log_coord + Vector2i(-1, 0), # left (lane - 1)
			current_log_coord + Vector2i(0, -1), # up (depth - 1)
			current_log_coord + Vector2i(1, 0)   # right (lane + 1)
		]

		for neighbor_log_coord in neighbors_logical:
			var neighbor_phys_coord = lane_manager.get_tile_from_logical(neighbor_log_coord.x, neighbor_log_coord.y)
			if neighbor_phys_coord == Vector2i(-1, -1): continue
			
			if has_wire(neighbor_phys_coord) and not visited.has(neighbor_phys_coord):
				visited[neighbor_phys_coord] = true
				queue.push_back(neighbor_phys_coord)
	
	# 3. Update visuals for all wires.
	for coord in _wires:
		_update_single_wire_visual(coord)

	# 4. Notify other systems that the network has changed.
	emit_signal("network_updated")


func _update_single_wire_visual(coord: Vector2i) -> void:
	var wire_instance = _wires.get(coord)
	if not is_instance_valid(wire_instance): return

	var logical_coord = lane_manager.get_logical_from_tile(coord)
	var connections: Array[int] = []
	
	if logical_coord != Vector2i(-1, -1):
		var ln = logical_coord.x
		var d = logical_coord.y
		
		# Connections: 1:down, 2:left, 3:up, 4:right
		var down_phys = lane_manager.get_tile_from_logical(ln, d - 1)
		if has_wire(down_phys) or _power_sources.has(down_phys): connections.append(1)

		# Logical left (lane-1) is visually to the RIGHT on the isometric grid. Use connection '4'.
		var left_phys = lane_manager.get_tile_from_logical(ln - 1, d)
		if has_wire(left_phys) or _power_sources.has(left_phys): connections.append(4)

		var up_phys = lane_manager.get_tile_from_logical(ln, d + 1)
		if has_wire(up_phys) or _power_sources.has(up_phys): connections.append(3)

		# Logical right (lane+1) is visually to the LEFT on the isometric grid. Use connection '2'.
		var right_phys = lane_manager.get_tile_from_logical(ln + 1, d)
		if has_wire(right_phys) or _power_sources.has(right_phys): connections.append(2)
	
	wire_instance.set_connections(connections)

