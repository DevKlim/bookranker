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
var left_vbox: VBoxContainer
var right_vbox: VBoxContainer

var machine_container: VBoxContainer 
var status_hbox: HBoxContainer
var machine_progress: ProgressBar
var cancel_recipe_btn: Button

# Custom UI Container for Modding / Special Buildings
var custom_ui_container: VBoxContainer

# Recipe UI Elements
var recipe_scroll: ScrollContainer
var recipe_grid: HFlowContainer

# Ally/Generic Grid
var generic_grid: GridContainer

# Player Inventory Bottom Panel
var player_inv_container: VBoxContainer
var player_inv_grid: GridContainer

# Mod UI
var mod_lbl: Label
var mod_grid: GridContainer

# Building Stats UI
var b_stats_container: VBoxContainer
var b_stats_hp: Label
var b_stats_sec: Label
var b_stats_pwr: Label
var b_stats_eff: Label
var b_stats_def: Label
var b_stats_fw: Label
var b_stats_net: Label
var b_stats_comp: Label
var b_stats_luck: Label
var b_stats_spc: Label
var b_stats_ping: Label
var b_stats_mal: Label

var current_inventory: InventoryComponent
var current_context: Object = null 

var scale_root: Control
var base_min_size: Vector2 = Vector2(550, 400)

var content_bg_ref: PanelContainer
var _is_resizing: bool = false

# Dragging Variables
var dragging: bool = false
var drag_offset: Vector2

