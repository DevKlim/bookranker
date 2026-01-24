class_name TargetAcquirerComponent
extends Node

## A component that finds targets by querying specific grid tiles in LaneManager.
## Optimized for grid-based defense (Line of Sight).

signal target_acquired(target)
signal target_lost(last_target)

## Range in TILES (blocks)
@export var range_tiles: int = 20

var is_active: bool = true:
	set(value):
		is_active = value
		if not is_active:
			current_target = null

var current_target: Node3D = null:
	set(value):
		if current_target != value:
			var old_target = current_target
			current_target = value
			if current_target:
				emit_signal("target_acquired", current_target)
			elif is_instance_valid(old_target):
				emit_signal("target_lost", old_target)

var _scan_timer: Timer
var _parent_building: Node

func _ready() -> void:
	_parent_building = get_parent()
	
	# Scan for targets. Optimized lookup allows frequent scans (0.1s is fine).
	_scan_timer = Timer.new()
	_scan_timer.wait_time = 0.1
	_scan_timer.autostart = true
	_scan_timer.timeout.connect(_scan_for_targets)
	add_child(_scan_timer)
	
	# Clean up old area if it exists from previous version
	var old_area = get_node_or_null("DetectionArea")
	if old_area: old_area.queue_free()

func setup_custom_shape(size: Vector3, _center: Vector3) -> void:
	# Compatibility for Turret.gd initialization
	# Turret sends range in the Z component of the size vector
	range_tiles = int(size.z / LaneManager.GRID_SCALE)

func _scan_for_targets() -> void:
	if not is_active: return
	
	# Validate current target
	if is_instance_valid(current_target):
		if current_target.is_queued_for_deletion():
			current_target = null
		else:
			# Check if still in range/valid tile
			var t_tile = LaneManager.world_to_tile(current_target.global_position)
			if not _is_tile_in_range(t_tile):
				current_target = null

	# If we have a target, we might stick with it, or check for a closer one.
	# For strict line defense, we usually want the closest one.
	_find_closest_target()

func _find_closest_target() -> void:
	var my_pos = _parent_building.global_position
	var my_tile = LaneManager.world_to_tile(my_pos)
	
	var dir_vec = _get_facing_vector()
	
	# Raycast logic on the Grid
	# Check tiles from closest (1) to furthest (range_tiles)
	for i in range(1, range_tiles + 1):
		var check_tile = my_tile + (dir_vec * i)
		
		# Optimization: If tile is outside valid map bounds, stop
		if not LaneManager.is_valid_tile(check_tile):
			continue
			
		var enemies_here = LaneManager.get_enemies_at(check_tile)
		
		# If enemies are found in this tile
		if not enemies_here.is_empty():
			var best_enemy = null
			var best_dist = INF
			
			for enemy in enemies_here:
				if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
					# Sub-tile precision: find closest within this tile
					var d = my_pos.distance_squared_to(enemy.global_position)
					if d < best_dist:
						best_dist = d
						best_enemy = enemy
			
			if best_enemy:
				current_target = best_enemy
				return # Found closest valid target
	
	# No target found in line
	current_target = null

func _get_facing_vector() -> Vector2i:
	if not _parent_building: return Vector2i(0, -1) # Default Up
	
	# Use BaseBuilding's output_direction logic if available
	if "output_direction" in _parent_building:
		# BaseBuilding Enums: 0=Down, 1=Left, 2=Up, 3=Right
		# NOTE: LaneManager Coordinates -> Z is Rows (Lanes), X is Depth
		# +Z is Down, -Z is Up, +X is Right, -X is Left
		
		# Wait, let's check coordinate system from LaneManager.gd:
		# x = depth, z = lane_idx
		# So typically enemies move from +X to 0.
		
		# If Turret faces RIGHT (+X), it looks into positive X.
		
		match _parent_building.output_direction:
			0: return Vector2i(0, 1)  # Down (+Z)
			1: return Vector2i(-1, 0) # Left (-X)
			2: return Vector2i(0, -1) # Up (-Z)
			3: return Vector2i(1, 0)  # Right (+X)
			
	# Fallback using rotation if output_direction isn't set or valid
	var fwd = _parent_building.global_transform.basis.z
	# Snap to grid vector
	if abs(fwd.x) > abs(fwd.z):
		return Vector2i(sign(fwd.x), 0)
	else:
		return Vector2i(0, sign(fwd.z))
	return Vector2i(1, 0)

func _is_tile_in_range(target_tile: Vector2i) -> bool:
	var my_tile = LaneManager.world_to_tile(_parent_building.global_position)
	var diff = target_tile - my_tile
	var dir = _get_facing_vector()
	
	# Check alignment (Must be on the line defined by dir)
	if dir.x != 0:
		if diff.y != 0: return false # Not in same row
		if sign(diff.x) != dir.x: return false # Behind us
		return abs(diff.x) <= range_tiles
	else:
		if diff.x != 0: return false # Not in same col
		if sign(diff.y) != dir.y: return false # Behind us
		return abs(diff.y) <= range_tiles
