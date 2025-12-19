extends PanelContainer

@onready var close_button: Button = $VBoxContainer/Header/CloseButton
@onready var title_label: Label = $VBoxContainer/Header/Title

# Standard Slot Display (For generic single-slot items)
@onready var item_panel: Panel = $VBoxContainer/Content/ItemPanel 
@onready var item_icon: TextureRect = $VBoxContainer/Content/ItemPanel/ItemIcon
@onready var count_label: Label = $VBoxContainer/Content/ItemPanel/CountLabel

# Custom Status Display (For Burnace/Machines)
var machine_container: HBoxContainer
var input_slot: Panel
var input_icon: TextureRect
var input_count: Label
var arrow_icon: TextureRect
var output_slot: Panel
var output_icon: TextureRect
var output_count: Label

# Container for dynamically added recipe buttons
var recipe_container: GridContainer

var current_inventory: InventoryComponent
var current_context: Object = null # The building associated with the inventory

func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	
	var content = find_child("Content")
	if content:
		# Recipe Container
		recipe_container = GridContainer.new()
		recipe_container.columns = 4
		recipe_container.add_theme_constant_override("h_separation", 4)
		recipe_container.add_theme_constant_override("v_separation", 4)
		content.add_child(recipe_container)
		
		# Machine UI Container (Furnace Style)
		machine_container = HBoxContainer.new()
		machine_container.visible = false
		machine_container.alignment = BoxContainer.ALIGNMENT_CENTER
		machine_container.add_theme_constant_override("separation", 10)
		content.add_child(machine_container)
		
		# Input Slot
		input_slot = _create_slot_panel()
		machine_container.add_child(input_slot)
		input_icon = input_slot.get_node("Icon")
		input_count = input_slot.get_node("Count")
		
		# Arrow Progress
		arrow_icon = TextureRect.new()
		arrow_icon.custom_minimum_size = Vector2(32, 32)
		arrow_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		arrow_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		arrow_icon.texture = preload("res://assets/ui/arrowright.png") # Fallback
		arrow_icon.modulate = Color(0.8, 0.8, 0.8)
		machine_container.add_child(arrow_icon)
		
		# Output Slot
		output_slot = _create_slot_panel()
		machine_container.add_child(output_slot)
		output_icon = output_slot.get_node("Icon")
		output_count = output_slot.get_node("Count")

func _create_slot_panel() -> Panel:
	var p = Panel.new()
	p.custom_minimum_size = Vector2(48, 48)
	
	var icon = TextureRect.new()
	icon.name = "Icon"
	icon.layout_mode = 1
	icon.anchors_preset = Control.PRESET_FULL_RECT
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.offset_left = 4; icon.offset_top = 4; icon.offset_right = -4; icon.offset_bottom = -4
	p.add_child(icon)
	
	var lbl = Label.new()
	lbl.name = "Count"
	lbl.layout_mode = 1
	lbl.anchors_preset = Control.PRESET_BOTTOM_RIGHT
	lbl.position = Vector2(-4, -4)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	p.add_child(lbl)
	return p

func open(inventory: InventoryComponent, title: String = "Storage", context: Object = null) -> void:
	# Disconnect previous signals
	if current_inventory and current_inventory.is_connected("inventory_changed", _update_display):
		current_inventory.inventory_changed.disconnect(_update_display)
	
	if current_context:
		if "input_inventory" in current_context:
			var inv = current_context.input_inventory
			if inv and inv.is_connected("inventory_changed", _update_display):
				inv.inventory_changed.disconnect(_update_display)
		if "output_inventory" in current_context:
			var inv = current_context.output_inventory
			if inv and inv.is_connected("inventory_changed", _update_display):
				inv.inventory_changed.disconnect(_update_display)
	
	current_inventory = inventory
	current_context = context
	
	if title_label:
		title_label.text = title
	
	# Connect signals for Context (Machine) or Simple Inventory
	if current_context and current_context.has_method("get_processing_icon"):
		# It's a machine with multiple inventories usually
		if "input_inventory" in current_context:
			current_context.input_inventory.inventory_changed.connect(_update_display)
		if "output_inventory" in current_context:
			current_context.output_inventory.inventory_changed.connect(_update_display)
	elif current_inventory:
		# Simple inventory
		current_inventory.inventory_changed.connect(_update_display)
			
	_update_display()
	_update_recipes()
	show()

