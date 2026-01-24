@tool
class_name BaseBuilding
extends StaticBody3D

enum Direction { DOWN, LEFT, UP, RIGHT }

# Components
var power_consumer: PowerConsumerComponent
var health_component: HealthComponent
var inventory_component: InventoryComponent
var inventory_component_alt: InventoryComponent # Handle "InputInventory" legacy
var elemental_component: ElementalComponent

var grid_component: Node
@export var powered_color: Color = Color(1, 1, 1, 1)
@export var unpowered_color: Color = Color(0.2, 0.2, 0.2, 1)

# Identity
@export var display_name: String = ""

@export_group("Stats")
@export var max_health: float = 100.0
@export var max_energy: float = 50.0
@export var power_consumption: float = 5.0
@export var efficiency: float = 1.0 
@export var lux_stat: float = 0.0 
@export var luck_stat: float = 0.0

@export_group("I/O Configuration")
var input_mask: int = 0
var output_mask: int = 0

@export_flags("Down:1", "Left:2", "Up:4", "Right:8") var default_input_mask: int = 15:
	set(value):
		default_input_mask = value
		_update_masks_from_current_rotation()

@export_flags("Down:1", "Left:2", "Up:4", "Right:8") var default_output_mask: int = 15:
	set(value):
		default_output_mask = value
		_update_masks_from_current_rotation()

@export var has_input: bool = true
@export var has_output: bool = true

# Legacy Single Direction Support
var output_direction: Direction = Direction.DOWN
var input_direction: Direction = Direction.UP

@export_group("Layout")
@export var layout_config: Array = []

var visual_offset: Vector3 = Vector3.ZERO
var is_active: bool = false
var is_staggered: bool = false
var stats: Dictionary = {}

func _get_main_sprite() -> AnimatedSprite3D:
	return get_node_or_null("AnimatedSprite3D")

func _ready() -> void:
	if Engine.is_editor_hint(): return
	if has_meta("is_preview"): return
	
	if display_name == "":
		var n = name
		if "@" in n: display_name = "Building"
		else: display_name = n.rstrip("0123456789")
	
	_update_masks_from_current_rotation()
	
	if input_mask > 0: has_input = true
	if output_mask > 0: has_output = true
	
	_setup_visuals()
	_setup_grid_component()
	_setup_elemental_component() 
	_setup_power_component()
	_setup_health_component()
	_setup_inventory_component()
	
	_on_power_status_changed(false)

func _setup_visuals() -> void:
	# FIX: Add offset to existing position (from Scene Editor) instead of overwriting it.
	# This ensures adjustments made in the .tscn file are preserved.
	var sprite = _get_main_sprite()
	if sprite: 
		sprite.position += visual_offset
	else:
		var visual = get_node_or_null("BlockVisual")
		if visual: 
			visual.position += visual_offset

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

func _setup_elemental_component() -> void:
	elemental_component = get_node_or_null("ElementalComponent")
	if not elemental_component:
		elemental_component = ElementalComponent.new()
		elemental_component.name = "ElementalComponent"
		add_child(elemental_component)

func _setup_power_component() -> void:
	power_consumer = get_node_or_null("PowerConsumerComponent")
	if not power_consumer:
		power_consumer = PowerConsumerComponent.new()
		power_consumer.name = "PowerConsumerComponent"
		add_child(power_consumer)
	
	_update_power_consumption()
	PowerGridManager.register_consumer(power_consumer)

func _update_power_consumption() -> void:
	if not power_consumer: return
	var eff = get_stat("efficiency", efficiency)
	if eff <= 0.1: eff = 0.1
	power_consumer.power_consumption = power_consumption / eff

func _setup_health_component() -> void:
	health_component = get_node_or_null("HealthComponent")
	if not health_component:
		health_component = HealthComponent.new()
		health_component.name = "HealthComponent"
		add_child(health_component)
	
	health_component.max_health = max_health
	health_component.current_health = max_health
	health_component.max_energy = max_energy
	health_component.current_energy = max_energy
	
	health_component.died.connect(_on_died)
	health_component.staggered.connect(_on_staggered)
	health_component.recovered.connect(_on_recovered)

func _setup_inventory_component() -> void:
	inventory_component = get_node_or_null("InventoryComponent")
	if not inventory_component:
		inventory_component = get_node_or_null("InputInventory")

func _on_power_status_changed(has_power: bool) -> void:
	is_active = has_power and not is_staggered
	
	var animated_sprite = _get_main_sprite()
	if is_instance_valid(animated_sprite):
		animated_sprite.modulate = powered_color if has_power else unpowered_color
	
	set_process(is_active)
	set_physics_process(is_active)
	
	var shooter = get_node_or_null("ShooterComponent")
	if shooter: shooter.set_process(is_active)

func _on_staggered(_duration: float) -> void:
	is_staggered = true
	_on_power_status_changed(power_consumer.has_power if power_consumer else false)

func _on_recovered() -> void:
	is_staggered = false
	_on_power_status_changed(power_consumer.has_power if power_consumer else false)

