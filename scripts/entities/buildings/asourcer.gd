@tool
class_name Asourcer
extends BaseBuilding

signal recipe_changed

var current_recipe: RecipeResource = null

# Components
var input_inventory: InventoryComponent
var output_inventory: InventoryComponent
var crafter 

func _init() -> void:
	has_input = true
	has_output = true
	input_inventory = InventoryComponent.new()
	output_inventory = InventoryComponent.new()

func _ready() -> void:
	if not Engine.is_editor_hint():
		crafter = get_node_or_null("CrafterComponent")
		if not crafter:
			var script = load("res://scripts/components/crafter_component.gd")
			if script:
				crafter = script.new()
				crafter.name = "CrafterComponent"
				add_child(crafter)
		
		input_inventory.name = "InputInventory"
		input_inventory.max_slots = 0 
		input_inventory.slot_capacity = 20
		input_inventory.can_receive = true
		add_child(input_inventory)
		
		output_inventory.name = "OutputInventory"
		output_inventory.max_slots = 1
		output_inventory.slot_capacity = 50
		output_inventory.can_output = true
		add_child(output_inventory)
	
	super._ready()

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not is_active or not crafter: return
	
	if current_recipe and not crafter.is_busy():
		_try_start_craft()
	
	if crafter.update_process(delta):
		_complete_craft()
	
	if output_inventory.has_item():
		try_output_from_inventory(output_inventory)

func _try_start_craft() -> void:
	if not current_recipe: return
	if not output_inventory.has_space_for(current_recipe.output_item): return
		
	var has_ingredients = false
	var slot = input_inventory.slots[0] if input_inventory.slots.size() > 0 else null
	
	if slot != null and slot.item == current_recipe.input_item:
		if slot.count >= current_recipe.input_count:
			has_ingredients = true
	
	if has_ingredients:
		if input_inventory.remove_item(current_recipe.input_item, current_recipe.input_count):
			crafter.start_craft(current_recipe)

func _complete_craft() -> void:
	if current_recipe:
		output_inventory.add_item(current_recipe.output_item, current_recipe.output_count)
		crafter.stop_craft()

func set_recipe(recipe: RecipeResource) -> void:
	if current_recipe == recipe: return
	
	if input_inventory.has_item():
		print("Asourcer: Clearing inventory for new recipe.")
		input_inventory.slots.fill(null)
		input_inventory.emit_signal("inventory_changed")
	
	current_recipe = recipe
	if crafter: crafter.stop_craft()
	
	if current_recipe:
		print("Asourcer: Recipe set to %s" % current_recipe.recipe_name)
		var item_stack_size = 50
		if current_recipe.input_item:
			item_stack_size = current_recipe.input_item.stack_size
		
		var slots_needed = 1
		if item_stack_size > 0:
			slots_needed = ceil(float(current_recipe.input_count) / float(item_stack_size))
		
		input_inventory.max_slots = int(max(1, slots_needed))
		input_inventory.slots.resize(input_inventory.max_slots)
		for i in range(input_inventory.max_slots):
			input_inventory.slots[i] = null
		input_inventory.allowed_items = [current_recipe.input_item]
	
	emit_signal("recipe_changed")

func clear_recipe() -> void:
	current_recipe = null
	if crafter: crafter.stop_craft()
	input_inventory.max_slots = 0
	input_inventory.allowed_items = []
	input_inventory.slots.resize(0)
	print("Asourcer: Recipe cleared.")
	emit_signal("recipe_changed")

func receive_item(item: Resource, _from_node: Node3D = null, _extra_data: Dictionary = {}) -> bool:
	if not has_input or not current_recipe: return false
	if item != current_recipe.input_item:
		if item.resource_path != current_recipe.input_item.resource_path:
			return false
	if input_inventory.add_item(item) == 0:
		return true
	return false

func requires_recipe_selection() -> bool:
	return true

func get_processing_icon() -> Texture2D:
	if current_recipe and current_recipe.output_item:
		return current_recipe.output_item.icon
	return null

func get_recipes() -> Array[RecipeResource]:
	var all_recipes = []
	if GameManager.has_method("get_available_recipes"):
		all_recipes = GameManager.get_available_recipes()
	else:
		printerr("Asourcer: GameManager not found.")
		return []
	
	var filtered: Array[RecipeResource] = []
	for r in all_recipes:
		if r.category == "assembly":
			filtered.append(r)
	
	print("Asourcer: Found %d valid recipes (assembly) out of %d total." % [filtered.size(), all_recipes.size()])
	return filtered
