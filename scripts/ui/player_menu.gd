class_name PlayerMenu
extends PanelContainer

## The unified UI for Player Inventory and Creative Menu.

var tabs: TabContainer
var mode_button: Button
var player_grid: GridContainer
var items_grid: GridContainer
var buildings_grid: GridContainer
var crafting_grid: GridContainer 

# --- Details Panel Elements ---
var details_panel: PanelContainer
var details_content: VBoxContainer
var details_title: Label
var details_icon: TextureRect
var details_ingredients_grid: GridContainer
var craft_button: Button
var craft_progress: ProgressBar
var selected_recipe: RecipeResource = null

var all_items: Array[ItemResource] = []
var all_buildings: Array[BuildableResource] = []
var basic_recipes: Array[RecipeResource] = [] # Cache

# --- Custom Button for Tooltips ---
class CraftingButton extends Button:
	var recipe: RecipeResource
	
	func _make_custom_tooltip(_for_text: String) -> Object:
		var panel = PanelContainer.new()
		var vbox = VBoxContainer.new()
		panel.add_child(vbox)
		
		# Spacing
		vbox.add_theme_constant_override("separation", 8)
		
		var label = Label.new()
		label.text = "Requires:"
		vbox.add_child(label)
		
		if not recipe.inputs.is_empty():
			var grid = GridContainer.new()
			grid.columns = 4
			vbox.add_child(grid)
			
			for entry in recipe.inputs:
				var res = entry.resource
				var count = entry.count
				
				var icon = TextureRect.new()
				if res.get("icon"): icon.texture = res.icon
				if res.get("color"): icon.modulate = res.color
				icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon.custom_minimum_size = Vector2(24, 24)
				
				var lbl = Label.new()
				lbl.text = str(count)
				
				grid.add_child(icon)
				grid.add_child(lbl)
			
		return panel

func _ready() -> void:
	_build_ui_structure()
	_load_resources()
	
	mode_button.pressed.connect(_on_mode_toggle)
	PlayerManager.mode_changed.connect(_on_mode_changed)
	PlayerManager.player_inventory.inventory_changed.connect(_update_player_inventory)
	PlayerManager.player_inventory.inventory_changed.connect(_update_crafting_ui)
	
	# Connect to Player Crafter
	if PlayerManager.crafter:
		PlayerManager.crafter.progress_changed.connect(_on_craft_progress)
		PlayerManager.crafter.craft_started.connect(_on_craft_state_changed)
		PlayerManager.crafter.craft_finished.connect(_on_craft_state_changed)
	
	# Initialize state
	_on_mode_changed(PlayerManager.is_creative_mode)
	_update_player_inventory()

func _build_ui_structure() -> void:
	# Main Layout Split
	var main_hbox = HBoxContainer.new()
	main_hbox.name = "MainLayout"
	add_child(main_hbox)
	
	# --- Left Side (Grids) ---
	var left_vbox = VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hbox.add_child(left_vbox)
	
	# Header
	var header = HBoxContainer.new()
	header.name = "Header"
	left_vbox.add_child(header)
	
	var title = Label.new()
	title.text = "Inventory"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	
	mode_button = Button.new()
	mode_button.name = "ModeButton"
	mode_button.text = "Mode: Normal"
	header.add_child(mode_button)
	
	# Tabs
	tabs = TabContainer.new()
	tabs.name = "TabContainer"
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(tabs)
	
	# -- Crafting Tab
	var craft_tab = _create_grid_tab("Crafting")
	tabs.add_child(craft_tab)
	crafting_grid = craft_tab.get_node("Scroll/Grid")
	
	# -- Buildings Tab
	var build_tab = _create_grid_tab("Buildings")
	tabs.add_child(build_tab)
	buildings_grid = build_tab.get_node("Scroll/Grid")
	
	# -- Items Tab
	var item_tab = _create_grid_tab("Items")
	tabs.add_child(item_tab)
	items_grid = item_tab.get_node("Scroll/Grid")
	
	# Player Inventory
	var p_inv = PanelContainer.new()
	p_inv.name = "PlayerInv"
	p_inv.custom_minimum_size = Vector2(0, 200)
	left_vbox.add_child(p_inv)
	
	var scroll = ScrollContainer.new()
	scroll.name = "Scroll"
	p_inv.add_child(scroll)
	
	player_grid = GridContainer.new()
	player_grid.name = "Grid"
	player_grid.columns = 10
	player_grid.add_theme_constant_override("h_separation", 4)
	player_grid.add_theme_constant_override("v_separation", 4)
	scroll.add_child(player_grid)
	
	# --- Right Side (Details Panel) ---
	details_panel = PanelContainer.new()
	details_panel.custom_minimum_size = Vector2(200, 0)
	details_panel.visible = false
	main_hbox.add_child(details_panel)
	
	details_content = VBoxContainer.new()
	details_panel.add_child(details_content)
	
	# Title
	details_title = Label.new()
	details_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	details_title.autowrap_mode = TextServer.AUTOWRAP_WORD
	details_content.add_child(details_title)
	
	# Large Icon
	details_icon = TextureRect.new()
	details_icon.custom_minimum_size = Vector2(64, 64)
	details_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	details_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	details_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	details_content.add_child(details_icon)
	
	var div = HSeparator.new()
	details_content.add_child(div)
	
	var req_lbl = Label.new()
	req_lbl.text = "Required Materials:"
	details_content.add_child(req_lbl)
	
	# Ingredients Grid
	details_ingredients_grid = GridContainer.new()
	details_ingredients_grid.columns = 3
	details_content.add_child(details_ingredients_grid)
	
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details_content.add_child(spacer)
	
	# Progress Bar
	craft_progress = ProgressBar.new()
	craft_progress.custom_minimum_size = Vector2(0, 20)
	craft_progress.show_percentage = false
	craft_progress.visible = false
	details_content.add_child(craft_progress)
	
	craft_button = Button.new()
	craft_button.text = "Craft"
	craft_button.custom_minimum_size = Vector2(0, 40)
	craft_button.pressed.connect(_on_craft_button_pressed)
	details_content.add_child(craft_button)

