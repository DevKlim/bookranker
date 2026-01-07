@tool
class_name Burnace
extends BaseBuilding

## The Burnace (Furnace) automatically smelts valid ores into alloys.
## It auto-detects the recipe based on the input item.

@export var recipes: Array[RecipeResource] = []

@onready var input_inventory: InventoryComponent = InventoryComponent.new()
@onready var output_inventory: InventoryComponent = InventoryComponent.new()

var craft_timer: float = 0.0
var is_smelting: bool = false
var active_recipe: RecipeResource = null

func _init() -> void:
	has_input = true
	has_output = true

func _ready() -> void:
	if Engine.is_editor_hint(): return
	
	input_inventory.name = "InputInventory"
	input_inventory.max_slots = 1
	input_inventory.slot_capacity = 20
	add_child(input_inventory)
	
	output_inventory.name = "OutputInventory"
	output_inventory.max_slots = 1
	output_inventory.slot_capacity = 20
	add_child(output_inventory)
	
	super._ready()
	
	if recipes.is_empty():
		_load_default_recipes()

func _load_default_recipes() -> void:
	var defaults = [
		"res://resources/recipes/smelt_iron.tres",
		"res://resources/recipes/smelt_copper.tres"
	]
	for path in defaults:
		if ResourceLoader.exists(path):
			recipes.append(load(path))

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not is_active: return
	
	_handle_smelting(delta)
	
	# Continuously try to output result
	if output_inventory.has_item():
		try_output_from_inventory(output_inventory)

func _handle_smelting(delta: float) -> void:
	if is_smelting and active_recipe:
		craft_timer += delta
		if craft_timer >= active_recipe.craft_time:
			_complete_smelt()
	else:
		_try_start_smelting()

func _try_start_smelting() -> void:
	var input_item = input_inventory.get_first_item()
	if not input_item: return

	var potential_recipe = null
	for r in recipes:
		if r.input_item == input_item:
			potential_recipe = r
			break
		elif r.input_item.resource_path == input_item.resource_path:
			potential_recipe = r
			break
		elif r.input_item.item_name == input_item.item_name:
			potential_recipe = r
			break
	
	if potential_recipe:
		var slot = input_inventory.slots[0]
		if slot.count >= potential_recipe.input_count:
			if output_inventory.has_space_for(potential_recipe.output_item):
				if input_inventory.remove_item(input_item, potential_recipe.input_count):
					active_recipe = potential_recipe
					is_smelting = true
					craft_timer = 0.0

func _complete_smelt() -> void:
	is_smelting = false
	craft_timer = 0.0
	if active_recipe:
		output_inventory.add_item(active_recipe.output_item, active_recipe.output_count)
		active_recipe = null

func receive_item(item: Resource, _from_node: Node3D = null, _extra_data: Dictionary = {}) -> bool:
	if not has_input: return false
	var i = item as ItemResource
	if not i: return false
	
	# Validation: Ensure item works with at least one recipe
	var is_valid = false
	for r in recipes:
		if r.input_item == i or r.input_item.item_name == i.item_name:
			is_valid = true
			break
	
	if is_valid:
		return input_inventory.add_item(i) == 0
		
	return false

func requires_recipe_selection() -> bool:
	return false

func get_processing_icon() -> Texture2D:
	if active_recipe:
		return active_recipe.output_item.icon
	var item = input_inventory.get_first_item()
	if item:
		for r in recipes:
			if r.input_item == item or r.input_item.item_name == item.item_name:
				return r.output_item.icon
	return null

func get_input_count() -> int:
	var slot = input_inventory.slots[0]
	return slot.count if slot else 0

func get_output_count() -> int:
	var slot = output_inventory.slots[0]
	return slot.count if slot else 0
