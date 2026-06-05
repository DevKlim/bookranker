@tool
class_name Chalkboard
extends BaseBuilding

signal recipe_changed

var current_recipe: RecipeResource = null
var crafter: CrafterComponent
var input_inventory: InventoryComponent
var output_inventory: InventoryComponent

func _init() -> void:
	has_input = true
	has_output = true
	default_input_mask = 15 # Accept inputs from all sides (e.g. from Slipstreams)

func _ready() -> void:
	if not Engine.is_editor_hint():
		crafter = get_node_or_null("CrafterComponent")
		if not crafter:
			var script = load("res://scripts/components/crafter_component.gd")
			if script:
				crafter = script.new()
				crafter.name = "CrafterComponent"
				add_child(crafter)
				
		# Removed: crafter.craft_finished.connect(_handle_craft_completion)
		# CrafterComponent natively calls parent._handle_craft_completion() automatically!
		
		input_inventory = get_node_or_null("InputInventory")
		if not input_inventory:
			input_inventory = InventoryComponent.new()
			input_inventory.name = "InputInventory"
			add_child(input_inventory)
			
		output_inventory = get_node_or_null("OutputInventory")
		if not output_inventory:
			output_inventory = InventoryComponent.new()
			output_inventory.name = "OutputInventory"
			add_child(output_inventory)
			
		clear_recipe() # Initialize completely blocked/empty until selection
	
	super._ready()

func _on_power_status_changed(has_power: bool) -> void:
	is_active = true
	set_process(is_active)
	set_physics_process(is_active)
	emit_signal("stats_updated")

func _has_ingredients() -> bool:
	if not current_recipe or not input_inventory or not output_inventory: return false
	
	# Check output space
	var out_res = current_recipe.outputs[0].resource if current_recipe.outputs.size() > 0 else null
	var out_count = current_recipe.outputs[0].count if current_recipe.outputs.size() > 0 else 1
	var out_slot = output_inventory.slots[0]
	
	if out_slot != null:
		if out_slot.item != out_res: return false
		if out_slot.count + out_count > output_inventory._get_stack_limit(out_res): return false
		
	# Check inputs available
	for i in range(current_recipe.inputs.size()):
		var req = current_recipe.inputs[i]
		var in_slot = input_inventory.slots[i]
		if not in_slot or in_slot.count < req.count:
			return false
			
	return true

func _consume_ingredients() -> void:
	if not current_recipe or not input_inventory: return
	for i in range(current_recipe.inputs.size()):
		var req = current_recipe.inputs[i]
		if input_inventory.slots[i]:
			input_inventory.slots[i].count -= req.count
			if input_inventory.slots[i].count <= 0:
				input_inventory.slots[i] = null
	input_inventory.emit_signal("inventory_changed")

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or not is_active or not crafter: return
	
	if current_recipe:
		if not crafter.is_busy():
			if _has_ingredients():
				crafter.start_craft(current_recipe)
		else:
			# Safety check: Cancel crafting if ingredients are manually removed mid-process
			if not _has_ingredients():
				crafter.stop_craft()
	
	if output_inventory and output_inventory.has_item():
		try_output_from_inventory(output_inventory)

func _handle_craft_completion(recipe: RecipeResource) -> void:
	if not recipe or not output_inventory: return
	
	# Consume items strictly when process has finished
	_consume_ingredients()
	
	var out_res = recipe.outputs[0].resource if recipe.outputs.size() > 0 else null
	var out_count = recipe.outputs[0].count if recipe.outputs.size() > 0 else 1
	
	var out_slot = output_inventory.slots[0]
	if out_slot == null:
		output_inventory.slots[0] = { "item": out_res, "count": out_count }
	else:
		out_slot.count += out_count
		
	output_inventory.emit_signal("inventory_changed")

func try_output_from_inventory(inv: InventoryComponent) -> bool:
	if not has_output or not current_recipe or is_in_group("loot_buildings"): return false
	
	var out_slot = inv.slots[0]
	if not out_slot or out_slot.count <= 0: return false
	
	var it = out_slot.item
	for i in range(4):
		if (output_mask & (1 << i)):
			var n = get_neighbor(i as Direction)
			if is_instance_valid(n) and n.has_method("receive_item"):
				if n.get("has_input") == false: continue
				
				if n.receive_item(it, self):
					out_slot.count -= 1
					if out_slot.count <= 0:
						inv.slots[0] = null
					inv.emit_signal("inventory_changed")
					return true
	return false

func set_recipe(recipe: RecipeResource) -> void:
	if current_recipe == recipe: return
	
	# Eject old inputs securely if applicable
	if input_inventory and input_inventory.has_item() and PlayerManager.game_inventory:
		var p_inv = PlayerManager.game_inventory
		var all_fit = true
		for slot in input_inventory.slots:
			if slot and slot.item:
				if not p_inv.has_space_for(slot.item):
					all_fit = false
					break
					
		if not all_fit:
			if get_tree().root.has_node("Main/GameUI"):
				get_tree().root.get_node("Main/GameUI").show_notification("Inventory Full! Clear space before swapping recipes.", Color(0.9, 0.2, 0.2))
			return
			
		for i in range(input_inventory.slots.size()):
			var slot = input_inventory.slots[i]
			if slot and slot.item:
				p_inv.add_item(slot.item, slot.count)
				input_inventory.slots[i] = null
		input_inventory.emit_signal("inventory_changed")
	
	current_recipe = recipe
	if crafter: crafter.stop_craft()
	
	if current_recipe:
		var num_inputs = current_recipe.inputs.size()
		input_inventory.max_slots = num_inputs
		input_inventory.slots.resize(input_inventory.max_slots)
		for i in range(input_inventory.max_slots):
			input_inventory.slots[i] = null
			
		output_inventory.max_slots = 1
		output_inventory.slots.resize(1)
		output_inventory.slots[0] = null
			
		var allowed_in: Array[Resource] =[]
		for input in current_recipe.inputs:
			if input.resource: allowed_in.append(input.resource)
			
		var allowed_out: Array[Resource] =[]
		if current_recipe.outputs.size() > 0: allowed_out.append(current_recipe.outputs[0].resource)
			
		input_inventory.allowed_items = allowed_in
		input_inventory.slot_filter = _strict_recipe_input_filter
		input_inventory.custom_filter = Callable()
		input_inventory.can_receive = true
		
		output_inventory.allowed_items = allowed_out
		output_inventory.can_receive = false # Explicitly prevent manual player inputs into output
	else:
		if input_inventory:
			input_inventory.allowed_items = []
			input_inventory.slot_filter = Callable()
			input_inventory.max_slots = 0
			input_inventory.slots.resize(0)
			input_inventory.can_receive = false
		if output_inventory:
			output_inventory.max_slots = 0
			output_inventory.slots.resize(0)
	
	emit_signal("recipe_changed")

func _strict_recipe_input_filter(item: Resource, index: int) -> bool:
	if item == null: return true
	if not current_recipe: return false
	if index < current_recipe.inputs.size():
		return item == current_recipe.inputs[index].resource
	return false

func clear_recipe() -> void:
	set_recipe(null)

func receive_item(item: Resource, _from_node: Node3D = null, _extra_data: Dictionary = {}) -> bool:
	if not has_input or not current_recipe or not input_inventory: return false
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