func _create_grid_tab(name: String) -> Control:
	var c = MarginContainer.new()
	c.name = name
	var scroll = ScrollContainer.new()
	scroll.name = "Scroll"
	c.add_child(scroll)
	var grid = GridContainer.new()
	grid.name = "Grid"
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	scroll.add_child(grid)
	return c

func _load_resources() -> void:
	# Load Items
	var item_dir = DirAccess.open("res://resources/items/")
	if item_dir:
		item_dir.list_dir_begin()
		var f = item_dir.get_next()
		while f != "":
			if f.ends_with(".tres"):
				var r = load("res://resources/items/" + f)
				if r is ItemResource: all_items.append(r)
			f = item_dir.get_next()
	
	# Load Buildables
	var build_dir = DirAccess.open("res://resources/buildables/")
	if build_dir:
		build_dir.list_dir_begin()
		var f = build_dir.get_next()
		while f != "":
			if f.ends_with(".tres"):
				var r = load("res://resources/buildables/" + f)
				if r is BuildableResource: all_buildings.append(r)
			f = build_dir.get_next()
	
	# Load Basic Recipes
	if GameManager.has_method("get_available_recipes"):
		for r in GameManager.get_available_recipes():
			if r.category == "basic":
				basic_recipes.append(r)

func _on_mode_toggle() -> void:
	PlayerManager.is_creative_mode = !PlayerManager.is_creative_mode

func _on_mode_changed(creative: bool) -> void:
	mode_button.text = "Mode: Creative" if creative else "Mode: Normal"
	
	var t_build = tabs.get_node("Buildings")
	var t_item = tabs.get_node("Items")
	var t_craft = tabs.get_node("Crafting")
	
	if creative:
		details_panel.visible = false
		selected_recipe = null
		
		t_build.visible = true
		t_item.visible = true
		t_craft.visible = false
		
		_populate_creative_grids()
		if tabs.current_tab == t_craft.get_index():
			tabs.current_tab = t_build.get_index()
	else:
		_clear_grid(items_grid)
		_clear_grid(buildings_grid)
		
		t_craft.visible = true
		_populate_crafting_grid()
		
		tabs.current_tab = t_craft.get_index()
		t_build.visible = false
		t_item.visible = false

func _populate_creative_grids() -> void:
	_clear_grid(items_grid)
	_clear_grid(buildings_grid)
	for item in all_items:
		items_grid.add_child(_create_item_button(item, true))
	for build in all_buildings:
		buildings_grid.add_child(_create_item_button(build, true))

func _populate_crafting_grid() -> void:
	_clear_grid(crafting_grid)
	for recipe in basic_recipes:
		var btn = _create_crafting_button(recipe)
		crafting_grid.add_child(btn)

