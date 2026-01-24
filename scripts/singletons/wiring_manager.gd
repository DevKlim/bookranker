extends Node

## Manages the state of the wire network.
## Implements a Redstone-like grid logic and Network Analysis.

signal network_updated

# Dictionary storing { Vector2i(x, z): WireInstance }
var _wires: Dictionary = {}

const POWER_SOURCE_COORD = Vector2i(0, 2)

func _ready() -> void:
	print("WiringManager (Redstone Mode) Initialized.")

func add_wire(coord: Vector2i, instance: Node) -> void:
	if not _wires.has(coord):
		_wires[coord] = instance
		call_deferred("update_network")

func remove_wire(coord: Vector2i) -> void:
	if _wires.has(coord):
		_wires.erase(coord)
		call_deferred("update_network")

func has_wire(coord: Vector2i) -> bool:
	return _wires.has(coord)

func get_wire_instance(coord: Vector2i) -> Node:
	return _wires.get(coord, null)

func is_powered(coord: Vector2i) -> bool:
	var w = _wires.get(coord, null)
	if is_instance_valid(w) and "is_powered" in w:
		return w.is_powered
	
	if coord == POWER_SOURCE_COORD:
		return true
		
	return false

func update_network() -> void:
	# 1. Reset
	for wire_instance in _wires.values():
		if is_instance_valid(wire_instance) and wire_instance.has_method("set_powered"):
			wire_instance.set_powered(false)

	# 2. BFS from Source
	var queue: Array[Vector2i] = []
	var visited: Dictionary = {}

	if has_wire(POWER_SOURCE_COORD):
		queue.append(POWER_SOURCE_COORD)
		visited[POWER_SOURCE_COORD] = true
		if is_instance_valid(_wires[POWER_SOURCE_COORD]):
			_wires[POWER_SOURCE_COORD].set_powered(true)
	
	while not queue.is_empty():
		var current = queue.pop_front()
		
		var neighbors = _get_neighbors(current)
		for n in neighbors:
			if has_wire(n) and not visited.has(n):
				visited[n] = true
				if is_instance_valid(_wires[n]):
					_wires[n].set_powered(true)
				queue.push_back(n)

	# 3. Update Visuals
	for coord in _wires:
		_update_single_wire_visual(coord)
		
	emit_signal("network_updated")

func _update_single_wire_visual(coord: Vector2i) -> void:
	var wire_instance = _wires.get(coord)
	if not is_instance_valid(wire_instance): return
	if not wire_instance.has_method("set_connections"): return

	var connections: Array[int] = []
	# 1: Left (-X), 2: Down (+Z), 3: Right (+X), 4: Up (-Z)
	if has_wire(coord + Vector2i(-1, 0)): connections.append(1)
	if has_wire(coord + Vector2i(0, 1)):  connections.append(2)
	if has_wire(coord + Vector2i(1, 0)):  connections.append(3)
	if has_wire(coord + Vector2i(0, -1)): connections.append(4)

	wire_instance.set_connections(connections)

func _get_neighbors(coord: Vector2i) -> Array[Vector2i]:
	return [
		coord + Vector2i(1, 0),
		coord + Vector2i(-1, 0),
		coord + Vector2i(0, 1),
		coord + Vector2i(0, -1)
	]

## Analyzes the network starting at the given coordinate.
## Returns a dictionary with stats: wire_count, consumers, generators, demand, generation, net.
func get_network_stats(start_coord: Vector2i) -> Dictionary:
	if not has_wire(start_coord):
		return {}

	var stats = {
		"wire_count": 0,
		"generator_count": 0,
		"consumer_count": 0,
		"total_generation": 0.0,
		"total_demand": 0.0,
		"net_power": 0.0,
		"status": "Inactive",
		"connected_coords": []
	}
	
	var queue: Array[Vector2i] = [start_coord]
	var visited_wire: Dictionary = { start_coord: true }
	var visited_buildings: Dictionary = {} 
	
	while not queue.is_empty():
		var current = queue.pop_front()
		stats.wire_count += 1
		stats.connected_coords.append(current)
		
		# Check devices attached to this wire tile (e.g. on top)
		_scan_tile_for_devices(current, stats, visited_buildings)
		
		# Scan neighbors for wires AND adjacent machines (e.g. Core or side-ports)
		var neighbors = _get_neighbors(current)
		for n in neighbors:
			# Check for adjacent devices (Core, or machines connected to side of wire)
			_scan_tile_for_devices(n, stats, visited_buildings)
			
			# Future Proofing: Logic Gates blocking
			if _is_gate_blocking(current, n):
				continue
			
			# Continue BFS along wires
			if has_wire(n) and not visited_wire.has(n):
				visited_wire[n] = true
				queue.append(n)
	
	stats.net_power = stats.total_generation - stats.total_demand
	
	if stats.total_generation <= 0 and stats.total_demand > 0:
		stats.status = "Unpowered"
	elif stats.net_power >= 0:
		stats.status = "Stable"
	else:
		stats.status = "Overloaded"
	
	if stats.total_generation == 0 and stats.total_demand == 0:
		stats.status = "Idle"
		
	return stats

func _scan_tile_for_devices(coord: Vector2i, stats: Dictionary, visited_buildings: Dictionary) -> void:
	# We check if there is a building at this coordinate.
	var building = LaneManager.get_entity_at(coord, "building")
	if not building or not is_instance_valid(building): return
	
	# Prevent double counting multi-tile buildings
	if visited_buildings.has(building): return
	visited_buildings[building] = true
	
	# Check for Power Provider
	var provider = building.get_node_or_null("PowerProviderComponent")
	if provider:
		stats.generator_count += 1
		stats.total_generation += provider.power_generation
	
	# Check for Power Consumer
	var consumer = building.get_node_or_null("PowerConsumerComponent")
	if consumer:
		stats.consumer_count += 1
		stats.total_demand += consumer.power_consumption

func _is_gate_blocking(_from: Vector2i, _to: Vector2i) -> bool:
	# Placeholder for logic gates
	return false
