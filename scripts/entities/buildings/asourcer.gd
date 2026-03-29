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
	
	var out_res = current_recipe.outputs[0].resource if current_recipe.outputs.size() > 0 else null
	if out_res and not output_inventory.has_space_for(out_res): return
		
	var in_res = current_recipe.inputs[0].resource if current_recipe.inputs.size() > 0 else null
	var in_count = current_recipe.inputs[0].count if current_recipe.inputs.size() > 0 else 1
	
	var has_ingredients = false
	var slot = input_inventory.slots[0] if input_inventory.slots.size() > 0 else null
	
	if slot != null and slot.item == in_res:
		if slot.count >= in_count:
			has_ingredients = true
	
	if has_ingredients:
		if input_inventory.remove_item(in_res, in_count):
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
		print("Asourcer: Clearing inventory for new recipe.")
		input_inventory.slots.fill(null)
		input_inventory.emit_signal("inventory_changed")
	
	current_recipe = recipe
	if crafter: crafter.stop_craft()
	
	if current_recipe:
		print("Asourcer: Recipe set to %s" % current_recipe.recipe_name)
		var in_res = current_recipe.inputs[0].resource if current_recipe.inputs.size() > 0 else null
		var in_count = current_recipe.inputs[0].count if current_recipe.inputs.size() > 0 else 1
		
		var item_stack_size = 50
		if in_res and "stack_size" in in_res:
			item_stack_size = in_res.stack_size
		
		var slots_needed = 1
		if item_stack_size > 0:
			slots_needed = ceil(float(in_count) / float(item_stack_size))
		
		input_inventory.max_slots = int(max(1, slots_needed))
		input_inventory.slots.resize(input_inventory.max_slots)
		for i in range(input_inventory.max_slots):
			input_inventory.slots[i] = null
			
		if in_res:
			input_inventory.allowed_items = [in_res]
		else:
			input_inventory.allowed_items =[]
	
	emit_signal("recipe_changed")

func clear_recipe() -> void:
	current_recipe = null
	if crafter: crafter.stop_craft()
	input_inventory.max_slots = 0
	input_inventory.allowed_items =[]
	input_inventory.slots.resize(0)
	print("Asourcer: Recipe cleared.")
	emit_signal("recipe_changed")

func receive_item(item: Resource, _from_node: Node3D = null, _extra_data: Dictionary = {}) -> bool:
	if not has_input or not current_recipe: return false
	var in_res = current_recipe.inputs[0].resource if current_recipe.inputs.size() > 0 else null
	
	if item != in_res:
		if in_res and item.resource_path != in_res.resource_path:
			return false
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
		printerr("Asourcer: GameManager not found.")
		return[]
	
	var filtered: Array[RecipeResource] =[]
	var current_wave = GameManager.game_data.get("wave", 1)
	for r in all_recipes:
		if r.category == "assembly" and r.tier <= current_wave:
			filtered.append(r)
	
	print("Asourcer: Found %d valid recipes (assembly) out of %d total." %[filtered.size(), all_recipes.size()])
	return filtered
