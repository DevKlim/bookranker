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

# Ally/Generic Grid
var generic_grid: GridContainer

# Mod UI
var mod_lbl: Label
var mod_grid: GridContainer

# Building Stats UI
var b_stats_container: VBoxContainer
var b_stats_hp: Label
var b_stats_power: Label
var b_stats_eff: Label

var current_inventory: InventoryComponent
var current_context: Object = null 

var scale_root: Control
var base_min_size: Vector2 = Vector2(550, 400)

# Dragging Variables
var dragging: bool = false
var drag_offset: Vector2

func _apply_liquid_glass(win: Control, corner_radius: float = 12.0) -> void:
	win.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	
	var bbc = BackBufferCopy.new()
	bbc.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	win.add_child(bbc)
	win.move_child(bbc, 0)
	
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat = ShaderMaterial.new()
	var shader = load("res://shaders/liquid_glass.gdshader")
	if shader:
		mat.shader = shader
		mat.set_shader_parameter("tint", Color(0.9, 0.9, 0.9, 0.45))
		mat.set_shader_parameter("corner_radius", corner_radius)
		mat.set_shader_parameter("bezel_width", 8.0)
	bg.material = mat
	win.add_child(bg)
	win.move_child(bg, 1)
	
	win.resized.connect(func(): if mat.shader: mat.set_shader_parameter("rect_size", win.size))
	win.call_deferred("emit_signal", "resized")

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
		close_button.add_theme_color_override("font_color", Color.WHITE)
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
	
	content_bg.set_drag_forwarding(Callable(self, "_on_bg_get_drag_data"), Callable(self, "_on_bg_can_drop"), Callable(self, "_on_bg_drop"))
	
	recipe_scroll = ScrollContainer.new()
	recipe_scroll.name = "RecipeScroll"
	recipe_scroll.custom_minimum_size = Vector2(0, 200) 
	recipe_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	recipe_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recipe_scroll.visible = false
	content_bg.add_child(recipe_scroll)
	
	recipe_scroll.set_drag_forwarding(Callable(self, "_on_bg_get_drag_data"), Callable(self, "_on_bg_can_drop"), Callable(self, "_on_bg_drop"))
	
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
	content_margin.add_theme_constant_override("margin_bottom", 20)
	content_margin.add_theme_constant_override("margin_top", 10)
	content_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	for child in content_container.get_children():
		content_container.remove_child(child)
		content_margin.add_child(child)
	content_container.add_child(content_margin)
	
	content_container.get_parent().remove_child(content_container)
	content_bg.add_child(content_container)
	
	var split = HBoxContainer.new()
	split.add_theme_constant_override("separation", 40)
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_margin.add_child(split)
	
	left_vbox = VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(left_vbox)
	
	right_vbox = VBoxContainer.new()
	right_vbox.custom_minimum_size = Vector2(200, 0)
	split.add_child(right_vbox)
	
	machine_container = VBoxContainer.new()
	machine_container.visible = false
	machine_container.alignment = BoxContainer.ALIGNMENT_CENTER
	machine_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(machine_container)
	
	status_hbox = HBoxContainer.new()
	status_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	status_hbox.add_theme_constant_override("separation", 15)
	machine_container.add_child(status_hbox)
	
	input_slot = _create_slot_panel()
	status_hbox.add_child(input_slot)
	input_icon = input_slot.get_node("Center/Icon")
	input_count = input_slot.get_node("Count")

	fuel_slot = _create_slot_panel()
	fuel_slot.modulate = Color(0.8, 0.7, 0.6)
	fuel_slot.visible = false
	status_hbox.add_child(fuel_slot)
	fuel_icon = fuel_slot.get_node("Center/Icon")
	
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
	
	output_slot = _create_slot_panel()
	status_hbox.add_child(output_slot)
	output_icon = output_slot.get_node("Center/Icon")
	output_count = output_slot.get_node("Count")
	
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 15)
	machine_container.add_child(spacer)
	
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

	# Stats UI using robust VBox/Labels instead of RichTextLabel
	b_stats_container = VBoxContainer.new()
	b_stats_container.visible = false
	b_stats_container.add_theme_constant_override("separation", 4)
	b_stats_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(b_stats_container)
	
	var b_stats_title = Label.new()
	b_stats_title.text = "Building Stats"
	b_stats_title.add_theme_font_size_override("font_size", 16)
	b_stats_title.add_theme_color_override("font_color", Color.BLACK)
	b_stats_container.add_child(b_stats_title)
	
	b_stats_hp = Label.new()
	b_stats_hp.add_theme_font_size_override("font_size", 14)
	b_stats_hp.add_theme_color_override("font_color", Color(0.7, 0.0, 0.0))
	b_stats_container.add_child(b_stats_hp)
	
	b_stats_power = Label.new()
	b_stats_power.add_theme_font_size_override("font_size", 14)
	b_stats_power.add_theme_color_override("font_color", Color(0.6, 0.6, 0.0))
	b_stats_container.add_child(b_stats_power)
	
	b_stats_eff = Label.new()
	b_stats_eff.add_theme_font_size_override("font_size", 14)
	b_stats_eff.add_theme_color_override("font_color", Color(0.0, 0.6, 0.0))
	b_stats_container.add_child(b_stats_eff)

	main_vbox.queue_free()
	_setup_window_resizing(self, scale_wrapper, scale_root, frame_margin)

