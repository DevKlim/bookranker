extends BaseBuilding

## The Asorcerer (Assembler) takes an input item, processes it, and outputs a result.

@export var recipes: Array[RecipeResource] = []
var current_recipe: RecipeResource

@onready var input_inventory: InventoryComponent = InventoryComponent.new()
@onready var output_inventory: InventoryComponent = InventoryComponent.new()

var craft_timer: float = 0.0
var is_crafting: bool = false

func _ready() -> void:
	input_inventory.name = "InputInventory"
	input_inventory.max_slots = 1
	input_inventory.slot_capacity = 20
	add_child(input_inventory)
	
	output_inventory.name = "OutputInventory"
	output_inventory.max_slots = 1
	output_inventory.slot_capacity = 20
	add_child(output_inventory)
	
	super._ready()
	
	# Auto-select first recipe for now (simple implementation)
	if not recipes.is_empty():
		current_recipe = recipes[0]

func _process(delta: float) -> void:
	if not is_active: return
	
	_handle_crafting(delta)
	_try_output_item()

func _handle_crafting(delta: float) -> void:
	if not current_recipe: return
	
	if is_crafting:
		craft_timer += delta
		if craft_timer >= current_recipe.craft_time:
			complete_craft()
	else:
		# Check if we can start crafting
		var has_input = input_inventory.remove_item(current_recipe.input_item, current_recipe.input_count)
		if has_input:
			# Check if output has space
			if output_inventory.has_space_for(current_recipe.output_item):
				is_crafting = true
				craft_timer = 0.0
			else:
				# Refund input if output is full
				input_inventory.add_item(current_recipe.input_item, current_recipe.input_count)

func complete_craft() -> void:
	is_crafting = false
	craft_timer = 0.0
	output_inventory.add_item(current_recipe.output_item, current_recipe.output_count)

func _try_output_item():
	if not output_inventory.has_item(): return
	
	var neighbor = get_neighbor(output_direction)
	if neighbor and neighbor.has_method("receive_item"):
		var item = output_inventory.get_first_item()
		if item:
			if neighbor.receive_item(item):
				output_inventory.remove_item(item, 1)

# Accept input items if they match the current recipe
func receive_item(item: ItemResource) -> bool:
	if current_recipe and item == current_recipe.input_item:
		return input_inventory.add_item(item) == 0
	return false