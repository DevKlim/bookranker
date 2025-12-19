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
var secondary_sprite: AnimatedSprite2D

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
	
	# Force an update of position based on current animation
	var main = _get_main_sprite()
	if main:
		_update_secondary_visuals(main.animation)

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

func receive_item(item: ItemResource, _from_node: Node2D = null) -> bool:
	if not has_input: return false
	if current_recipe:
		if item == current_recipe.input_item:
			return input_inventory.add_item(item) == 0
	return false

func requires_recipe_selection() -> bool:
	return true

# --- Visual Logic ---

func _get_extra_offset(anim_name: StringName) -> Vector2i:
	# Returns the tile coordinate of the "back" of the machine (Input side),
	# relative to the "front" (Output side/Origin).
	match anim_name:
		&"idle_down":  return Vector2i(0, -1)
		&"idle_up":    return Vector2i(0, 1)
		&"idle_left":  return Vector2i(1, 0)
		&"idle_right": return Vector2i(-1, 0)
	return Vector2i.ZERO

## Define the extra sprite configuration for the Build System & Preview (Offsets only)
func get_visual_configuration(anim_name: StringName) -> Array:
	var offset = _get_extra_offset(anim_name)
	if offset == Vector2i.ZERO: return []
	
	return [{
		"offset": offset,
		"animation": anim_name # Use same animation frame
	}]

## Return ALL occupied tiles including the origin
func get_occupied_cells(anim_name: StringName) -> Array[Vector2i]:
	return [Vector2i.ZERO, _get_extra_offset(anim_name)]

# Override rotation to update internal secondary sprite
func set_build_rotation(anim_name: StringName) -> void:
	super.set_build_rotation(anim_name)
	_update_secondary_visuals(anim_name)

func _update_secondary_visuals(anim_name: StringName) -> void:
	if not is_instance_valid(secondary_sprite): return
	
	if secondary_sprite.sprite_frames.has_animation(anim_name):
		secondary_sprite.play(anim_name)
	
	var rigid_offset = _get_extra_offset(anim_name)
	var pixel_offset = Vector2.ZERO
	var snapped_to_lane = false
	
	# Runtime: Try to snap to logical lane to avoid physical zigzag gaps
	if not Engine.is_editor_hint():
		var my_tile = LaneManager.tile_map.local_to_map(global_position)
		var my_log = LaneManager.get_logical_from_tile(my_tile)
		
		# If we are on a valid lane tile
		if my_log != Vector2i(-1, -1):
			var target_log = my_log
			
			# Determine where the Input Neighbor should be in Logical Space
			match input_direction:
				Direction.UP:    target_log.y += 1 # Up = Depth+1
				Direction.DOWN:  target_log.y -= 1
				Direction.LEFT:  target_log.x += 1 # Input from Right = Lane+1 (Wait, mapping check?)
				Direction.RIGHT: target_log.x -= 1
			
			var target_phys = LaneManager.get_tile_from_logical(target_log.x, target_log.y)
			
			# If a valid neighbor exists on the lane, align to it visually
			if target_phys != Vector2i(-1, -1):
				var p0 = LaneManager.tile_map.map_to_local(my_tile)
				var p1 = LaneManager.tile_map.map_to_local(target_phys)
				pixel_offset = p1 - p0
				snapped_to_lane = true
	
	# Fallback (Editor or Off-Lane): Use rigid physical offset
	if not snapped_to_lane:
		if not Engine.is_editor_hint() and is_instance_valid(LaneManager.tile_map):
			var tm = LaneManager.tile_map
			var p0 = tm.map_to_local(Vector2i.ZERO)
			var p1 = tm.map_to_local(rigid_offset)
			pixel_offset = p1 - p0
		else:
			# Editor Approximation (Standard Iso)
			pixel_offset = Vector2((rigid_offset.x - rigid_offset.y) * 16, (rigid_offset.x + rigid_offset.y) * 8)

	var main = _get_main_sprite()
	if main:
		secondary_sprite.position = main.position + pixel_offset

func _on_power_status_changed(has_power: bool) -> void:
	super._on_power_status_changed(has_power)
	if is_instance_valid(secondary_sprite):
		secondary_sprite.modulate = powered_color if has_power else unpowered_color

func get_processing_icon() -> Texture2D:
	if current_recipe:
		return current_recipe.output_item.icon
	return null