func _setup_window_resizing(win: Control, scale_wrapper: Control, scale_root: Control, content_node: Control) -> void:
	var m = 12
	var configs = [[0, -1, Control.CURSOR_VSIZE],[0, 1, Control.CURSOR_VSIZE],[-1, 0, Control.CURSOR_HSIZE],[1, 0, Control.CURSOR_HSIZE],[-1, -1, Control.CURSOR_FDIAGSIZE],[1, -1, Control.CURSOR_BDIAGSIZE],[-1, 1, Control.CURSOR_BDIAGSIZE],[1, 1, Control.CURSOR_FDIAGSIZE] 
	]
	
	var handles =[]
	var sync_ref =[]
	
	for cfg in configs:
		var handle = Control.new()
		handle.mouse_default_cursor_shape = cfg[2]
		handle.top_level = true
		win.add_child(handle)
		handles.append({"node": handle, "dx": cfg[0], "dy": cfg[1]})
		
		handle.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					win.set_meta("res_drag", true)
					win.set_meta("res_dx", cfg[0])
					win.set_meta("res_dy", cfg[1])
					win.set_meta("res_start_pos", win.global_position)
					win.set_meta("res_start_size", win.size)
					win.set_meta("res_start_mouse", event.global_position)
				else:
					win.set_meta("res_drag", false)
			elif event is InputEventMouseMotion and win.get_meta("res_drag", false):
				var dx = win.get_meta("res_dx")
				var dy = win.get_meta("res_dy")
				var s_pos = win.get_meta("res_start_pos")
				var s_size = win.get_meta("res_start_size")
				var s_mouse = win.get_meta("res_start_mouse")
				
				var delta = event.global_position - s_mouse
				var absolute_min = Vector2(100, 100) # Can scale very tiny
				
				var new_pos = s_pos
				var new_size = s_size
				
				if dx == 1:
					new_size.x = max(absolute_min.x, s_size.x + delta.x)
				elif dx == -1:
					new_size.x = max(absolute_min.x, s_size.x - delta.x)
					new_pos.x = s_pos.x + (s_size.x - new_size.x)
					
				if dy == 1:
					new_size.y = max(absolute_min.y, s_size.y + delta.y)
				elif dy == -1:
					new_size.y = max(absolute_min.y, s_size.y - delta.y)
					new_pos.y = s_pos.y + (s_size.y - new_size.y)
					
				win.global_position = new_pos
				win.size = new_size
				win.custom_minimum_size = new_size
				
				if sync_ref.size() > 0:
					sync_ref[0].call()
		)
		
	var sync_handles = func():
		if not win.is_inside_tree(): return
		
		var c_size = scale_wrapper.size
		if c_size.x < 10 or c_size.y < 10:
			c_size = win.size - Vector2(0, 30)
			
		c_size.x = max(1.0, c_size.x)
		c_size.y = max(1.0, c_size.y)
		
		var target_x = max(1.0, base_min_size.x - 24.0)
		var target_y = max(1.0, base_min_size.y - 54.0)
		
		var s = min(1.0, min(c_size.x / target_x, c_size.y / target_y))
		if s >= 0.99:
			s = 1.0 # Prevent floating point compression
			
		scale_root.scale = Vector2(s, s)
		content_node.size = (c_size / s).ceil()
		content_node.position = Vector2.ZERO
		
		for h in handles:
			var node = h.node
			var dx = h.dx
			var dy = h.dy
			var r_pos = win.global_position
			var r_size = win.size
			
			if dx == 0 and dy == -1:
				node.global_position = r_pos + Vector2(m, -m)
				node.size = Vector2(r_size.x - 2*m, 2*m)
			elif dx == 0 and dy == 1:
				node.global_position = r_pos + Vector2(m, r_size.y - m)
				node.size = Vector2(r_size.x - 2*m, 2*m)
			elif dx == -1 and dy == 0:
				node.global_position = r_pos + Vector2(-m, m)
				node.size = Vector2(2*m, r_size.y - 2*m)
			elif dx == 1 and dy == 0:
				node.global_position = r_pos + Vector2(r_size.x - m, m)
				node.size = Vector2(2*m, r_size.y - 2*m)
			elif dx == -1 and dy == -1:
				node.global_position = r_pos + Vector2(-m, -m)
				node.size = Vector2(2*m, 2*m)
			elif dx == 1 and dy == -1:
				node.global_position = r_pos + Vector2(r_size.x - m, -m)
				node.size = Vector2(2*m, 2*m)
			elif dx == -1 and dy == 1:
				node.global_position = r_pos + Vector2(-m, r_size.y - m)
				node.size = Vector2(2*m, 2*m)
			elif dx == 1 and dy == 1:
				node.global_position = r_pos + Vector2(r_size.x - m, r_size.y - m)
				node.size = Vector2(2*m, 2*m)
				
	sync_ref.append(sync_handles)
	win.resized.connect(sync_handles)
	win.item_rect_changed.connect(sync_handles)
	win.visibility_changed.connect(func():
		for h in handles:
			h.node.visible = win.visible
		if win.visible:
			win.call_deferred("emit_signal", "resized")
	)
	win.call_deferred("emit_signal", "resized")

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
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(64, 64)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
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
	
	var slot_data = inv.slots[idx]
	if slot_data:
		tr.texture = slot_data.item.icon
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
		btn.text = "MOD"
		btn.modulate = Color(1, 1, 1, 0.5)
	
	btn.set_drag_forwarding(
		Callable(self, "_get_slot_drag_data").bind({"inv": inv, "slot": idx}), 
		Callable(self, "_on_slot_can_drop").bind(inv), 
		Callable(self, "_on_slot_drop").bind(inv, idx)
	)
	return btn

