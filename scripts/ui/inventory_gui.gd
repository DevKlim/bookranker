extends PanelContainer

@onready var main_vbox: VBoxContainer = $VBoxContainer
@onready var close_button: Button = $VBoxContainer/Header/CloseButton
@onready var title_label: Label = $VBoxContainer/Header/Title

# Generic Display
@onready var content_container: Control = $VBoxContainer/Content
@onready var item_panel: Panel = $VBoxContainer/Content/ItemPanel 
@onready var item_icon: TextureRect = $VBoxContainer/Content/ItemPanel/ItemIcon
@onready var count_label: Label = $VBoxContainer/Content/ItemPanel/CountLabel

# Machine UI Elements
var machine_container: VBoxContainer 
var status_hbox: HBoxContainer
var input_slot: Panel
var input_icon: TextureRect
var input_count: Label
var fuel_slot: Panel 
var fuel_icon: TextureRect 
var output_slot: Panel
var output_icon: TextureRect
var output_count: Label
var cancel_recipe_btn: Button

# Recipe UI Elements
var recipe_scroll: ScrollContainer
var recipe_grid: HFlowContainer

var current_inventory: InventoryComponent
var current_context: Object = null 

func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	
	recipe_scroll = ScrollContainer.new()
	recipe_scroll.name = "RecipeScroll"
	recipe_scroll.custom_minimum_size = Vector2(0, 200) 
	recipe_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	recipe_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recipe_scroll.visible = false
	main_vbox.add_child(recipe_scroll)
	
	var margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	recipe_scroll.add_child(margin)
	
	recipe_grid = HFlowContainer.new()
	recipe_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recipe_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	recipe_grid.add_theme_constant_override("h_separation", 12)
	recipe_grid.add_theme_constant_override("v_separation", 12)
	margin.add_child(recipe_grid)
	
	machine_container = VBoxContainer.new()
	machine_container.visible = false
	machine_container.alignment = BoxContainer.ALIGNMENT_CENTER
	machine_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_container.add_child(machine_container)
	
	status_hbox = HBoxContainer.new()
	status_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	status_hbox.add_theme_constant_override("separation", 15)
	machine_container.add_child(status_hbox)
	
	input_slot = _create_slot_panel()
	status_hbox.add_child(input_slot)
	input_icon = input_slot.get_node("Icon")
	input_count = input_slot.get_node("Count")

	fuel_slot = _create_slot_panel()
	fuel_slot.modulate = Color(0.8, 0.7, 0.6)
	fuel_slot.visible = false
	status_hbox.add_child(fuel_slot)
	fuel_icon = fuel_slot.get_node("Icon")
	
	# Create a procedural arrow texture
	var arrow = TextureRect.new()
	arrow.custom_minimum_size = Vector2(32, 32)
	arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	arrow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	# Procedural Gradient Arrow (Right Facing)
	var grad = Gradient.new()
	grad.colors = [Color.WHITE, Color.WHITE]
	var grad_tex = GradientTexture2D.new()
	grad_tex.gradient = grad
	grad_tex.width = 32
	grad_tex.height = 32
	grad_tex.fill = GradientTexture2D.FILL_LINEAR
	grad_tex.fill_from = Vector2(0, 0)
	grad_tex.fill_to = Vector2(1, 0.5) 
	
	if ResourceLoader.exists("res://assets/ui/arrowright.png"):
		arrow.texture = load("res://assets/ui/arrowright.png")
	else:
		# Fallback: A simple rect, rotated to look dynamic
		arrow.texture = grad_tex
		arrow.modulate = Color(0.6, 0.6, 0.6)
	
	status_hbox.add_child(arrow)
	
	output_slot = _create_slot_panel()
	status_hbox.add_child(output_slot)
	output_icon = output_slot.get_node("Icon")
	output_count = output_slot.get_node("Count")
	
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 15)
	machine_container.add_child(spacer)
	
	cancel_recipe_btn = Button.new()
	cancel_recipe_btn.text = "Change Recipe"
	cancel_recipe_btn.custom_minimum_size = Vector2(140, 45)
	cancel_recipe_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cancel_recipe_btn.pressed.connect(_on_cancel_recipe)
	machine_container.add_child(cancel_recipe_btn)

func _create_slot_panel() -> Panel:
	var p = Panel.new()
	p.custom_minimum_size = Vector2(64, 64)
	var icon = TextureRect.new()
	icon.name = "Icon"
	icon.layout_mode = 1
	icon.anchors_preset = Control.PRESET_FULL_RECT
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.offset_left=6; icon.offset_top=6; icon.offset_right=-6; icon.offset_bottom=-6
	p.add_child(icon)
	var lbl = Label.new()
	lbl.name = "Count"
	lbl.layout_mode = 1
	lbl.anchors_preset = Control.PRESET_BOTTOM_RIGHT
	lbl.position = Vector2(-4, -2)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	p.add_child(lbl)
	return p