func _apply_liquid_glass(win: Control, corner_radius: float = 12.0) -> void:
	WindowUtils.apply_liquid_glass(win, corner_radius)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_KEEP_SIZE)
	size = base_min_size
	clip_contents = true
	
	if item_icon:
		item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		item_icon.texture_filter = Control.TEXTURE_FILTER_NEAREST
	
	_apply_liquid_glass(self, 12.0)
	
	var main_margin = MarginContainer.new()
	main_margin.add_theme_constant_override("margin_left", 4)
	main_margin.add_theme_constant_override("margin_top", -2)
	main_margin.add_theme_constant_override("margin_right", 4)
	main_margin.add_theme_constant_override("margin_bottom", 4)
	main_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(main_margin)

	var outer_vbox = VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 0)
	outer_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_margin.add_child(outer_vbox)

	var header = main_vbox.get_node_or_null("Header") as Control
	if header:
		main_vbox.remove_child(header)
		outer_vbox.add_child(header)
		header.custom_minimum_size = Vector2(0, 30)
		header.gui_input.connect(_on_header_gui_input)

	if title_label:
		title_label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
		title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		title_label.clip_text = true

	if close_button:
		# XP Close Button
		var c_style = StyleBoxEmpty.new()
		close_button.add_theme_stylebox_override("normal", c_style)
		var hc_style = StyleBoxFlat.new(); hc_style.bg_color = Color(1.0, 1.0, 1.0, 0.2)
		hc_style.corner_radius_top_left = 4; hc_style.corner_radius_top_right = 4
		hc_style.corner_radius_bottom_left = 4; hc_style.corner_radius_bottom_right = 4
		close_button.add_theme_stylebox_override("hover", hc_style)
		var pc_style = hc_style.duplicate(); pc_style.bg_color = Color(1.0, 1.0, 1.0, 0.4)
		close_button.add_theme_stylebox_override("pressed", pc_style)
		close_button.text = "X"
		close_button.add_theme_color_override("font_color", Color.BLACK)
		close_button.add_theme_color_override("font_hover_color", Color.WHITE)
		close_button.add_theme_color_override("font_pressed_color", Color.WHITE)
		close_button.custom_minimum_size = Vector2(24, 20)
		close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
		close_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if header: header.move_child(close_button, -1)
	
	close_button.pressed.connect(_on_close_pressed)
	
	var scale_wrapper = Control.new()
	scale_wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scale_wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scale_wrapper.clip_contents = true
	outer_vbox.add_child(scale_wrapper)

	scale_root = Control.new()
	scale_wrapper.add_child(scale_root)

	var frame_margin = MarginContainer.new()
	frame_margin.name = "FrameMargin"
	frame_margin.add_theme_constant_override("margin_left", 0)
	frame_margin.add_theme_constant_override("margin_right", 0)
	frame_margin.add_theme_constant_override("margin_bottom", 0)
	frame_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scale_root.add_child(frame_margin)
	
	var content_bg = PanelContainer.new()
	content_bg_ref = content_bg
	content_bg.name = "ContentBG"
	var cbg_style = StyleBoxFlat.new()
	cbg_style.bg_color = Color.WHITE
	cbg_style.corner_radius_bottom_left = 6
	cbg_style.corner_radius_bottom_right = 6
	cbg_style.corner_radius_top_left = 6
	cbg_style.corner_radius_top_right = 6
	content_bg.add_theme_stylebox_override("panel", cbg_style)
	content_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame_margin.add_child(content_bg)
	
	content_bg.set_drag_forwarding(Callable(), Callable(UIHelper, "can_drop_trash"), Callable(UIHelper, "drop_trash"))
	
	var layout_vbox = VBoxContainer.new()
	layout_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_bg.add_child(layout_vbox)

	recipe_scroll = ScrollContainer.new()
	recipe_scroll.name = "RecipeScroll"
	recipe_scroll.custom_minimum_size = Vector2(0, 200) 
	recipe_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	recipe_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recipe_scroll.visible = false
	layout_vbox.add_child(recipe_scroll)
	
	var margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 20)
	recipe_scroll.add_child(margin)
	
	recipe_grid = HFlowContainer.new()
	recipe_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recipe_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	recipe_grid.add_theme_constant_override("h_separation", 12)
	recipe_grid.add_theme_constant_override("v_separation", 12)
	margin.add_child(recipe_grid)
	
	content_container.custom_minimum_size = Vector2(0, 0)
	var content_margin = MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", 20)
	content_margin.add_theme_constant_override("margin_right", 20)
	content_margin.add_theme_constant_override("margin_bottom", 10)
	content_margin.add_theme_constant_override("margin_top", 10)
	content_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	for child in content_container.get_children():
		content_container.remove_child(child)
		content_margin.add_child(child)
	content_container.add_child(content_margin)
	
	content_container.get_parent().remove_child(content_container)
	layout_vbox.add_child(content_container)
	
	var split = HBoxContainer.new()
	split.add_theme_constant_override("separation", 40)
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_margin.add_child(split)
	
	left_vbox = VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(left_vbox)
	
	right_vbox = VBoxContainer.new()
	right_vbox.custom_minimum_size = Vector2(420, 0)
	split.add_child(right_vbox)
	
	# Mount Custom UI Container here
	custom_ui_container = VBoxContainer.new()
	custom_ui_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	custom_ui_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_ui_container.visible = false
	left_vbox.add_child(custom_ui_container)
	
	machine_container = VBoxContainer.new()
	machine_container.visible = false
	machine_container.alignment = BoxContainer.ALIGNMENT_CENTER
	machine_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(machine_container)
	
	status_hbox = HBoxContainer.new()
	status_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	status_hbox.add_theme_constant_override("separation", 15)
	machine_container.add_child(status_hbox)
	
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 15)
	machine_container.add_child(spacer)
	
	machine_progress = ProgressBar.new()
	machine_progress.custom_minimum_size = Vector2(200, 15)
	machine_progress.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	machine_progress.show_percentage = false
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.2, 0.2, 0.2, 0.1)
	sb.border_width_left = 1; sb.border_width_top = 1; sb.border_width_right = 1; sb.border_width_bottom = 1
	sb.border_color = Color(0, 0, 0, 0.2)
	sb.corner_radius_top_left = 6; sb.corner_radius_top_right = 6; sb.corner_radius_bottom_left = 6; sb.corner_radius_bottom_right = 6
	machine_progress.add_theme_stylebox_override("background", sb)
	var sbf = StyleBoxFlat.new()
	sbf.bg_color = Color(0.2, 0.8, 0.2)
	sbf.corner_radius_top_left = 6; sbf.corner_radius_top_right = 6; sbf.corner_radius_bottom_left = 6; sbf.corner_radius_bottom_right = 6
	machine_progress.add_theme_stylebox_override("fill", sbf)
	machine_container.add_child(machine_progress)
	
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 10)
	machine_container.add_child(spacer2)
	
	cancel_recipe_btn = Button.new()
	cancel_recipe_btn.text = "Change Recipe"
	cancel_recipe_btn.custom_minimum_size = Vector2(140, 40)
	cancel_recipe_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cancel_recipe_btn.add_theme_color_override("font_color", Color.BLACK)
	cancel_recipe_btn.pressed.connect(_on_cancel_recipe)
	machine_container.add_child(cancel_recipe_btn)

	generic_grid = GridContainer.new()
	generic_grid.columns = 5
	generic_grid.add_theme_constant_override("h_separation", 6)
	generic_grid.add_theme_constant_override("v_separation", 6)
	generic_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	generic_grid.visible = false
	left_vbox.add_child(generic_grid)

	mod_lbl = Label.new()
	mod_lbl.text = "Mod Slots"
	mod_lbl.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2)) 
	right_vbox.add_child(mod_lbl)
	
	mod_grid = GridContainer.new()
	mod_grid.columns = 3
	mod_grid.add_theme_constant_override("h_separation", 6)
	mod_grid.add_theme_constant_override("v_separation", 6)
	right_vbox.add_child(mod_grid)

	b_stats_container = VBoxContainer.new()
	b_stats_container.visible = false
	b_stats_container.add_theme_constant_override("separation", 2)
	b_stats_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(b_stats_container)
	
	var b_stats_title = Label.new()
	b_stats_title.text = "Building Stats"
	b_stats_title.add_theme_font_size_override("font_size", 16)
	b_stats_title.add_theme_color_override("font_color", Color.BLACK)
	b_stats_container.add_child(b_stats_title)
	
	var stats_grid = GridContainer.new()
	stats_grid.columns = 2
	stats_grid.add_theme_constant_override("h_separation", 10)
	stats_grid.add_theme_constant_override("v_separation", 4)
	b_stats_container.add_child(stats_grid)

	var _add_stat_lbl = func(color: Color) -> Label:
		var l = Label.new()
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", color)
		stats_grid.add_child(l)
		return l

	b_stats_hp = _add_stat_lbl.call(Color(0.7, 0.0, 0.0))
	b_stats_sec = _add_stat_lbl.call(Color(0.2, 0.6, 1.0))
	b_stats_pwr = _add_stat_lbl.call(Color(0.6, 0.6, 0.0))
	b_stats_eff = _add_stat_lbl.call(Color(0.0, 0.6, 0.0))
	b_stats_def = _add_stat_lbl.call(Color(0.5, 0.5, 0.5))
	b_stats_fw = _add_stat_lbl.call(Color(0.0, 0.7, 0.7))
	b_stats_net = _add_stat_lbl.call(Color(0.7, 0.0, 0.7))
	b_stats_comp = _add_stat_lbl.call(Color(0.7, 0.7, 0.0))
	b_stats_luck = _add_stat_lbl.call(Color(0.0, 0.8, 0.0))
	b_stats_spc = _add_stat_lbl.call(Color(0.4, 0.4, 0.4))
	b_stats_ping = _add_stat_lbl.call(Color(0.1, 0.8, 0.8))
	b_stats_mal = _add_stat_lbl.call(Color(0.8, 0.1, 0.1))

	# Configure permanent player inventory section below
	var sep_bottom = HSeparator.new()
	layout_vbox.add_child(sep_bottom)

	player_inv_container = VBoxContainer.new()
	var pmargin = MarginContainer.new()
	pmargin.add_theme_constant_override("margin_left", 20); pmargin.add_theme_constant_override("margin_right", 20)
	pmargin.add_theme_constant_override("margin_bottom", 20)
	pmargin.add_child(player_inv_container)
	layout_vbox.add_child(pmargin)

	var p_lbl = Label.new()
	p_lbl.text = "Player Inventory"
	p_lbl.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
	player_inv_container.add_child(p_lbl)

	var p_scroll = ScrollContainer.new()
	p_scroll.custom_minimum_size = Vector2(0, 150)
	player_inv_container.add_child(p_scroll)

	player_inv_grid = GridContainer.new()
	player_inv_grid.columns = 10
	player_inv_grid.add_theme_constant_override("h_separation", 4)
	player_inv_grid.add_theme_constant_override("v_separation", 4)
	p_scroll.add_child(player_inv_grid)

	main_vbox.queue_free()
	_setup_window_resizing(self, scale_wrapper, scale_root, frame_margin)
	
	if PlayerManager.game_inventory:
		PlayerManager.game_inventory.inventory_changed.connect(_update_player_inventory)