func set_build_rotation(rotation_val: Variant) -> void:
	var dir_idx: int = 0
	if typeof(rotation_val) == TYPE_INT: dir_idx = rotation_val
	elif typeof(rotation_val) == TYPE_STRING:
		var s = String(rotation_val)
		if s.ends_with("down"): dir_idx = 0
		elif s.ends_with("left"): dir_idx = 1
		elif s.ends_with("up"): dir_idx = 2
		elif s.ends_with("right"): dir_idx = 3

	output_direction = dir_idx as Direction
	match output_direction:
		Direction.DOWN: input_direction = Direction.UP
		Direction.LEFT: input_direction = Direction.RIGHT
		Direction.UP:   input_direction = Direction.DOWN
		Direction.RIGHT:input_direction = Direction.LEFT
		_: input_direction = Direction.UP

	var shift = (dir_idx + 2) % 4
	input_mask = _rotate_bitmask(int(default_input_mask), shift)
	output_mask = _rotate_bitmask(int(default_output_mask), shift)
	
	var rads = 0.0
	match dir_idx:
		0: rads = PI       
		1: rads = PI * 0.5 
		2: rads = 0.0      
		3: rads = -PI * 0.5
	rotation = Vector3(0, rads, 0)

func _update_masks_from_current_rotation() -> void:
	var y_rot = wrapf(rotation.y, -PI, PI)
	var dir_idx = 2
	if is_equal_approx(abs(y_rot), PI): dir_idx = 0
	elif is_equal_approx(y_rot, PI * 0.5): dir_idx = 1
	elif is_equal_approx(y_rot, -PI * 0.5): dir_idx = 3
	
	var shift = (dir_idx + 2) % 4
	input_mask = _rotate_bitmask(int(default_input_mask), shift)
	output_mask = _rotate_bitmask(int(default_output_mask), shift)

func _rotate_bitmask(mask: int, steps: int) -> int:
	var result: int = 0
	for i in range(4):
		if (mask & (1 << i)) != 0:
			var new_pos = (i + steps) % 4
			result |= (1 << new_pos)
	return result

func get_occupied_cells(rotation_index: int = -1) -> Array[Vector2i]:
	if layout_config.is_empty(): return [Vector2i.ZERO]
	var ri = rotation_index
	if ri == -1: ri = int(output_direction)
	var result: Array[Vector2i] = []
	for point in layout_config:
		var p
		if point is Vector2i: p = point
		else: p = Vector2i.ZERO 
		if ri == 0:   p = Vector2i(-p.x, -p.y)
		elif ri == 1: p = Vector2i(p.y, -p.x)
		elif ri == 2: p = p
		elif ri == 3: p = Vector2i(-p.y, p.x)
		result.append(p)
	return result

func _on_died(_node): queue_free()

func receive_item(item: Resource, from_node: Node3D = null, _extra_data: Dictionary = {}) -> bool: 
	if not has_input: return false
	
	if from_node:
		var my_tile = LaneManager.world_to_tile(global_position)
		var sender_tile = LaneManager.world_to_tile(from_node.global_position)
		var diff = sender_tile - my_tile
		
		var incoming_dir = -1
		if diff == Vector2i(0, 1): incoming_dir = Direction.DOWN
		elif diff == Vector2i(-1, 0): incoming_dir = Direction.LEFT
		elif diff == Vector2i(0, -1): incoming_dir = Direction.UP
		elif diff == Vector2i(1, 0): incoming_dir = Direction.RIGHT
		
		if incoming_dir != -1 and not (input_mask & (1 << incoming_dir)):
			return false 

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
	
	var b = LaneManager.get_buildable_at(tile + offset)
	if b: return b
	return null

func try_output_from_inventory(inv: InventoryComponent) -> bool:
	if not has_output or not inv or not inv.has_item(): return false
	if not inv.can_output: return false
	
	var it = inv.get_first_item()
	if not it: return false

	for i in range(4):
		if (output_mask & (1 << i)):
			var n = get_neighbor(i as Direction)
			if is_instance_valid(n) and n.has_method("receive_item"):
				if n.get("has_input") == false: continue
				
				if n.receive_item(it, self):
					inv.remove_item(it, 1)
					return true
	return false

func requires_recipe_selection() -> bool: return false

func get_stat(stat_name: String, base_value: float) -> float:
	var final_val = base_value
	if elemental_component:
		var mult = elemental_component.get_stat_modifier(stat_name + "_mult")
		final_val *= (1.0 + mult)
		var flat = elemental_component.get_stat_modifier(stat_name + "_flat")
		final_val += flat
	return max(0.0, final_val)

## Updated to accept 3 arguments to match Enemy and HealthComponent signature
func take_damage(amount: float, element: Resource = null, source: Node = null) -> void:
	if health_component: 
		health_component.take_damage(amount, element, source)

func set_active_state(is_active_flag: bool) -> void:
	if is_staggered: is_active_flag = false
	self.is_active = is_active_flag
	set_process(is_active)
	set_physics_process(is_active)
	var shooter = get_node_or_null("ShooterComponent")
	if shooter: shooter.set_process(is_active)