# --- Drag & Drop Implementation ---

func _get_slot_drag_data(_pos, data_ctx):
	var inv = data_ctx.inv
	var slot_idx = data_ctx.slot
	if not inv or slot_idx >= inv.slots.size() or inv.slots[slot_idx] == null:
		return null
	
	var item = inv.slots[slot_idx].item
	var count = inv.slots[slot_idx].count
	
	var preview = TextureRect.new()
	preview.texture = item.icon
	preview.size = Vector2(40,40)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.z_index = 100 # Ensure on top
	set_drag_preview(preview)
	
	return { 
		"type": "inventory_drag", 
		"inventory": inv, 
		"slot_index": slot_idx, 
		"item": item, 
		"count": count 
	}

# RENAMED to avoid virtual function conflict
func _on_slot_can_drop(_pos, data, target_inv: InventoryComponent) -> bool:
	if typeof(data) != TYPE_DICTIONARY or data.get("type") != "inventory_drag": 
		return false
	
	if not target_inv or not target_inv.can_receive: 
		return false
		
	if not target_inv.is_item_allowed(data.item):
		return false
		
	return true

# RENAMED to avoid virtual function conflict
func _on_slot_drop(_pos, data, target_inv: InventoryComponent, target_slot_idx: int) -> void:
	var source_inv = data.inventory
	var source_idx = data.slot_index
	var item = data.item
	var count = data.count
	
	if not is_instance_valid(source_inv) or source_idx >= source_inv.slots.size():
		return
	if source_inv.slots[source_idx] == null:
		return

	var remainder = target_inv.add_item(item, count)
	var taken = count - remainder
	
	if taken > 0:
		source_inv.remove_item(item, taken)

# ----------------------------------

func open(inventory: InventoryComponent, title: String = "Storage", context: Object = null) -> void:
	if current_inventory and current_inventory.is_connected("inventory_changed", _update_display):
		current_inventory.inventory_changed.disconnect(_update_display)
	_disconnect_context_signals()
	
	current_inventory = inventory
	current_context = context
	
	if title_label: title_label.text = title
	
	if current_context:
		if current_context.has_signal("recipe_changed"):
			if not current_context.recipe_changed.is_connected(_update_display):
				current_context.recipe_changed.connect(_update_display)
		for inv_name in ["input_inventory", "output_inventory", "fuel_inventory"]:
			var inv = current_context.get(inv_name)
			if inv and not inv.inventory_changed.is_connected(_update_display):
				inv.inventory_changed.connect(_update_display)

	if current_inventory:
		if not current_inventory.inventory_changed.is_connected(_update_display):
			current_inventory.inventory_changed.connect(_update_display)
			
	_update_display()
	show()

func _disconnect_context_signals():
	if current_context:
		if current_context.has_signal("recipe_changed"):
			if current_context.recipe_changed.is_connected(_update_display):
				current_context.recipe_changed.disconnect(_update_display)
		for inv_name in ["input_inventory", "output_inventory", "fuel_inventory"]:
			var inv = current_context.get(inv_name)
			if inv and inv.is_connected("inventory_changed", _update_display):
				inv.inventory_changed.disconnect(_update_display)

func _update_display(_arg = null) -> void:
	if current_context and current_context.has_method("get_processing_icon"):
		item_panel.hide()
		var needs_selection = false
		if current_context.has_method("requires_recipe_selection"):
			needs_selection = current_context.requires_recipe_selection()
		
		var has_recipe = false
		if "current_recipe" in current_context: has_recipe = (current_context.current_recipe != null)
		
		if needs_selection and not has_recipe:
			content_container.hide()
			recipe_scroll.show()
			_populate_recipe_grid()
			if title_label: title_label.text = "Select Recipe"
		else:
			recipe_scroll.hide()
			content_container.show()
			machine_container.show()
			
			var clean_name = "Machine"
			if "display_name" in current_context and current_context.display_name != "":
				clean_name = current_context.display_name
			elif "name" in current_context:
				clean_name = current_context.name.rstrip("0123456789")
			if title_label: title_label.text = clean_name
			
			cancel_recipe_btn.visible = current_context.has_method("clear_recipe")
			var recipe = current_context.get("current_recipe")
			if not recipe and "active_recipe" in current_context: recipe = current_context.active_recipe

			_update_machine_io(input_slot, input_icon, input_count, current_context.get("input_inventory"), recipe, true)
			_update_machine_io(output_slot, output_icon, output_count, current_context.get("output_inventory"), recipe, false)
			
			var fuel_inv = current_context.get("fuel_inventory")
			if fuel_inv:
				fuel_slot.visible = true
				_update_machine_io(fuel_slot, fuel_icon, null, fuel_inv, null, true)
			else:
				fuel_slot.visible = false
		return

	# Generic Display
	machine_container.hide()
	recipe_scroll.hide()
	content_container.show()
	item_panel.show()
	
	if not current_inventory: 
		_clear_generic_display()
		return
	
	# Enable Drag for Generic
	var slot = null
	if current_inventory.slots.size() > 0: slot = current_inventory.slots[0]
	
	if slot != null and slot.count > 0:
		item_icon.texture = slot.item.icon
		item_icon.modulate = slot.item.color
		count_label.text = str(slot.count)
		item_panel.tooltip_text = slot.item.item_name
	else:
		_clear_generic_display()

	# UPDATED: Use the renamed functions
	item_panel.set_drag_forwarding(
		Callable(self, "_get_slot_drag_data").bind({"inv": current_inventory, "slot": 0}), 
		Callable(self, "_on_slot_can_drop").bind(current_inventory), 
		Callable(self, "_on_slot_drop").bind(current_inventory, 0)
	)