func _update_display() -> void:
	# Check if it's a machine
	if current_context and current_context.has_method("get_processing_icon"):
		item_panel.hide()
		machine_container.show()
		
		# Update Input Slot
		_update_slot_visuals(input_icon, input_count, current_context.get("input_inventory"))
		
		# Update Output Slot
		_update_slot_visuals(output_icon, output_count, current_context.get("output_inventory"))
		
		return

	# Fallback to standard generic display
	machine_container.hide()
	item_panel.show()
	
	if not current_inventory: 
		_clear_generic_display()
		return
	
	var slot = null
	if current_inventory.slots.size() > 0:
		slot = current_inventory.slots[0]
	
	if slot != null and slot.count > 0:
		item_icon.texture = slot.item.icon
		item_icon.modulate = slot.item.color
		count_label.text = str(slot.count)
		item_panel.tooltip_text = slot.item.item_name # Add tooltip
	else:
		_clear_generic_display()

func _update_slot_visuals(icon_rect: TextureRect, count_lbl: Label, inv: InventoryComponent) -> void:
	# Find parent panel for tooltip
	var panel = icon_rect.get_parent()
	
	if not inv:
		icon_rect.texture = null
		count_lbl.text = ""
		if panel: panel.tooltip_text = ""
		return
		
	var slot = null
	if inv.slots.size() > 0:
		slot = inv.slots[0] # Visualize first slot only for now
	
	if slot != null and slot.count > 0:
		icon_rect.texture = slot.item.icon
		icon_rect.modulate = slot.item.color
		count_lbl.text = str(slot.count)
		if panel: panel.tooltip_text = slot.item.item_name # Add tooltip
	else:
		icon_rect.texture = null
		count_lbl.text = ""
		if panel: panel.tooltip_text = "Empty"

func _clear_generic_display() -> void:
	item_icon.texture = null
	count_label.text = ""
	item_panel.tooltip_text = "Empty"

func _update_recipes() -> void:
	if not recipe_container: return
	
	# Clear existing buttons
	for child in recipe_container.get_children():
		child.queue_free()
		
	if not current_context: return
	
	# Check if context requires recipe selection
	if current_context.has_method("requires_recipe_selection"):
		if not current_context.requires_recipe_selection():
			return

	# Generate buttons
	var recipes = current_context.get("recipes")
	if recipes and recipes is Array:
		for recipe in recipes:
			if recipe is RecipeResource:
				var btn = Button.new()
				btn.icon = recipe.output_item.icon
				btn.modulate = recipe.output_item.color
				btn.custom_minimum_size = Vector2(40, 40)
				btn.expand_icon = true
				btn.tooltip_text = "Craft %s\nInput: %s x%d" % [recipe.output_item.item_name, recipe.input_item.item_name, recipe.input_count]
				btn.pressed.connect(_on_recipe_selected.bind(recipe))
				recipe_container.add_child(btn)

func _on_recipe_selected(recipe: RecipeResource) -> void:
	if current_context and current_context.has_method("set_recipe"):
		current_context.set_recipe(recipe)

func _on_close_pressed() -> void:
	close()

func close() -> void:
	hide()
	# Disconnect all signals
	if current_inventory and current_inventory.is_connected("inventory_changed", _update_display):
		current_inventory.inventory_changed.disconnect(_update_display)
			
	if current_context:
		if "input_inventory" in current_context:
			var inv = current_context.input_inventory
			if inv and inv.is_connected("inventory_changed", _update_display):
				inv.inventory_changed.disconnect(_update_display)
		if "output_inventory" in current_context:
			var inv = current_context.output_inventory
			if inv and inv.is_connected("inventory_changed", _update_display):
				inv.inventory_changed.disconnect(_update_display)

	current_inventory = null
	current_context = null