func _create_crafting_button(recipe: RecipeResource) -> Button:
	var btn = CraftingButton.new()
	btn.recipe = recipe
	btn.custom_minimum_size = Vector2(64, 64)
	btn.expand_icon = true
	var out_res: Resource = recipe.get_main_output()
	if out_res:
		if out_res is ItemResource: 
			btn.icon = out_res.icon
			if out_res.get("color"): btn.modulate = out_res.color
		elif out_res is BuildableResource:
			btn.icon = out_res.icon
	
	btn.tooltip_text = "Recipe" 
	btn.pressed.connect(func(): _select_recipe(recipe))
	return btn

func _select_recipe(recipe: RecipeResource) -> void:
	selected_recipe = recipe
	details_panel.visible = true
	
	# Update Title & Icon
	var out_res: Resource = recipe.get_main_output()
	if out_res:
		if out_res is ItemResource:
			details_title.text = out_res.item_name
			details_icon.texture = out_res.icon
			if out_res.get("color"): details_icon.modulate = out_res.color
		elif out_res is BuildableResource:
			details_title.text = out_res.buildable_name
			details_icon.texture = out_res.icon
			details_icon.modulate = Color.WHITE
	
	# Update Ingredients Grid
	for c in details_ingredients_grid.get_children(): c.queue_free()
	
	if not recipe.inputs.is_empty():
		for entry in recipe.inputs:
			var container = VBoxContainer.new()
			
			var icon = TextureRect.new()
			var in_res = entry.resource
			var count = entry.count
			
			if in_res.get("icon"): icon.texture = in_res.icon
			if in_res.get("color"): icon.modulate = in_res.color
			else: icon.modulate = Color.WHITE
				
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.custom_minimum_size = Vector2(40, 40)
			
			var lbl = Label.new()
			lbl.text = "x%d" % count
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			
			container.add_child(icon)
			container.add_child(lbl)
			
			var n = ""
			if "item_name" in in_res: n = in_res.item_name
			elif "buildable_name" in in_res: n = in_res.buildable_name
			container.tooltip_text = n
			
			details_ingredients_grid.add_child(container)

	_update_crafting_ui()

func _on_craft_button_pressed() -> void:
	if selected_recipe:
		_craft_item(selected_recipe)

func _craft_item(recipe: RecipeResource) -> void:
	PlayerManager.request_craft(recipe)
	_update_crafting_ui()

func _on_craft_progress(percent: float) -> void:
	craft_progress.value = percent * 100.0

func _on_craft_state_changed(_recipe) -> void:
	_update_crafting_ui()

func _update_crafting_ui(_arg=null) -> void:
	if PlayerManager.is_creative_mode: return
	
	if selected_recipe:
		var inv = PlayerManager.player_inventory
		var can_afford = inv.has_ingredients_for(selected_recipe)
		var is_busy = false
		if PlayerManager.crafter: is_busy = PlayerManager.crafter.is_busy()
		
		if is_busy:
			craft_button.disabled = true
			craft_button.text = "Crafting..."
			craft_progress.visible = true
		else:
			craft_button.disabled = not can_afford
			craft_button.text = "Craft" if can_afford else "Missing Items"
			craft_progress.visible = false

func _update_player_inventory() -> void:
	_clear_grid(player_grid)
	var slots = PlayerManager.player_inventory.slots
	for i in range(slots.size()):
		var slot_data = slots[i]
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(50, 50)
		btn.expand_icon = true
		
		var prefix = ""
		if i < 10: prefix = "[Hotbar %d] " % ((i + 1) % 10)
		
		if slot_data:
			var res = slot_data.item
			var count = slot_data.count
			var icon = null
			var col = Color.WHITE
			var name_str = ""
			
			if res is ItemResource:
				icon = res.icon; col = res.color; name_str = res.item_name
			elif res is BuildableResource:
				icon = res.icon; name_str = res.buildable_name
			
			btn.icon = icon
			btn.modulate = col
			btn.tooltip_text = "%s%s (%d)" % [prefix, name_str, count]
			
			var lbl = Label.new()
			lbl.text = str(count)
			lbl.add_theme_color_override("font_outline_color", Color.BLACK)
			lbl.add_theme_constant_override("outline_size", 4)
			lbl.anchors_preset = Control.PRESET_BOTTOM_RIGHT
			lbl.position = Vector2(-4, -2)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			btn.add_child(lbl)
			
			# Combine Drag and Drop into ONE call to prevent overwriting
			btn.set_drag_forwarding(
				Callable(self, "_get_drag_data_move").bind(i), 
				Callable(self, "_can_drop"), 
				Callable(self, "_drop_on_slot").bind(i)
			)
		else:
			btn.tooltip_text = "%sEmpty" % prefix
			# Drop only (no drag from empty)
			btn.set_drag_forwarding(
				Callable(), 
				Callable(self, "_can_drop"), 
				Callable(self, "_drop_on_slot").bind(i)
			)
		
		player_grid.add_child(btn)