# --- Drag & Drop Implementation ---

func _on_bg_get_drag_data(_pos):
	return null

func _on_bg_can_drop(_pos, data) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.get("type") == "inventory_drag"

func _on_bg_drop(_pos, data) -> void:
	# Specifically zero-out the exact slot dragged to prevent accidentally eating other identical stacks
	if data.has("inventory") and data.has("item") and data.has("count"):
		var inv = data.inventory
		if data.has("slot_index") and data.slot_index >= 0 and data.slot_index < inv.slots.size():
			var slot = inv.slots[data.slot_index]
			if slot and slot.item == data.item:
				inv.slots[data.slot_index] = null
				inv.inventory_changed.emit()
				return
		
		# Fallback if slot index wasn't perfectly mapped
		inv.remove_item(data.item, data.count)

func _get_slot_drag_data(_pos, data_ctx):
	var inv = data_ctx.inv
	var slot_idx = data_ctx.slot
	if not inv or slot_idx >= inv.slots.size() or inv.slots[slot_idx] == null:
		return null
	
	var item = inv.slots[slot_idx].item
	var count = inv.slots[slot_idx].count
	
	var preview = TextureRect.new()
	preview.texture = item.icon
	preview.size = Vector2(64, 64)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture_filter = Control.TEXTURE_FILTER_NEAREST
	preview.z_index = 100
	set_drag_preview(preview)
	
	return { 
		"type": "inventory_drag", 
		"inventory": inv, 
		"slot_index": slot_idx, 
		"item": item, 
		"count": count 
	}