func _setup_window_resizing(win: Control, scale_wrapper: Control, scale_root: Control, content_node: Control) -> void:
	WindowUtils.setup_window_resizing(win, scale_wrapper, scale_root, content_node, base_min_size)

func _on_header_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = true
				drag_offset = event.global_position - global_position
			else:
				dragging = false
	elif event is InputEventMouseMotion and dragging:
		global_position = event.global_position - drag_offset

func _create_slot_panel() -> Panel:
	var p = Panel.new()
	p.custom_minimum_size = Vector2(64, 64)
	var center = CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(center)
	
	var icon = TextureRect.new()
	icon.name = "Icon"
	icon.custom_minimum_size = Vector2(64, 64)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = Control.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(icon)
	
	var lbl = Label.new()
	lbl.name = "Count"
	lbl.layout_mode = 1
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	lbl.offset_right = -4
	lbl.offset_bottom = -2
	var font = load("res://assets/fonts/v2-fs-tahoma-8px.otf")
	if font:
		lbl.add_theme_font_override("font", font)
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 4)
	p.add_child(lbl)
	return p

func _create_grid_slot_btn(inv: InventoryComponent, idx: int) -> Button:
	var btn = UIHelper.create_slot_btn_base()
	btn.set_script(preload("res://scripts/ui/slot_button.gd"))
	UIHelper.fill_slot_btn(btn, inv.slots[idx])
	
	if inv.slots[idx] == null:
		btn.text = "MOD"
		btn.add_theme_font_size_override("font_size", 24)
		btn.modulate = Color(1, 1, 1, 0.5)
	else:
		btn.set_meta("tooltip_res", inv.slots[idx].item)
		btn.tooltip_text = " "
		
	btn.gui_input.connect(func(event: InputEvent):
		if event.is_action_pressed("build_copy") and PlayerManager.is_creative_mode:
			if inv.slots[idx]:
				var drag_data = _get_slot_drag_data(Vector2.ZERO, {"inv": inv, "slot": idx}, btn)
				if drag_data:
					btn.force_drag(drag_data, WindowUtils.create_drag_preview(drag_data.item.icon))
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and not PlayerManager.is_creative_mode:
			if inv.slots[idx] and inv.slots[idx].item and inv.slots[idx].item.get("artifact_script"):
				var artifact = inv.slots[idx].item.get_artifact_instance()
				if artifact and artifact.has_method("on_right_click"):
					artifact.on_right_click(inv.slots[idx].item, self)
	)
		
	btn.pressed.connect(func():
		if Input.is_key_pressed(KEY_SHIFT):
			UIHelper.handle_shift_click(inv, idx)
	)
		
	btn.set_drag_forwarding(
		Callable(self, "_get_slot_drag_data").bind({"inv": inv, "slot": idx}, btn), 
		Callable(self, "_custom_can_drop_building").bind(inv), 
		Callable(self, "_custom_drop").bind(inv, idx)
	)
	return btn

