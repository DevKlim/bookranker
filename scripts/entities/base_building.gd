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
@export var output_direction: Direction = Direction.DOWN
@export var input_direction: Direction = Direction.UP
@export var has_input: bool = true
@export var has_output: bool = true

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
	# Debug check to confirm buildings receive the signal
	if is_active != has_power:
		print("Building %s (%s) Power Changed: %s" % [name, str(self), has_power])
		
	is_active = has_power
	var animated_sprite = _get_main_sprite()
	if is_instance_valid(animated_sprite):
		animated_sprite.modulate = powered_color if has_power else unpowered_color

func set_build_rotation(rotation_val: Variant) -> void:
	var dir_idx = 0
	if typeof(rotation_val) == TYPE_INT:
		dir_idx = rotation_val
	elif typeof(rotation_val) == TYPE_STRING:
		var s = String(rotation_val)
		if s.ends_with("down"): dir_idx = Direction.DOWN
		elif s.ends_with("left"): dir_idx = Direction.LEFT
		elif s.ends_with("up"): dir_idx = Direction.UP
		elif s.ends_with("right"): dir_idx = Direction.RIGHT

	output_direction = dir_idx as Direction
	
	match output_direction:
		Direction.DOWN: input_direction = Direction.UP
		Direction.LEFT: input_direction = Direction.RIGHT
		Direction.UP:   input_direction = Direction.DOWN
		Direction.RIGHT:input_direction = Direction.LEFT
		_: input_direction = Direction.UP

	var rads = 0.0
	match output_direction:
		Direction.DOWN: rads = PI       
		Direction.LEFT: rads = PI * 0.5 
		Direction.UP:   rads = 0.0      
		Direction.RIGHT:rads = -PI * 0.5
	
	rotation = Vector3(0, rads, 0)

func get_occupied_cells(_anim: Variant) -> Array[Vector2i]: return [Vector2i.ZERO]
func _on_died(_node): queue_free()

## Generic Receive Item.
## Ignores lane data to treat all inputs equally (funnel behavior).
func receive_item(item: Resource, _from_node: Node3D = null, _extra_data: Dictionary = {}) -> bool: 
	if not has_input: return false
	
	var i = item as ItemResource
	if not i: return false
	
	if inventory_component:
		if not inventory_component.can_receive: return false
		# add_item returns remainder. 0 means success (all added).
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
	
	var n = get_neighbor(output_direction)
	if is_instance_valid(n) and n.has_method("receive_item"):
		if n.get("has_input") == false: return false
		var it = inv.get_first_item()
		if it:
			if n.receive_item(it, self):
				inv.remove_item(it, 1)
				return true
	return false

func requires_recipe_selection() -> bool: return false
