@tool
class_name BaseBuilding
extends StaticBody3D

enum Direction { DOWN, LEFT, UP, RIGHT }

# Components
var power_consumer: PowerConsumerComponent
var health_component: HealthComponent
var inventory_component: InventoryComponent

var grid_component: Node
@export var powered_color: Color = Color(1, 1, 1, 1)
@export var unpowered_color: Color = Color(0.2, 0.2, 0.2, 1)

@export_group("I/O Configuration")
# Mask: 1=Down, 2=Left, 4=Up, 8=Right
# These are the *current* global directions based on rotation
@export_flags("Down:1", "Left:2", "Up:4", "Right:8") var input_mask: int = 15
@export_flags("Down:1", "Left:2", "Up:4", "Right:8") var output_mask: int = 15

# Default "Relative" Masks (Before rotation)
# 1=Down(Back), 2=Left, 4=Up(Front), 8=Right
@export var default_input_mask: int = 15
@export var default_output_mask: int = 15

@export var has_input: bool = true
@export var has_output: bool = true

# Legacy Single Direction Support (for logic that hasn't migrated to masks yet)
var output_direction: Direction = Direction.DOWN
var input_direction: Direction = Direction.UP

@export_group("Layout")
## Define the footprint of the building relative to the center [0,0].
## Populated by the data importer or manually.
@export var layout_config: Array[Vector2i] = [Vector2i.ZERO]

var visual_offset: Vector3 = Vector3.ZERO
var is_active: bool = false
var stats: Dictionary = {}

func _get_main_sprite() -> AnimatedSprite3D:
	return get_node_or_null("AnimatedSprite3D")

func _ready() -> void:
	if Engine.is_editor_hint(): return
	if has_meta("is_preview"): return
	
	_setup_visuals()
	_setup_grid_component()
	_setup_power_component()
	_setup_health_component()
	_setup_inventory_component()
	
	# Initial rotation application to set masks
	set_build_rotation(0)
	
	# Initialize as false, waiting for PowerGrid to update us
	_on_power_status_changed(false)

func _setup_visuals() -> void:
	var sprite = _get_main_sprite()
	if sprite: 
		sprite.position = visual_offset
	else:
		var visual = get_node_or_null("BlockVisual")
		if visual: visual.position = visual_offset

func _setup_grid_component() -> void:
	if not has_node("GridComponent"):
		grid_component = GridComponent.new()
		grid_component.name = "GridComponent"
		grid_component.layer = "building"
		if "snap_to_grid" in grid_component:
			grid_component.snap_to_grid = true
		add_child(grid_component)
	else:
		grid_component = get_node("GridComponent")

func _setup_power_component() -> void:
	power_consumer = get_node_or_null("PowerConsumerComponent")
	if not power_consumer:
		power_consumer = PowerConsumerComponent.new()
		power_consumer.name = "PowerConsumerComponent"
		power_consumer.power_consumption = 5.0 
		add_child(power_consumer)
	PowerGridManager.register_consumer(power_consumer)

func _setup_health_component() -> void:
	health_component = get_node_or_null("HealthComponent")
	if not health_component:
		health_component = HealthComponent.new()
		health_component.name = "HealthComponent"
		health_component.max_health = 100.0
		add_child(health_component)
	health_component.died.connect(_on_died)

func _setup_inventory_component() -> void:
	# Try to find existing inventory (from scene or importer)
	inventory_component = get_node_or_null("InventoryComponent")
	if not inventory_component:
		inventory_component = get_node_or_null("InputInventory")

func _on_power_status_changed(has_power: bool) -> void:
	is_active = has_power
	var animated_sprite = _get_main_sprite()
	if is_instance_valid(animated_sprite):
		animated_sprite.modulate = powered_color if has_power else unpowered_color