func _create_item_button(res: Resource, is_creative_source: bool) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(50, 50)
	btn.expand_icon = true
	if res.get("icon"): btn.icon = res.icon
	if res.get("color"): btn.modulate = res.color
	var n = res.get("item_name") if "item_name" in res else res.get("buildable_name")
	btn.tooltip_text = n
	if is_creative_source:
		btn.set_drag_forwarding(Callable(self, "_get_drag_data_create").bind(res), Callable(), Callable())
	return btn

func _clear_grid(grid: Container) -> void:
	for c in grid.get_children(): c.queue_free()

# --- Drag & Drop ---

func _get_drag_data_create(_pos, res: Resource) -> Variant:
	_set_preview(res)
	return { "type": "creative_spawn", "resource": res }

func _get_drag_data_move(_pos, slot_idx: int) -> Variant:
	var slot = PlayerManager.player_inventory.slots[slot_idx]
	if not slot: return null
	_set_preview(slot.item)
	return { "type": "inventory_drag", "inventory": PlayerManager.player_inventory, "slot_index": slot_idx, "item": slot.item, "count": slot.count }

func _set_preview(res):
	var tr = TextureRect.new()
	tr.texture = res.icon if res.get("icon") else null
	tr.size = Vector2(40, 40)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	set_drag_preview(tr)

func _can_drop(_pos, data) -> bool:
	if typeof(data) != TYPE_DICTIONARY: return false
	return data.get("type") in ["creative_spawn", "inventory_drag"]

func _drop_on_slot(_pos, data, to_index: int) -> void:
	var target_inv = PlayerManager.player_inventory
	var type = data.type
	
	if type == "creative_spawn":
		var res = data.resource
		var stack = 64
		if res is ItemResource: stack = res.stack_size
		target_inv.slots[to_index] = { "item": res, "count": stack }
		target_inv.inventory_changed.emit()
		
	elif type == "inventory_drag":
		var source_inv = data.inventory
		var source_idx = data.slot_index
		var item = data.item
		var count = data.count
		
		if not source_inv.slots[source_idx]: return

		var target_slot = target_inv.slots[to_index]
		
		if source_inv == target_inv:
			# Internal Swap/Stack
			if target_slot == null:
				target_inv.slots[to_index] = target_inv.slots[source_idx]
				target_inv.slots[source_idx] = null
			elif target_inv._items_match(target_slot.item, item):
				var cap = target_inv._get_stack_limit(target_slot.item)
				var space = cap - target_slot.count
				var to_move = min(space, count)
				target_slot.count += to_move
				target_inv.slots[source_idx].count -= to_move
				if target_inv.slots[source_idx].count <= 0:
					target_inv.slots[source_idx] = null
			else:
				var temp = target_inv.slots[to_index]
				target_inv.slots[to_index] = target_inv.slots[source_idx]
				target_inv.slots[source_idx] = temp
			target_inv.inventory_changed.emit()
			
		else:
			# External Transfer
			if target_slot == null:
				target_inv.slots[to_index] = { "item": item, "count": count }
				source_inv.slots[source_idx] = null
			elif target_inv._items_match(target_slot.item, item):
				var cap = target_inv._get_stack_limit(target_slot.item)
				var space = cap - target_slot.count
				var to_move = min(space, count)
				target_slot.count += to_move
				
				source_inv.slots[source_idx].count -= to_move
				if source_inv.slots[source_idx].count <= 0:
					source_inv.slots[source_idx] = null
			else:
				# Swap if source accepts target item
				var t_item = target_slot.item
				if source_inv.is_item_allowed(t_item):
					var t_count = target_slot.count
					target_inv.slots[to_index] = { "item": item, "count": count }
					source_inv.slots[source_idx] = { "item": t_item, "count": t_count }
				else:
					return # Blocked
			
			target_inv.inventory_changed.emit()
			source_inv.inventory_changed.emit()
