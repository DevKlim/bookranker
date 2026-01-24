@tool
class_name Burnace
extends BaseBuilding

@export var recipes: Array[RecipeResource] = []

var input_inventory: InventoryComponent
var output_inventory: InventoryComponent
var fuel_inventory: InventoryComponent
var crafter # Dynamic type

var active_recipe: RecipeResource = null
var burn_time_remaining: float = 0.0
var max_burn_time: float = 0.0

func _init() -> void:
	has_input = true
	has_output = true
	input_inventory = InventoryComponent.new()
	output_inventory = InventoryComponent.new()
	fuel_inventory = InventoryComponent.new()

func _ready() -> void:
	if Engine.is_editor_hint(): return
	
	# Try to find existing component first
	crafter = get_node_or_null("CrafterComponent")
	if not crafter:
		var script = load("res://scripts/components/crafter_component.gd")
		if script:
			crafter = script.new()
			crafter.name = "CrafterComponent"
			add_child(crafter)
	
	input_inventory.name = "InputInventory"
	input_inventory.max_slots = 1
	input_inventory.slot_capacity = 20
	add_child(input_inventory)
	
	fuel_inventory.name = "FuelInventory"
	fuel_inventory.max_slots = 1
	fuel_inventory.slot_capacity = 20
	var coal_res = load("res://resources/items/coal.tres")
	if coal_res: fuel_inventory.allowed_items = [coal_res]
	add_child(fuel_inventory)
	
	output_inventory.name = "OutputInventory"
	output_inventory.max_slots = 1
	output_inventory.slot_capacity = 20
	add_child(output_inventory)
	
	super._ready()
	
	if recipes.is_empty() and GameManager.has_method("get_available_recipes"):
		var all = GameManager.get_available_recipes()
		for r in all:
			if r.category == "smelting":
				recipes.append(r)

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not is_active or not crafter: return
	
	_handle_fuel(delta)
	
	if burn_time_remaining > 0:
		if active_recipe and not crafter.is_busy():
			_try_start_smelting()
			
		if crafter.update_process(delta):
			_complete_smelt()
	
	if not active_recipe and not crafter.is_busy():
		_detect_recipe()

	if output_inventory.has_item():
		try_output_from_inventory(output_inventory)

func _handle_fuel(delta: float) -> void:
	if burn_time_remaining > 0:
		burn_time_remaining -= delta
	
	if burn_time_remaining <= 0 and fuel_inventory.has_item():
		if input_inventory.has_item():
			var fuel_item = fuel_inventory.get_first_item()
			if fuel_inventory.remove_item(fuel_item, 1):
				burn_time_remaining = 10.0 
				max_burn_time = 10.0

func _detect_recipe() -> void:
	var input_item = input_inventory.get_first_item()
	if not input_item: return

	for r in recipes:
		if r.input_item == input_item or r.input_item.resource_path == input_item.resource_path:
			active_recipe = r
			break

func _try_start_smelting() -> void:
	if not active_recipe: return
	
	var input_item = input_inventory.get_first_item()
	if not input_item or input_item.resource_path != active_recipe.input_item.resource_path:
		active_recipe = null
		return

	if input_inventory.slots[0].count >= active_recipe.input_count:
		if output_inventory.has_space_for(active_recipe.output_item):
			if input_inventory.remove_item(input_item, active_recipe.input_count):
				crafter.start_craft(active_recipe)

func _complete_smelt() -> void:
	if active_recipe:
		output_inventory.add_item(active_recipe.output_item, active_recipe.output_count)
		crafter.stop_craft()
		
func receive_item(item: Resource, _from_node: Node3D = null, _extra_data: Dictionary = {}) -> bool:
	if not has_input: return false
	var i = item as ItemResource
	if not i: return false
	
	# Priority to Fuel
	if i.item_name == "Coal":
		if fuel_inventory.add_item(i) == 0:
			return true
	
	var is_valid_ore = false
	for r in recipes:
		if r.input_item.resource_path == i.resource_path:
			is_valid_ore = true
			break
	
	if is_valid_ore:
		return input_inventory.add_item(i) == 0
		
	return false

func requires_recipe_selection() -> bool:
	return false

func get_processing_icon() -> Texture2D:
	if active_recipe:
		return active_recipe.output_item.icon
	return null