# --- Drag & Drop Implementation ---

func _custom_can_drop_building(pos, data, inv) -> bool:
	if typeof(data) == TYPE_DICTIONARY and data.get("type") == "creative_copy": return true
	return UIHelper.can_drop_building(pos, data, inv)
	
func _custom_drop(pos, data, inv, idx) -> void:
	if typeof(data) == TYPE_DICTIONARY and data.get("type") == "creative_copy":
		var existing = inv.slots[idx]
		if not existing:
			inv.slots[idx] = {"item": data.item, "count": data.count}
			inv.inventory_changed.emit()
		elif existing.item == data.item:
			var space = existing.item.stack_size - existing.count
			var add = min(space, data.count)
			existing.count += add
			inv.inventory_changed.emit()
		else:
			inv.slots[idx] = {"item": data.item, "count": data.count}
			inv.inventory_changed.emit()
		return
	UIHelper.drop_inv(pos, data, inv, idx)

func _get_slot_drag_data(_pos, data_ctx, btn: Control):
	var inv = data_ctx.inv
	var slot_idx = data_ctx.slot
	if not inv or slot_idx >= inv.slots.size() or inv.slots[slot_idx] == null:
		return null
	
	var item = inv.slots[slot_idx].item
	var count = inv.slots[slot_idx].count
	
	btn.set_drag_preview(WindowUtils.create_drag_preview(item.icon))

	if PlayerManager.is_creative_mode and Input.is_action_pressed("build_copy"):
		var stack = 64
		if item is ItemResource: stack = item.stack_size
		return { "type": "creative_copy", "item": item, "count": stack }
	
	return { 
		"type": "inventory_drag", 
		"inventory": inv, 
		"slot_index": slot_idx, 
		"item": item, 
		"count": count 
	}