func _on_slot_can_drop(_pos, data, target_inv: InventoryComponent) -> bool:
	if typeof(data) != TYPE_DICTIONARY or data.get("type") != "inventory_drag": 
		return false
	if not target_inv or not target_inv.can_receive: 
		return false
	if not target_inv.is_item_allowed(data.item):
		return false
	return true

func _on_slot_drop(_pos, data, target_inv: InventoryComponent, to_index: int) -> void:
	var source_inv = data.inventory
	var source_idx = data.slot_index
	var item = data.item
	var count = data.count
	
	if not is_instance_valid(source_inv) or source_idx >= source_inv.slots.size():
		return
	if source_inv.slots[source_idx] == null:
		return

	var target_slot = target_inv.slots[to_index]
	
	if source_inv == target_inv:
		if target_slot == null:
			target_inv.slots[to_index] = source_inv.slots[source_idx]
			source_inv.slots[source_idx] = null
		else:
			var temp = target_inv.slots[to_index]
			target_inv.slots[to_index] = source_inv.slots[source_idx]
			source_inv.slots[source_idx] = temp
		target_inv.inventory_changed.emit()
	else:
		var remainder = target_inv.add_item(item, count)
		var taken = count - remainder
		if taken > 0:
			# Directly deduct from the source slot rather than calling a broad remove_item
			# which might accidentally sweep a different slot holding the same item type.
			var s_slot = source_inv.slots[source_idx]
			if s_slot and s_slot.item == item:
				s_slot.count -= taken
				if s_slot.count <= 0:
					source_inv.slots[source_idx] = null
				source_inv.inventory_changed.emit()
			else:
				# Safe fallback
				source_inv.remove_item(item, taken)

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
		for inv_name in["input_inventory", "output_inventory", "fuel_inventory", "mod_inventory"]:
			var inv = current_context.get(inv_name)
			if inv and not inv.inventory_changed.is_connected(_update_display):
				inv.inventory_changed.connect(_update_display)

	if current_inventory:
		if not current_inventory.inventory_changed.is_connected(_update_display):
			current_inventory.inventory_changed.connect(_update_display)
			
	_update_display()
	
	if not visible:
		var vp_size = get_viewport_rect().size
		var s_size = size
		if s_size.x <= 10: s_size = base_min_size
		position = (vp_size - s_size) / 2.0
		
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
		for inv_name in["input_inventory", "output_inventory", "fuel_inventory", "mod_inventory"]:
			var inv = current_context.get(inv_name)
			if inv and inv.is_connected("inventory_changed", _update_display):
				inv.inventory_changed.disconnect(_update_display)

