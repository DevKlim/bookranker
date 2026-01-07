extends Node

## Manages the state of the wire network, including power propagation and visuals.
## Implements a Redstone-like grid logic in 3D (X, Z plane).
## Visuals are handled by assigning connection flags to the Wire entities.

signal network_updated

# Dictionary storing { Vector2i(x, z): WireInstance }
var _wires: Dictionary = {}

# The fixed power source coordinate in the grid (X=0, Z=2)
const POWER_SOURCE_COORD = Vector2i(0, 2)

func _ready() -> void:
	print("WiringManager (Redstone Mode) Initialized.")

func add_wire(coord: Vector2i, instance: Node) -> void:
	# coord is the 3D grid coordinate projected to 2D (x, z)
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
	
	# Check if this exact coordinate is the power source, even without a wire (for external checks)
	if coord == POWER_SOURCE_COORD:
		return true
		
	return false

## Recalculates power flow and visual connections for the entire grid.
## Uses BFS to propagate power from the source coordinate.
func update_network() -> void:
	# 1. Reset all wires to unpowered state
	for wire_instance in _wires.values():
		if is_instance_valid(wire_instance) and wire_instance.has_method("set_powered"):
			wire_instance.set_powered(false)

	# 2. Setup BFS from Power Source
	var queue: Array[Vector2i] = []
	var visited: Dictionary = {}

	# Force power source logic: 
	# If there is a wire at (2,0), ensure it turns on immediately.
	if has_wire(POWER_SOURCE_COORD):
		queue.append(POWER_SOURCE_COORD)
		visited[POWER_SOURCE_COORD] = true
		if is_instance_valid(_wires[POWER_SOURCE_COORD]):
			_wires[POWER_SOURCE_COORD].set_powered(true)
	else:
		# Warn just in case, though it's valid to not have started wiring yet
		# print("WiringManager: No wire connected to Main Power Source at %s" % POWER_SOURCE_COORD)
		pass
	
	# 3. Propagate Power (Redstone logic: Adjacent wires share power)
	while not queue.is_empty():
		var current = queue.pop_front()
		
		# Check 4 Neighbors: Right(+X), Left(-X), Down(+Z), Up(-Z)
		var neighbors = [
			current + Vector2i(1, 0),
			current + Vector2i(-1, 0),
			current + Vector2i(0, 1),
			current + Vector2i(0, -1)
		]
		
		for n in neighbors:
			if has_wire(n) and not visited.has(n):
				visited[n] = true
				if is_instance_valid(_wires[n]):
					_wires[n].set_powered(true)
				queue.push_back(n)

	# 4. Update Visual Connections for ALL wires (regardless of power)
	# This determines if they draw lines or the "dot"
	for coord in _wires:
		_update_single_wire_visual(coord)
		
	emit_signal("network_updated")

func _update_single_wire_visual(coord: Vector2i) -> void:
	var wire_instance = _wires.get(coord)
	if not is_instance_valid(wire_instance): return
	if not wire_instance.has_method("set_connections"): return

	var connections: Array[int] = []
	
	# Godot 3D Wire Directions (Matches wire.gd visual mapping)
	# 1: Left (-X)
	# 2: Down (+Z)
	# 3: Right (+X)
	# 4: Up (-Z)
	
	if has_wire(coord + Vector2i(-1, 0)): connections.append(1)
	if has_wire(coord + Vector2i(0, 1)):  connections.append(2)
	if has_wire(coord + Vector2i(1, 0)):  connections.append(3)
	if has_wire(coord + Vector2i(0, -1)): connections.append(4)

	wire_instance.set_connections(connections)