func set_build_rotation(rotation_val: Variant) -> void:
	var dir_idx = 0
	if typeof(rotation_val) == TYPE_INT:
		dir_idx = rotation_val
	elif typeof(rotation_val) == TYPE_STRING:
		# Fallback parsing
		var s = String(rotation_val)
		if s.ends_with("down"): dir_idx = 0
		elif s.ends_with("left"): dir_idx = 1
		elif s.ends_with("up"): dir_idx = 2
		elif s.ends_with("right"): dir_idx = 3

	# Legacy single direction updates (assumes typical Conveyor logic: Output=Rot, Input=Opposite)
	output_direction = dir_idx as Direction
	match output_direction:
		Direction.DOWN: input_direction = Direction.UP
		Direction.LEFT: input_direction = Direction.RIGHT
		Direction.UP:   input_direction = Direction.DOWN
		Direction.RIGHT:input_direction = Direction.LEFT
		_: input_direction = Direction.UP

	# --- Bitmask Rotation Logic ---
	# Rotate the default mask bits left by 'dir_idx' positions (circular 4-bit shift)
	# 1->2->4->8->1
	input_mask = _rotate_bitmask(default_input_mask, dir_idx)
	output_mask = _rotate_bitmask(default_output_mask, dir_idx)
	
	# Apply Visual Rotation
	var rads = 0.0
	match dir_idx:
		0: rads = PI       
		1: rads = PI * 0.5 
		2: rads = 0.0      
		3: rads = -PI * 0.5
	rotation = Vector3(0, rads, 0)

func _rotate_bitmask(mask: int, steps: int) -> int:
	# Mask is 4 bits: 0..3
	var result = 0
	for i in range(4):
		if (mask & (1 << i)) != 0:
			var new_pos = (i + steps) % 4
			result |= (1 << new_pos)
	return result

## Returns the list of occupied grid offsets based on rotation
func get_occupied_cells(rotation_index: int = -1) -> Array[Vector2i]:
	if layout_config.is_empty():
		return [Vector2i.ZERO]
	
	var ri = rotation_index
	if ri == -1: ri = int(output_direction) # Use current if not specified
	
	var result: Array[Vector2i] = []
	for point in layout_config:
		var p = point
		# 0 (Down/Back) -> 180 degrees
		if ri == 0:
			p = Vector2i(-point.x, -point.y)
		# 1 (Left) -> 90 degrees
		elif ri == 1:
			p = Vector2i(point.y, -point.x)
		# 2 (Up/Fwd) -> 0 degrees (Original)
		elif ri == 2:
			p = point
		# 3 (Right) -> -90 degrees
		elif ri == 3:
			p = Vector2i(-point.y, point.x)
			
		result.append(p)
		
	return result

func _on_died(_node): queue_free()

## Generic Receive Item.
func receive_item(item: Resource, from_node: Node3D = null, _extra_data: Dictionary = {}) -> bool: 
	if not has_input: return false
	
	# Validate direction mask if from_node is provided
	if from_node:
		var my_tile = LaneManager.world_to_tile(global_position)
		var sender_tile = LaneManager.world_to_tile(from_node.global_position)
		var diff = sender_tile - my_tile
		
		# Determine incoming direction relative to ME
		var incoming_dir = -1
		if diff == Vector2i(0, 1): incoming_dir = Direction.DOWN
		elif diff == Vector2i(-1, 0): incoming_dir = Direction.LEFT
		elif diff == Vector2i(0, -1): incoming_dir = Direction.UP
		elif diff == Vector2i(1, 0): incoming_dir = Direction.RIGHT
		
		if incoming_dir != -1:
			if not (input_mask & (1 << incoming_dir)):
				return false # Blocked side

	var i = item as ItemResource
	if not i: return false
	
	if inventory_component:
		if not inventory_component.can_receive: return false
		var remainder = inventory_component.add_item(i, 1)
		return remainder == 0
		
	return false

func get_neighbor(dir: Direction) -> Node3D:
	if Engine.is_editor_hint(): return null
	var tile = LaneManager.world_to_tile(global_position)
	var offset = Vector2i.ZERO
	match dir:
		Direction.DOWN: offset = Vector2i(0, 1)
		Direction.UP:   offset = Vector2i(0, -1)
		Direction.LEFT: offset = Vector2i(-1, 0)
		Direction.RIGHT:offset = Vector2i(1, 0)
	return LaneManager.get_buildable_at(tile + offset)

func try_output_from_inventory(inv: InventoryComponent) -> bool:
	if not has_output or not inv.has_item(): return false
	if not inv.can_output: return false
	
	# Check all allowed output directions
	for i in range(4):
		if (output_mask & (1 << i)):
			var n = get_neighbor(i as Direction)
			if is_instance_valid(n) and n.has_method("receive_item"):
				# Check if neighbor accepts input
				if n.get("has_input") == false: continue
				
				var it = inv.get_first_item()
				if it:
					if n.receive_item(it, self):
						inv.remove_item(it, 1)
						return true
	return false

func requires_recipe_selection() -> bool: return false