func _update_machine_io(panel: Panel, icon_rect: TextureRect, count_lbl: Label, inv: InventoryComponent, recipe: RecipeResource, is_input: bool) -> void:
	var current_amount = 0
	if inv and inv.slots.size() > 0 and inv.slots[0] != null:
		current_amount = inv.slots[0].count
	
	# UPDATED: Use the renamed functions
	if panel and inv:
		panel.set_drag_forwarding(
			Callable(self, "_get_slot_drag_data").bind({"inv": inv, "slot": 0}), 
			Callable(self, "_on_slot_can_drop").bind(inv), 
			Callable(self, "_on_slot_drop").bind(inv, 0)
		)
	elif panel:
		panel.set_drag_forwarding(Callable(), Callable(), Callable())
	
	var target_icon = null
	var target_color = Color.WHITE
	var required_amount = 0
	var item_name = "Empty"
	
	if recipe:
		if is_input:
			if recipe.input_item:
				target_icon = recipe.input_item.icon
				target_color = recipe.input_item.color
				required_amount = recipe.input_count
				item_name = recipe.input_item.item_name
		else:
			if recipe.output_item:
				target_icon = recipe.output_item.icon
				target_color = recipe.output_item.color
				required_amount = recipe.output_count
				item_name = recipe.output_item.item_name
	
	if current_amount > 0 and inv.slots[0] != null:
		icon_rect.texture = inv.slots[0].item.icon
		icon_rect.modulate = inv.slots[0].item.color
		icon_rect.modulate.a = 1.0
	elif target_icon:
		icon_rect.texture = target_icon
		icon_rect.modulate = target_color
		icon_rect.modulate.a = 0.4
	else:
		icon_rect.texture = null
	
	if count_lbl:
		if is_input and target_icon:
			count_lbl.text = "%d / %d" % [current_amount, required_amount]
		else:
			count_lbl.text = "" if current_amount == 0 else str(current_amount)
	
	if panel: panel.tooltip_text = item_name

func _clear_generic_display() -> void:
	item_icon.texture = null
	count_label.text = ""
	item_panel.tooltip_text = "Empty"

func _populate_recipe_grid() -> void:
	for child in recipe_grid.get_children():
		child.queue_free()
	if not current_context: return
	var recipes = []
	if current_context.has_method("get_recipes"): recipes = current_context.get_recipes()
	if recipes.is_empty():
		var lbl = Label.new()
		lbl.text = "No Recipes Found"
		recipe_grid.add_child(lbl)
		return
	
	for recipe in recipes:
		if recipe is RecipeResource:
			var btn = Button.new()
			btn.custom_minimum_size = Vector2(80, 80)
			btn.expand_icon = true
			var name_str = recipe.recipe_name
			if recipe.output_item: name_str = recipe.output_item.item_name
			btn.tooltip_text = "%s\n(Tier %d)" % [name_str, recipe.tier]
			
			if recipe.output_item and recipe.output_item.icon:
				btn.icon = recipe.output_item.icon
				if recipe.output_item.color != Color.WHITE: btn.modulate = recipe.output_item.color
			else:
				btn.text = name_str.left(4)
			
			btn.pressed.connect(_on_recipe_selected.bind(recipe))
			recipe_grid.add_child(btn)

func _on_recipe_selected(recipe: RecipeResource) -> void:
	if current_context and current_context.has_method("set_recipe"):
		current_context.set_recipe(recipe)

func _on_cancel_recipe() -> void:
	if current_context and current_context.has_method("clear_recipe"):
		current_context.clear_recipe()

func _on_close_pressed() -> void:
	close()

func close() -> void:
	hide()
	if current_inventory and current_inventory.is_connected("inventory_changed", _update_display):
		current_inventory.inventory_changed.disconnect(_update_display)
	_disconnect_context_signals()
	current_inventory = null
	current_context = null