func _on_slot_panel_gui_input(event: InputEvent, inv: Node, idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and Input.is_key_pressed(KEY_SHIFT):
		UIHelper.handle_shift_click(inv, idx)

# ----------------------------------

func open(inventory: InventoryComponent, title: String = "Storage", context: Object = null) -> void:
	if current_inventory and current_inventory.is_connected("inventory_changed", _update_display):
		current_inventory.inventory_changed.disconnect(_update_display)
	_disconnect_context_signals()
	
	current_inventory = inventory
	current_context = context
	
	if title_label: title_label.text = "  " + title
	
	if current_context:
		if current_context.has_signal("recipe_changed"):
			if not current_context.recipe_changed.is_connected(_update_display):
				current_context.recipe_changed.connect(_update_display)
		if current_context.has_signal("stats_updated"):
			if not current_context.stats_updated.is_connected(_update_display):
				current_context.stats_updated.connect(_update_display)
		if current_context.get("crafter"):
			if not current_context.crafter.progress_changed.is_connected(_update_machine_progress):
				current_context.crafter.progress_changed.connect(_update_machine_progress)
		for inv_name in["input_inventory", "output_inventory", "fuel_inventory", "mod_inventory"]:
			var inv = current_context.get(inv_name)
			if inv and not inv.inventory_changed.is_connected(_update_display):
				inv.inventory_changed.connect(_update_display)

	if current_inventory:
		if not current_inventory.inventory_changed.is_connected(_update_display):
			current_inventory.inventory_changed.connect(_update_display)
			
	# Reset size to base_min_size to allow shrinking on every new menu open
	size = base_min_size
	if machine_progress: machine_progress.value = 0.0
	
	_update_display()
	_update_player_inventory()
	
	if not visible:
		var vp_size = get_viewport_rect().size
		position = (vp_size - size) / 2.0
		
	show()
	call_deferred("emit_signal", "resized")

func _disconnect_context_signals():
	if current_context:
		if current_context.has_signal("recipe_changed"):
			if current_context.recipe_changed.is_connected(_update_display):
				current_context.recipe_changed.disconnect(_update_display)
		if current_context.has_signal("stats_updated"):
			if current_context.stats_updated.is_connected(_update_display):
				current_context.stats_updated.disconnect(_update_display)
		if current_context.get("crafter"):
			if current_context.crafter.progress_changed.is_connected(_update_machine_progress):
				current_context.crafter.progress_changed.disconnect(_update_machine_progress)
		for inv_name in["input_inventory", "output_inventory", "fuel_inventory", "mod_inventory"]:
			var inv = current_context.get(inv_name)
			if inv and inv.is_connected("inventory_changed", _update_display):
				inv.inventory_changed.disconnect(_update_display)

func _update_machine_progress(percent: float) -> void:
	if machine_progress:
		machine_progress.value = percent * 100.0

func _update_player_inventory() -> void:
	if not player_inv_grid: return
	for child in player_inv_grid.get_children():
		child.queue_free()
		
	if not PlayerManager.game_inventory: return
	var slots = PlayerManager.game_inventory.slots
	for i in range(slots.size()):
		var btn = UIHelper.create_slot_btn_base()
		btn.set_script(preload("res://scripts/ui/slot_button.gd"))
		UIHelper.fill_slot_btn(btn, slots[i])
		
		btn.gui_input.connect(func(event: InputEvent):
			if event.is_action_pressed("build_copy") and PlayerManager.is_creative_mode:
				var slot = slots[i]
				if slot:
					var drag_data = { "type": "creative_copy", "item": slot.item, "count": slot.item.stack_size }
					btn.force_drag(drag_data, WindowUtils.create_drag_preview(slot.item.icon))
			elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and not PlayerManager.is_creative_mode:
				if slots[i] and slots[i].item and slots[i].item.get("artifact_script"):
					var artifact = slots[i].item.get_artifact_instance()
					if artifact and artifact.has_method("on_right_click"):
						artifact.on_right_click(slots[i].item, self)
		)
		
		if slots[i]:
			btn.set_meta("tooltip_res", slots[i].item)
			btn.tooltip_text = " "
			btn.pressed.connect(func():
				if Input.is_key_pressed(KEY_SHIFT):
					UIHelper.handle_shift_click(PlayerManager.game_inventory, i)
			)
			btn.set_drag_forwarding(Callable(self, "_get_slot_drag_data").bind({"inv": PlayerManager.game_inventory, "slot": i}, btn), Callable(self, "_custom_can_drop_building").bind(PlayerManager.game_inventory), Callable(self, "_custom_drop").bind(PlayerManager.game_inventory, i))
		else:
			btn.set_drag_forwarding(Callable(), Callable(self, "_custom_can_drop_building").bind(PlayerManager.game_inventory), Callable(self, "_custom_drop").bind(PlayerManager.game_inventory, i))
		player_inv_grid.add_child(btn)

func _recursive_override_size(node: Node, size: Vector2) -> void:
	if node is Control:
		if node is TextureRect or node is CenterContainer or node is Panel:
			node.custom_minimum_size = size
	for child in node.get_children():
		_recursive_override_size(child, size)

func _update_display(_arg = null) -> void:
	if is_instance_valid(custom_ui_container):
		for child in custom_ui_container.get_children():
			child.queue_free()

	var has_custom_ui = false
	if current_context and current_context.has_method("build_custom_ui"):
		has_custom_ui = true
		current_context.build_custom_ui(custom_ui_container)
		custom_ui_container.show()
	else:
		custom_ui_container.hide()

	if current_context and "mod_inventory" in current_context and current_context.mod_inventory:
		mod_lbl.show()
		mod_grid.show()
		right_vbox.show()
		
		for child in mod_grid.get_children(): child.queue_free()
		var m_inv = current_context.mod_inventory
		if m_inv.slots.size() == 0: mod_lbl.text = "No Mods"
		else: mod_lbl.text = "Mod Slots"
		for i in range(m_inv.slots.size()):
			var btn = _create_grid_slot_btn(m_inv, i)
			btn.custom_minimum_size = Vector2(128, 128)
			_recursive_override_size(btn, Vector2(128, 128))
			
			if not m_inv.slots[i]:
				var tooltip = "Mod Slot " + str(i+1)
				btn.tooltip_text = tooltip
			mod_grid.add_child(btn)
			
		if current_context.has_method("get_stat") or current_context.get("health_component"):
			b_stats_container.show()
			var hp = 0; var mhp = 0; var sec = 0; var msec = 0; var pwr = 0; var eff = 1.0; var def = 0; var fw = 0; var net = 0; var comp = 1; var luck = 0; var spc = 10; var ping_val = 1; var mal = 0
			
			if current_context.get("health_component"):
				hp = current_context.health_component.current_health
				mhp = current_context.health_component.max_health
				sec = current_context.health_component.current_security
				msec = current_context.health_component.max_security
			if current_context.get("power_consumer"):
				pwr = current_context.power_consumer.power_consumption
			if current_context.has_method("get_stat"):
				eff = current_context.get_stat("process_speed", current_context.get("process_speed") if current_context.get("process_speed") != null else 1.0)
				def = current_context.get_stat("defense", 0.0)
				fw = current_context.get_stat("firewall", 0.0)
				net = current_context.get_stat("networking", 0.0)
				comp = current_context.get_stat("compute", 1.0)
				luck = current_context.get_stat("luck_stat", 0.0)
				spc = current_context.get_stat("space", 10.0)
				ping_val = current_context.get_stat("ping", 1.0)
				mal = current_context.get_stat("malware", 0.0)
			
			b_stats_hp.text = "HP: %d / %d" %[int(hp), int(mhp)]
			b_stats_sec.text = "Sec: %d / %d" %[int(sec), int(msec)]
			b_stats_pwr.text = "Pwr: %d W" % int(pwr)
			b_stats_eff.text = "Spd: %.1fx" % eff
			b_stats_def.text = "Def: %d" % int(def)
			b_stats_fw.text = "FW: %.1f" % fw
			b_stats_net.text = "Net: %.1f" % net
			b_stats_comp.text = "Comp: %.1f" % comp
			b_stats_luck.text = "Luck: %.1f" % luck
			b_stats_spc.text = "Spc: %.1f" % spc
			b_stats_ping.text = "Ping: %.1f" % ping_val
			b_stats_mal.text = "Mal: %.1f" % mal
		else:
			b_stats_container.hide()
	else:
		right_vbox.hide()
		mod_lbl.hide()
		mod_grid.hide()
		if b_stats_container: b_stats_container.hide()

	if has_custom_ui:
		item_panel.hide()
		generic_grid.hide()
		machine_container.hide()
		recipe_scroll.hide()
		content_container.show()
		if title_label:
			var clean_name = "Custom Interface"
			if "display_name" in current_context and current_context.display_name != "": clean_name = current_context.display_name
			elif "name" in current_context: clean_name = current_context.name.rstrip("0123456789")
			title_label.text = "  " + clean_name
		_check_and_apply_resize()
		return

	if current_context and current_context.has_method("get_processing_icon"):
		item_panel.hide()
		generic_grid.hide()
		var needs_selection = false
		if current_context.has_method("requires_recipe_selection"):
			needs_selection = current_context.requires_recipe_selection()
		
		var has_recipe = false
		if "current_recipe" in current_context: has_recipe = (current_context.current_recipe != null)
		
		if needs_selection and not has_recipe:
			content_container.hide()
			recipe_scroll.show()
			_populate_recipe_grid()
			if title_label: title_label.text = "  Select Recipe"
		else:
			recipe_scroll.hide()
			content_container.show()
			machine_container.show()
			
			var recipe = current_context.get("current_recipe")
			if not recipe and "active_recipe" in current_context: recipe = current_context.active_recipe
			
			if recipe and machine_progress:
				machine_progress.show()
			elif machine_progress:
				machine_progress.hide()
			
			var clean_name = "Machine"
			if "display_name" in current_context and current_context.display_name != "":
				clean_name = current_context.display_name
			elif "name" in current_context:
				clean_name = current_context.name.rstrip("0123456789")
			if title_label: title_label.text = "  " + clean_name
			
			cancel_recipe_btn.visible = current_context.has_method("clear_recipe")

			for child in status_hbox.get_children():
				child.queue_free()
				
			var input_inv = current_context.get("input_inventory")
			if not input_inv and current_context.get("inventory_component"):
				input_inv = current_context.get("inventory_component")
				
			if recipe and recipe.inputs.size() > 0:
				for i in range(recipe.inputs.size()):
					var slot = _create_slot_panel()
					status_hbox.add_child(slot)
					var icon = slot.get_node("Center/Icon")
					var count_lbl = slot.get_node("Count")
					_update_machine_io_multi(slot, icon, count_lbl, input_inv, recipe, true, i)
			else:
				var slot = _create_slot_panel()
				status_hbox.add_child(slot)
				var icon = slot.get_node("Center/Icon")
				var count_lbl = slot.get_node("Count")
				_update_machine_io_multi(slot, icon, count_lbl, input_inv, recipe, true, 0)

			var fuel_inv = current_context.get("fuel_inventory")
			if fuel_inv:
				var f_slot = _create_slot_panel()
				f_slot.modulate = Color(0.8, 0.7, 0.6)
				status_hbox.add_child(f_slot)
				var f_icon = f_slot.get_node("Center/Icon")
				_update_machine_io_multi(f_slot, f_icon, null, fuel_inv, null, true, 0)

			var arrow = TextureRect.new()
			arrow.custom_minimum_size = Vector2(32, 32)
			arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			arrow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			var grad = Gradient.new()
			grad.colors =[Color.WHITE, Color.WHITE]
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
				arrow.texture = grad_tex
				arrow.modulate = Color(0.6, 0.6, 0.6)
			status_hbox.add_child(arrow)

			var output_inv = current_context.get("output_inventory")
			if not output_inv and current_context.get("inventory_component"):
				output_inv = current_context.get("inventory_component")
				
			if recipe and recipe.outputs.size() > 0:
				for i in range(recipe.outputs.size()):
					var out_slot = _create_slot_panel()
					status_hbox.add_child(out_slot)
					var out_icon = out_slot.get_node("Center/Icon")
					var out_count = out_slot.get_node("Count")
					_update_machine_io_multi(out_slot, out_icon, out_count, output_inv, recipe, false, i)
			else:
				var out_slot = _create_slot_panel()
				status_hbox.add_child(out_slot)
				var out_icon = out_slot.get_node("Center/Icon")
				var out_count = out_slot.get_node("Count")
				_update_machine_io_multi(out_slot, out_icon, out_count, output_inv, recipe, false, 0)
				
		_check_and_apply_resize()
		return

	machine_container.hide()
	recipe_scroll.hide()
	content_container.show()
	item_panel.hide()
	
	if not current_inventory: 
		generic_grid.hide()
		_check_and_apply_resize()
		return

	var is_core = (current_context and current_context.is_in_group("core"))
	if is_core or (current_context and current_inventory == current_context.get("mod_inventory")):
		generic_grid.hide()
	else:
		generic_grid.show()
		for child in generic_grid.get_children():
			child.queue_free()
		
		var is_ally = (current_context and current_context.is_in_group("allies"))
		
		for i in range(current_inventory.slots.size()):
			var slot_data = current_inventory.slots[i]
			var btn = Button.new()
			btn.custom_minimum_size = Vector2(64, 64)
			btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			btn.set_script(preload("res://scripts/ui/slot_button.gd"))
			
			var center = CenterContainer.new()
			center.set_anchors_preset(Control.PRESET_FULL_RECT)
			center.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(center)
			
			var tr = TextureRect.new()
			tr.name = "ItemIcon"
			tr.custom_minimum_size = Vector2(64, 64)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.texture_filter = Control.TEXTURE_FILTER_NEAREST
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			center.add_child(tr)
			
			var slot_name = ""
			var tooltip = ""
			
			if is_ally:
				match i:
					0: 
						btn.modulate = Color(1.0, 0.8, 0.8) # Tool
						tooltip = "[Tool] "
					1: 
						btn.modulate = Color(0.8, 1.0, 0.8) # Weapon
						tooltip = "[Weapon] "
					2: 
						btn.modulate = Color(0.8, 0.8, 1.0) # Armor
						tooltip = "[Armor] "
					3: 
						btn.modulate = Color(1.0, 1.0, 0.8) # Artifact
						tooltip = "[Artifact] "
			else:
				if current_context and current_context.has_method("get_slot_tooltip"):
					tooltip = current_context.get_slot_tooltip(i) + "\n"
				if current_context and current_context.has_method("get_slot_label"):
					slot_name = current_context.get_slot_label(i)
					
			if slot_name != "":
				var title_lbl = Label.new()
				title_lbl.text = slot_name
				title_lbl.set_anchors_preset(Control.PRESET_TOP_LEFT)
				title_lbl.offset_left = 4
				title_lbl.offset_top = 2
				var font = load("res://assets/fonts/v2-fs-tahoma-8px.otf")
				if font: title_lbl.add_theme_font_override("font", font)
				title_lbl.add_theme_font_size_override("font_size", 14)
				title_lbl.add_theme_color_override("font_color", Color.WHITE)
				title_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
				title_lbl.add_theme_constant_override("outline_size", 4)
				title_lbl.z_index = 5
				btn.add_child(title_lbl)
			
			if slot_data:
				var item = slot_data.item
				tr.texture = item.icon
				
				btn.set_meta("tooltip_res", item)
				btn.tooltip_text = " "
				
				var lbl = Label.new()
				lbl.text = str(slot_data.count)
				lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				lbl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
				lbl.offset_right = -4
				lbl.offset_bottom = -2
				var font = load("res://assets/fonts/v2-fs-tahoma-8px.otf")
				if font:
					lbl.add_theme_font_override("font", font)
				lbl.add_theme_font_size_override("font_size", 16)
				lbl.add_theme_color_override("font_outline_color", Color.BLACK)
				lbl.add_theme_constant_override("outline_size", 4)
				btn.add_child(lbl)
			else:
				if is_ally:
					match i:
						0: btn.text = "TL"
						1: btn.text = "WP"
						2: btn.text = "AR"
						3: btn.text = "AT"
				btn.tooltip_text = tooltip + "Empty"
			
			btn.gui_input.connect(func(event: InputEvent):
				if event.is_action_pressed("build_copy") and PlayerManager.is_creative_mode:
					if current_inventory.slots[i]:
						var drag_data = _get_slot_drag_data(Vector2.ZERO, {"inv": current_inventory, "slot": i}, btn)
						if drag_data:
							btn.force_drag(drag_data, WindowUtils.create_drag_preview(drag_data.item.icon))
				elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and not PlayerManager.is_creative_mode:
					if slot_data and slot_data.item and slot_data.item.get("artifact_script"):
						var artifact = slot_data.item.get_artifact_instance()
						if artifact and artifact.has_method("on_right_click"):
							artifact.on_right_click(slot_data.item, self)
			)
			
			btn.pressed.connect(func():
				if Input.is_key_pressed(KEY_SHIFT):
					UIHelper.handle_shift_click(current_inventory, i)
			)
			
			btn.set_drag_forwarding(
				Callable(self, "_get_slot_drag_data").bind({"inv": current_inventory, "slot": i}, btn), 
				Callable(self, "_custom_can_drop_building").bind(current_inventory), 
				Callable(self, "_custom_drop").bind(current_inventory, i)
			)
			
			generic_grid.add_child(btn)
			
	_check_and_apply_resize()

func _update_machine_io_multi(panel: Panel, icon_rect: TextureRect, count_lbl: Label, inv: Node, recipe: Resource, is_input: bool, input_idx: int) -> void:
	panel.set_script(preload("res://scripts/ui/slot_panel.gd"))
	
	var target_icon = null
	var target_color = Color.WHITE
	var required_amount = 0
	var item_name = "Empty"
	var target_item = null
	
	if recipe:
		if is_input:
			if recipe.inputs.size() > input_idx:
				var entry = recipe.inputs[input_idx]
				target_item = entry.resource
				target_icon = entry.resource.icon
				required_amount = entry.count
				if "item_name" in entry.resource: item_name = entry.resource.item_name
				elif "buildable_name" in entry.resource: item_name = entry.resource.buildable_name
		else:
			if recipe.outputs.size() > input_idx:
				var entry = recipe.outputs[input_idx]
				target_item = entry.resource
				target_icon = entry.resource.icon
				required_amount = entry.count
				if "item_name" in entry.resource: item_name = entry.resource.item_name
				elif "buildable_name" in entry.resource: item_name = entry.resource.buildable_name
				
	var current_amount = 0
	if inv and target_item:
		for slot in inv.slots:
			if slot and slot.item == target_item:
				current_amount += slot.count
	elif inv and inv.slots.size() > input_idx and inv.slots[input_idx] and not recipe:
		current_amount = inv.slots[input_idx].count
		target_icon = inv.slots[input_idx].item.icon
		if "item_name" in inv.slots[input_idx].item: item_name = inv.slots[input_idx].item.item_name
	
	if panel and inv:
		var bound_slot = 0
		if inv.slots.size() > input_idx: bound_slot = input_idx
		
		if not panel.gui_input.is_connected(_on_slot_panel_gui_input):
			panel.gui_input.connect(_on_slot_panel_gui_input.bind(inv, bound_slot))
			
		panel.gui_input.connect(func(event: InputEvent):
			if event.is_action_pressed("build_copy") and PlayerManager.is_creative_mode:
				if inv.slots.size() > bound_slot and inv.slots[bound_slot]:
					var drag_data = _get_slot_drag_data(Vector2.ZERO, {"inv": inv, "slot": bound_slot}, panel)
					if drag_data:
						panel.force_drag(drag_data, WindowUtils.create_drag_preview(drag_data.item.icon))
			elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and not PlayerManager.is_creative_mode:
				if inv.slots.size() > bound_slot and inv.slots[bound_slot] and inv.slots[bound_slot].item and inv.slots[bound_slot].item.get("artifact_script"):
					var artifact = inv.slots[bound_slot].item.get_artifact_instance()
					if artifact and artifact.has_method("on_right_click"):
						artifact.on_right_click(inv.slots[bound_slot].item, self)
		)
			
		panel.set_drag_forwarding(
			Callable(self, "_get_slot_drag_data").bind({"inv": inv, "slot": bound_slot}, panel), 
			Callable(self, "_custom_can_drop_building").bind(inv), 
			Callable(self, "_custom_drop").bind(inv, bound_slot)
		)
	elif panel:
		panel.set_drag_forwarding(Callable(), Callable(), Callable())
		
	if current_amount > 0 and (current_amount >= required_amount or not is_input):
		icon_rect.texture = target_icon
		icon_rect.modulate = Color.WHITE
		icon_rect.modulate.a = 1.0
	elif target_icon:
		icon_rect.texture = target_icon
		icon_rect.modulate = target_color
		icon_rect.modulate.a = 0.4
	else:
		icon_rect.texture = null
		icon_rect.modulate = Color.WHITE
	
	if count_lbl:
		if is_input and target_icon:
			count_lbl.text = "%d / %d" %[current_amount, required_amount]
		else:
			count_lbl.text = "" if current_amount == 0 else str(current_amount)
	
	if panel:
		if current_amount > 0 or (target_icon and is_input):
			if target_item:
				panel.set_meta("tooltip_res", target_item)
				panel.tooltip_text = " "
			elif inv and inv.slots.size() > input_idx and inv.slots[input_idx]:
				panel.set_meta("tooltip_res", inv.slots[input_idx].item)
				panel.tooltip_text = " "
		else:
			panel.set_meta("tooltip_res", null)
			panel.tooltip_text = item_name

func _populate_recipe_grid() -> void:
	for child in recipe_grid.get_children():
		child.queue_free()
	if not current_context: return
	var recipes =[]
	if current_context.has_method("get_recipes"): recipes = current_context.get_recipes()
	if recipes.is_empty():
		var lbl = Label.new()
		lbl.text = "No Recipes Found"
		lbl.add_theme_color_override("font_color", Color.BLACK)
		recipe_grid.add_child(lbl)
		return
	
	for recipe in recipes:
		if recipe is RecipeResource:
			var btn = Button.new()
			btn.custom_minimum_size = Vector2(64, 64)
			btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			
			var center = CenterContainer.new()
			center.set_anchors_preset(Control.PRESET_FULL_RECT)
			center.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(center)

			var tr = TextureRect.new()
			tr.custom_minimum_size = Vector2(64, 64)
			tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tr.texture_filter = Control.TEXTURE_FILTER_NEAREST
			tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			center.add_child(tr)
			
			var name_str = recipe.recipe_name
			var out = recipe.get_main_output()
			if out:
				if "item_name" in out: name_str = out.item_name
				elif "buildable_name" in out: name_str = out.buildable_name
			btn.tooltip_text = "%s\n(Tier %d)" %[name_str, recipe.tier]
			
			if out and out.icon:
				tr.texture = out.icon
			else:
				btn.text = name_str.left(4)
			
			btn.pressed.connect(_on_recipe_selected.bind(recipe))
			
			btn.set_drag_forwarding(
				Callable(),
				Callable(UIHelper, "can_drop_trash"),
				Callable(UIHelper, "drop_trash")
			)
			
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

func _check_and_apply_resize() -> void:
	if not is_inside_tree(): return
	if _is_resizing: return
	_is_resizing = true
	
	await get_tree().process_frame
	
	if is_instance_valid(content_bg_ref):
		var min_content = content_bg_ref.get_combined_minimum_size()
		var target_x = max(base_min_size.x, min_content.x + 20)
		var target_y = max(base_min_size.y, min_content.y + 60)
		
		# Always ensure we fit the content tightly if it exceeds base_min_size
		if size.x < target_x or size.y < target_y:
			size = Vector2(max(size.x, target_x), max(size.y, target_y))
			var vp_size = get_viewport_rect().size
			position = (vp_size - size) / 2.0
			emit_signal("resized")
			
	_is_resizing = false
