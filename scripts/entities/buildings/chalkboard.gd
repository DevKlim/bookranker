@tool
class_name Chalkboard
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
	
	var out_res = current_recipe.outputs[0].resource if current_recipe.outputs.size() > 0 else null
	if out_res and not output_inventory.has_space_for(out_res): return
		
	var has_ingredients = true
	for input in current_recipe.inputs:
		if not input_inventory.has_item_count(input.resource, input.count):
			has_ingredients = false
			break
	
	if has_ingredients:
		for input in current_recipe.inputs:
			input_inventory.remove_item(input.resource, input.count)
		crafter.start_craft(current_recipe)

func _complete_craft() -> void:
	if current_recipe:
		var out_res = current_recipe.outputs[0].resource if current_recipe.outputs.size() > 0 else null
		var out_count = current_recipe.outputs[0].count if current_recipe.outputs.size() > 0 else 1
		if out_res:
			output_inventory.add_item(out_res, out_count)
		crafter.stop_craft()

func set_recipe(recipe: RecipeResource) -> void:
	if current_recipe == recipe: return
	
	if input_inventory.has_item():
		input_inventory.slots.fill(null)
		input_inventory.emit_signal("inventory_changed")
	
	current_recipe = recipe
	if crafter: crafter.stop_craft()
	
	if current_recipe:
		var num_inputs = current_recipe.inputs.size()
		input_inventory.max_slots = max(1, num_inputs)
		input_inventory.slots.resize(input_inventory.max_slots)
		for i in range(input_inventory.max_slots):
			input_inventory.slots[i] = null
			
		var allowed: Array[Resource] =[]
		for input in current_recipe.inputs:
			if input.resource:
				allowed.append(input.resource)
		input_inventory.allowed_items = allowed
		
		input_inventory.slot_filter = _strict_recipe_filter
	else:
		var empty_allowed: Array[Resource] =[]
		input_inventory.allowed_items = empty_allowed
		input_inventory.slot_filter = Callable()
	
	emit_signal("recipe_changed")

func _strict_recipe_filter(item: Resource, index: int) -> bool:
	if not current_recipe or index >= current_recipe.inputs.size(): return false
	return item == current_recipe.inputs[index].resource

func clear_recipe() -> void:
	current_recipe = null
	if crafter: crafter.stop_craft()
	input_inventory.max_slots = 0
	
	var empty_allowed: Array[Resource] =[]
	input_inventory.allowed_items = empty_allowed
	input_inventory.slot_filter = Callable()
	input_inventory.slots.resize(0)
	emit_signal("recipe_changed")

func receive_item(item: Resource, _from_node: Node3D = null, _extra_data: Dictionary = {}) -> bool:
	if not has_input or not current_recipe: return false
	
	if input_inventory.add_item(item) == 0:
		return true
	return false

func requires_recipe_selection() -> bool:
	return true

func get_processing_icon() -> Texture2D:
	if current_recipe:
		var out_res = current_recipe.outputs[0].resource if current_recipe.outputs.size() > 0 else null
		if out_res and "icon" in out_res:
			return out_res.icon
	return null

func get_recipes() -> Array[RecipeResource]:
	var all_recipes =[]
	if GameManager.has_method("get_available_recipes"):
		all_recipes = GameManager.get_available_recipes()
	else:
		return[]
	
	var filtered: Array[RecipeResource] =[]
	var current_wave = GameManager.game_data.get("wave", 1)
	for r in all_recipes:
		if r.category == "chalkboard":
			if r.tier <= current_wave:
				filtered.append(r)
	
	return filtered