func _update_display(_arg = null) -> void:
	if current_context and "mod_inventory" in current_context and current_context.mod_inventory:
		mod_lbl.show()
		mod_grid.show()
		right_vbox.show()
		
		for child in mod_grid.get_children(): child.queue_free()
		var m_inv = current_context.mod_inventory
		for i in range(m_inv.slots.size()):
			var btn = _create_grid_slot_btn(m_inv, i)
			var tooltip = "Mod Slot " + str(i+1)
			if m_inv.slots[i]:
				var itm = m_inv.slots[i].item
				if "item_name" in itm: tooltip = itm.item_name
				elif "buildable_name" in itm: tooltip = itm.buildable_name
			btn.tooltip_text = tooltip
			mod_grid.add_child(btn)
			
		# Show Building Stats using robust Label nodes
		if current_context.has_method("get_stat") or current_context.get("health_component"):
			b_stats_container.show()
			var hp = 0; var mhp = 0; var pwr = 0; var eff = 1.0
			
			if current_context.get("health_component"):
				hp = current_context.health_component.current_health
				mhp = current_context.health_component.max_health
			if current_context.get("power_consumer"):
				pwr = current_context.power_consumer.power_consumption
			if current_context.has_method("get_stat"):
				eff = current_context.get_stat("efficiency", current_context.get("efficiency") if current_context.get("efficiency") != null else 1.0)
			
			b_stats_hp.text = "HP: %d / %d" %[int(hp), int(mhp)]
			b_stats_power.text = "Power: %d W" % int(pwr)
			b_stats_eff.text = "Efficiency: %.1fx" % eff
		else:
			b_stats_container.hide()
	else:
		right_vbox.hide()
		mod_lbl.hide()
		mod_grid.hide()
		if b_stats_container: b_stats_container.hide()

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
			
			var clean_name = "Machine"
			if "display_name" in current_context and current_context.display_name != "":
				clean_name = current_context.display_name
			elif "name" in current_context:
				clean_name = current_context.name.rstrip("0123456789")
			if title_label: title_label.text = "  " + clean_name
			
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

	machine_container.hide()
	recipe_scroll.hide()
	content_container.show()
	item_panel.hide()
	
	if not current_inventory: 
		generic_grid.hide()
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
			
			var tooltip = ""
			var slot_name = ""
			
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
					
			# Display the custom text overlay so labeled boxes are highly visible regardless of contents
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
				if "item_name" in item: tooltip += item.item_name
				elif "buildable_name" in item: tooltip += item.buildable_name
			else:
				if is_ally:
					match i:
						0: btn.text = "TL"
						1: btn.text = "WP"
						2: btn.text = "AR"
						3: btn.text = "AT"
				tooltip += "Empty"
			
			btn.tooltip_text = tooltip
			
			btn.set_drag_forwarding(
				Callable(self, "_get_slot_drag_data").bind({"inv": current_inventory, "slot": i}), 
				Callable(self, "_on_slot_can_drop").bind(current_inventory), 
				Callable(self, "_on_slot_drop").bind(current_inventory, i)
			)
			
			generic_grid.add_child(btn)

func _update_machine_io(panel: Panel, icon_rect: TextureRect, count_lbl: Label, inv: InventoryComponent, recipe: RecipeResource, is_input: bool) -> void:
	var current_amount = 0
	if inv and inv.slots.size() > 0 and inv.slots[0] != null:
		current_amount = inv.slots[0].count
	
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
			if recipe.inputs.size() > 0:
				var entry = recipe.inputs[0] # Simplification
				target_icon = entry.resource.icon
				required_amount = entry.count
				if "item_name" in entry.resource: item_name = entry.resource.item_name
				elif "buildable_name" in entry.resource: item_name = entry.resource.buildable_name
		else:
			if recipe.outputs.size() > 0:
				var entry = recipe.outputs[0]
				target_icon = entry.resource.icon
				required_amount = entry.count
				if "item_name" in entry.resource: item_name = entry.resource.item_name
				elif "buildable_name" in entry.resource: item_name = entry.resource.buildable_name
	
	if current_amount > 0 and inv.slots[0] != null:
		icon_rect.texture = inv.slots[0].item.icon
		icon_rect.modulate.a = 1.0
	elif target_icon:
		icon_rect.texture = target_icon
		icon_rect.modulate = target_color
		icon_rect.modulate.a = 0.4
	else:
		icon_rect.texture = null
	
	if count_lbl:
		if is_input and target_icon:
			count_lbl.text = "%d / %d" %[current_amount, required_amount]
		else:
			count_lbl.text = "" if current_amount == 0 else str(current_amount)
	
	if panel: panel.tooltip_text = item_name

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
				Callable(self, "_on_bg_get_drag_data"),
				Callable(self, "_on_bg_can_drop"),
				Callable(self, "_on_bg_drop")
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
