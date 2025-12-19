@tool
class_name TurretBuilding
extends BaseBuilding

# Component references
@onready var target_acquirer: TargetAcquirerComponent = $TargetAcquirerComponent
@onready var shooter: ShooterComponent = $ShooterComponent
@onready var rotatable: Node2D = $Rotatable

@export var storage_cap: int = 100

# Add Inventory
@onready var inventory: InventoryComponent = InventoryComponent.new()

func _init() -> void:
	# Configure capabilities for Editor & Runtime
	has_output = false
	has_input = true

func _get_main_sprite() -> AnimatedSprite2D:
	return get_node_or_null("Rotatable/TurretBase")

func _ready() -> void:
	if Engine.is_editor_hint():
		return

	center_offset = Vector2(0, 16)
	
	inventory.name = "InventoryComponent"
	inventory.max_slots = 1
	inventory.slot_capacity = storage_cap 
	add_child(inventory)

	target_acquirer.validation_callback = _is_valid_target

	super._ready() 
	
	set_build_rotation(&"idle_up")
	
	assert(target_acquirer, "Turret is missing TargetAcquirerComponent!")
	assert(shooter, "Turret is missing ShooterComponent!")
	assert(rotatable, "Turret is missing a Node2D named 'Rotatable'!")

	target_acquirer.target_acquired.connect(_on_target_acquired)

func _is_valid_target(body: Node2D) -> bool:
	var my_center = global_position + center_offset
	var my_tile = LaneManager.tile_map.local_to_map(my_center)
	var my_logical = LaneManager.get_logical_from_tile(my_tile)
	
	var enemy_tile = LaneManager.tile_map.local_to_map(body.global_position)
	var enemy_logical = LaneManager.get_logical_from_tile(enemy_tile)
	
	if my_logical == Vector2i(-1, -1) or enemy_logical == Vector2i(-1, -1):
		return false
	
	# Check alignment based on output direction axis
	match output_direction:
		Direction.UP, Direction.DOWN:
			return my_logical.x == enemy_logical.x
		Direction.LEFT, Direction.RIGHT:
			return my_logical.y == enemy_logical.y
			
	return false

func _on_power_status_changed(has_power: bool) -> void:
	super._on_power_status_changed(has_power)

func _on_target_acquired(_target: Node2D) -> void:
	pass

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or not is_active:
		return
		
	var current_target = target_acquirer.current_target
	if is_instance_valid(current_target):
		var ammo = inventory.get_first_item()
		if ammo:
			if shooter.can_shoot():
				
				# 1. Determine direction based on tile geometry
				var shoot_dir = _get_shoot_dir_vector(output_direction)
				
				# 2. Determine Lane Filter
				# If shooting UP/DOWN (Lane Axis), we only want to hit enemies in this lane index (Logical X)
				# If shooting LEFT/RIGHT (Row Axis), we cross lanes, so filter is -1 (hit all)
				var filter_lane_id = -1
				
				if output_direction == Direction.UP or output_direction == Direction.DOWN:
					var my_tile = LaneManager.tile_map.local_to_map(global_position + center_offset)
					var my_logical = LaneManager.get_logical_from_tile(my_tile)
					if my_logical != Vector2i(-1, -1):
						filter_lane_id = my_logical.x
				
				# 3. Calculate Start Position (Center of Tile) to ensure perfect alignment
				var my_tile_map_coord = LaneManager.tile_map.local_to_map(global_position + center_offset)
				var tile_center_world = LaneManager.tile_map.map_to_local(my_tile_map_coord)
				
				shooter.shoot_in_direction(shoot_dir, filter_lane_id, ammo, tile_center_world)
				inventory.remove_item(ammo, 1)

func _get_shoot_dir_vector(dir: Direction) -> Vector2:
	# Calculate vectors based on tile centers to ensure axis alignment
	var my_tile = LaneManager.tile_map.local_to_map(global_position + center_offset)
	var my_pos = LaneManager.tile_map.map_to_local(my_tile)
	
	var target_tile = my_tile
	
	# Try logical neighbors first (Lane Logic)
	var my_logical = LaneManager.get_logical_from_tile(my_tile)
	if my_logical != Vector2i(-1, -1):
		var target_logical = my_logical
		match dir:
			# Swapped logic for UP and DOWN based on request
			Direction.DOWN: target_logical += Vector2i(0, 1)
			Direction.UP:   target_logical += Vector2i(0, -1)
			Direction.LEFT: target_logical += Vector2i(1, 0)
			Direction.RIGHT:target_logical += Vector2i(-1, 0)
		target_tile = LaneManager.get_tile_from_logical(target_logical.x, target_logical.y)
	
	# Fallback to physical if logical failed or stayed same
	if target_tile == my_tile or target_tile == Vector2i(-1, -1):
		match dir:
			# Swapped logic for UP and DOWN based on request
			Direction.DOWN: target_tile = my_tile + Vector2i(0, -1)
			Direction.UP:   target_tile = my_tile + Vector2i(0, 1)
			Direction.LEFT: target_tile = my_tile + Vector2i(-1, 0)
			Direction.RIGHT:target_tile = my_tile + Vector2i(1, 0)
			
	var target_pos = LaneManager.tile_map.map_to_local(target_tile)
	return my_pos.direction_to(target_pos)

func receive_item(item: ItemResource, _from_node: Node2D = null) -> bool:
	return inventory.add_item(item) == 0
