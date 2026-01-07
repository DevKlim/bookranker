@tool
class_name Asourcer
extends BaseBuilding

## The Asourcer (Assembler) takes inputs, processes them based on a recipe, and outputs a result.
## Occupies 2 tiles dynamically based on rotation.

@export var recipes: Array[RecipeResource] = []
var current_recipe: RecipeResource

@onready var input_inventory: InventoryComponent = InventoryComponent.new()
@onready var output_inventory: InventoryComponent = InventoryComponent.new()

# The secondary sprite to cover the 2nd tile
var secondary_sprite: AnimatedSprite3D

var craft_timer: float = 0.0
var is_crafting: bool = false

func _init() -> void:
	has_input = true
	has_output = true

func _ready() -> void:
	if not Engine.is_editor_hint():
		# Runtime Initialization
		input_inventory.name = "InputInventory"
		input_inventory.max_slots = 5 
		input_inventory.slot_capacity = 20
		add_child(input_inventory)
		
		output_inventory.name = "OutputInventory"
		output_inventory.max_slots = 1
		output_inventory.slot_capacity = 20
		add_child(output_inventory)
	
	# Visual Setup (Run in both Editor and Game)
	_setup_secondary_sprite()
	
	super._ready()
	
	if not Engine.is_editor_hint():
		# Load default recipes if none assigned
		if recipes.is_empty():
			_load_default_recipes()

		# Default to first recipe if available
		if not recipes.is_empty():
			set_recipe(recipes[0])
		
func _setup_secondary_sprite() -> void:
	# Ensure we have a secondary sprite for the 2x1 visual
	if has_node("SecondarySprite"):
		secondary_sprite = get_node("SecondarySprite")
	else:
		var main_sprite = _get_main_sprite()
		if main_sprite:
			secondary_sprite = main_sprite.duplicate()
			secondary_sprite.name = "SecondarySprite"
			add_child(secondary_sprite)
	
	# Force an update of position based on current output direction
	_update_secondary_visuals()

func _load_default_recipes() -> void:
	var defaults = [
		"res://resources/recipes/craft_cable.tres",
		"res://resources/recipes/craft_gear.tres",
		"res://resources/recipes/craft_rod.tres"
	]
	for path in defaults:
		if ResourceLoader.exists(path):
			recipes.append(load(path))

func _process(delta: float) -> void:
	if Engine.is_editor_hint(): 
		return
	
	if not is_active: return
	
	_handle_crafting(delta)
	
	if output_inventory.has_item():
		try_output_from_inventory(output_inventory)

func _handle_crafting(delta: float) -> void:
	if not current_recipe: return
	
	if is_crafting:
		craft_timer += delta
		if craft_timer >= current_recipe.craft_time:
			complete_craft()
	else:
		_try_start_craft()

func _try_start_craft() -> void:
	if not current_recipe: return
	
	# 1. Check Output Space
	if not output_inventory.has_space_for(current_recipe.output_item):
		return
		
	# 2. Check Input Requirements
	var available_count = 0
	for slot in input_inventory.slots:
		if slot != null and slot.item == current_recipe.input_item:
			available_count += slot.count
	
	if available_count >= current_recipe.input_count:
		input_inventory.remove_item(current_recipe.input_item, current_recipe.input_count)
		is_crafting = true
		craft_timer = 0.0

func complete_craft() -> void:
	is_crafting = false
	craft_timer = 0.0
	if current_recipe:
		output_inventory.add_item(current_recipe.output_item, current_recipe.output_count)

func set_recipe(recipe: RecipeResource) -> void:
	if current_recipe != recipe:
		current_recipe = recipe
		is_crafting = false
		craft_timer = 0.0

func receive_item(item: Resource, _from_node: Node3D = null, _extra_data: Dictionary = {}) -> bool:
	if not has_input: return false
	if not item is ItemResource: return false
	
	# Relaxed Logic: Accept item if it belongs to ANY recipe, not just the active one.
	var is_valid_ingredient = false
	for r in recipes:
		if r.input_item == item or r.input_item.item_name == item.item_name:
			is_valid_ingredient = true
			break
	
	if is_valid_ingredient:
		return input_inventory.add_item(item) == 0
		
	return false

func requires_recipe_selection() -> bool:
	return true

# --- Visual Logic ---

func _get_extra_offset_by_dir(dir: Direction) -> Vector2i:
	match dir:
		Direction.DOWN:  return Vector2i(0, -1)
		Direction.UP:    return Vector2i(0, 1)
		Direction.LEFT:  return Vector2i(1, 0)
		Direction.RIGHT: return Vector2i(-1, 0)
	return Vector2i.ZERO

func get_occupied_cells(rot_val: Variant) -> Array[Vector2i]:
	var dir = Direction.DOWN
	if typeof(rot_val) == TYPE_INT:
		dir = rot_val as Direction
	elif typeof(rot_val) == TYPE_STRING:
		var s = String(rot_val)
		if s.ends_with("down"): dir = Direction.DOWN
		elif s.ends_with("up"): dir = Direction.UP
		elif s.ends_with("left"): dir = Direction.LEFT
		elif s.ends_with("right"): dir = Direction.RIGHT
		
	return [Vector2i.ZERO, _get_extra_offset_by_dir(dir)]

func set_build_rotation(rotation_val: Variant) -> void:
	super.set_build_rotation(rotation_val)
	_update_secondary_visuals()

func _update_secondary_visuals() -> void:
	if not is_instance_valid(secondary_sprite): return
	
	var pixel_offset = Vector3(0, 0, 1.0)
	
	if not Engine.is_editor_hint():
		var my_tile = LaneManager.world_to_tile(global_position - LaneManager.get_layer_offset("building"))
		var my_log = LaneManager.get_logical_from_tile(my_tile)
		
		if my_log != Vector2i(-1, -1):
			var target_log = my_log
			match input_direction:
				Direction.UP:    target_log.y += 1 
				Direction.DOWN:  target_log.y -= 1
				Direction.LEFT:  target_log.x += 1 
				Direction.RIGHT: target_log.x -= 1
			
			var target_phys = LaneManager.get_tile_from_logical(target_log.x, target_log.y)
			if target_phys != Vector2i(-1, -1):
				var p0 = LaneManager.tile_to_world(my_tile)
				var p1 = LaneManager.tile_to_world(target_phys)
				var global_vec = p1 - p0
				pixel_offset = global_transform.basis.inverse() * global_vec
	
	secondary_sprite.position = pixel_offset
	if secondary_sprite.sprite_frames.has_animation("idle_down"):
		if secondary_sprite.animation != "idle_down":
			secondary_sprite.play("idle_down")

func _on_power_status_changed(has_power: bool) -> void:
	super._on_power_status_changed(has_power)
	if is_instance_valid(secondary_sprite):
		secondary_sprite.modulate = powered_color if has_power else unpowered_color

func get_processing_icon() -> Texture2D:
	if current_recipe:
		return current_recipe.output_item.icon
	return null
