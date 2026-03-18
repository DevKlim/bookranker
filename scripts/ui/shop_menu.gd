class_name ShopMenu
extends Control

signal closed

var panel: PanelContainer
var items_container: HBoxContainer
var close_button: Button
var byts_label: Label
var scale_root: Control

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
		mat.set_shader_parameter("tint", Color(0.9, 0.9, 0.9, 0.25))
		mat.set_shader_parameter("corner_radius", corner_radius)
		mat.set_shader_parameter("bezel_width", 12.0)
	bg.material = mat
	win.add_child(bg)
	win.move_child(bg, 1)
	
	win.resized.connect(func(): if mat.shader: mat.set_shader_parameter("rect_size", win.size))
	win.call_deferred("emit_signal", "resized")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	
	GameManager.run_data_changed.connect(_update_byts_label)
	
	var positioning_layer = Control.new()
	positioning_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	positioning_layer.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(positioning_layer)
	
	panel = PanelContainer.new()
	panel.clip_contents = true
	panel.custom_minimum_size = Vector2(650, 450)
	_apply_liquid_glass(panel, 12.0)
	positioning_layer.add_child(panel)
	
	var main_margin = MarginContainer.new()
	main_margin.add_theme_constant_override("margin_left", 4)
	main_margin.add_theme_constant_override("margin_right", 4)
	main_margin.add_theme_constant_override("margin_top", -2)
	main_margin.add_theme_constant_override("margin_bottom", 4)
	main_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(main_margin)

	var outer_vbox = VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", 0)
	outer_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_margin.add_child(outer_vbox)

	var title_bar = PanelContainer.new()
	title_bar.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	title_bar.custom_minimum_size = Vector2(0, 30)
	title_bar.gui_input.connect(_on_title_gui_input)
	outer_vbox.add_child(title_bar)
	
	var title_margin = MarginContainer.new()
	title_margin.add_theme_constant_override("margin_bottom", 5)
	title_margin.add_theme_constant_override("margin_left", 12)
	title_margin.add_theme_constant_override("margin_right", 12)
	title_margin.add_theme_constant_override("margin_top", 10)
	title_bar.add_child(title_margin)
	
	var title_hbox = HBoxContainer.new()
	title_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	title_margin.add_child(title_hbox)
	
	var title = Label.new()
	title.text = "  Shop"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.add_theme_font_size_override("font_size", 24) 
	title.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.clip_text = true
	title_hbox.add_child(title)

	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 2)
	btn_hbox.alignment = BoxContainer.ALIGNMENT_END
	title_hbox.add_child(btn_hbox)
	
	close_button = _create_xp_btn("X")
	close_button.pressed.connect(_on_close_pressed)
	
	btn_hbox.add_child(close_button)
	
	var scale_wrapper = Control.new()
	scale_wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scale_wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scale_wrapper.clip_contents = true
	outer_vbox.add_child(scale_wrapper)

	scale_root = Control.new()
	scale_wrapper.add_child(scale_root)

	var frame_margin = MarginContainer.new()
	frame_margin.add_theme_constant_override("margin_left", 0)
	frame_margin.add_theme_constant_override("margin_right", 0)
	frame_margin.add_theme_constant_override("margin_bottom", 0)
	frame_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scale_root.add_child(frame_margin)
	
	var content_bg = PanelContainer.new()
	var cbg_style = StyleBoxFlat.new()
	cbg_style.bg_color = Color.WHITE
	cbg_style.corner_radius_bottom_left = 6
	cbg_style.corner_radius_bottom_right = 6
	cbg_style.corner_radius_top_left = 6
	cbg_style.corner_radius_top_right = 6
	content_bg.add_theme_stylebox_override("panel", cbg_style)
	content_bg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame_margin.add_child(content_bg)
	
	# Content Area
	var content_margin = MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", 20)
	content_margin.add_theme_constant_override("margin_right", 20)
	content_margin.add_theme_constant_override("margin_top", 20)
	content_margin.add_theme_constant_override("margin_bottom", 20)
	content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_bg.add_child(content_margin)
	
	var content_vbox = VBoxContainer.new()
	content_margin.add_child(content_vbox)
	
	var top_hbox = HBoxContainer.new()
	content_vbox.add_child(top_hbox)
	
	var subtitle = Label.new()
	subtitle.text = "Purchase Upgrades and Mods"
	subtitle.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
	subtitle.add_theme_font_size_override("font_size", 20)
	top_hbox.add_child(subtitle)
	
	byts_label = Label.new()
	byts_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
	byts_label.add_theme_font_size_override("font_size", 20)
	byts_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	byts_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_hbox.add_child(byts_label)
	
	items_container = HBoxContainer.new()
	items_container.alignment = BoxContainer.ALIGNMENT_CENTER
	items_container.add_theme_constant_override("separation", 20)
	items_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_vbox.add_child(items_container)
	
	_setup_window_resizing(panel, scale_wrapper, scale_root, frame_margin)

func _create_xp_btn(txt: String) -> Button:
	var btn = Button.new()
	btn.text = txt
	btn.custom_minimum_size = Vector2(24, 20)
	
	var normal = StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("normal", normal)
	
	var hover = StyleBoxFlat.new()
	hover.bg_color = Color(1, 1, 1, 0.2)
	hover.corner_radius_top_left = 4; hover.corner_radius_top_right = 4
	hover.corner_radius_bottom_left = 4; hover.corner_radius_bottom_right = 4
	btn.add_theme_stylebox_override("hover", hover)
	
	var pressed = hover.duplicate()
	pressed.bg_color = Color(1, 1, 1, 0.4)
	btn.add_theme_stylebox_override("pressed", pressed)
	
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	
	return btn

func _setup_window_resizing(win: Control, scale_wrapper: Control, scale_root: Control, content_node: Control) -> void:
	var m = 12
	var configs = [[0, -1, Control.CURSOR_VSIZE],[0, 1, Control.CURSOR_VSIZE],[-1, 0, Control.CURSOR_HSIZE],[1, 0, Control.CURSOR_HSIZE],[-1, -1, Control.CURSOR_FDIAGSIZE],[1, -1, Control.CURSOR_BDIAGSIZE],[-1, 1, Control.CURSOR_BDIAGSIZE],[1, 1, Control.CURSOR_FDIAGSIZE]]
	
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
				var absolute_min = Vector2(100, 100) # Squish small!
				
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
		c_size.x = max(1.0, c_size.x)
		c_size.y = max(1.0, c_size.y)
		
		var target_x = max(1.0, 650.0 - 24.0)
		var target_y = max(1.0, 450.0 - 54.0)
		
		var s = min(1.0, min(c_size.x / target_x, c_size.y / target_y))
		if s >= 0.99:
			s = 1.0
			
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
	
	# Fixes layout size propagation bugs on dynamically spawned shop items
	visibility_changed.connect(func():
		for h in handles:
			h.node.visible = visible
		if visible:
			await get_tree().process_frame
			if is_instance_valid(win):
				win.emit_signal("resized")
	)
	
	if visible:
		win.call_deferred("emit_signal", "resized")

func _on_title_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = true
				drag_offset = event.global_position - panel.global_position
			else:
				dragging = false
	elif event is InputEventMouseMotion and dragging:
		panel.global_position = event.global_position - drag_offset

func open(wave_idx: int) -> void:
	_update_byts_label()
	_populate_shop(wave_idx)
	
	var vp_size = get_viewport_rect().size
	var p_size = panel.size
	if p_size.x <= 10: p_size = Vector2(650, 450)
	panel.size = p_size
	panel.position = (vp_size - p_size) / 2.0
	show()
	
	# Explicit call to enforce instant child container updates
	panel.reset_size()
	panel.emit_signal("resized")

func _update_byts_label() -> void:
	if is_instance_valid(byts_label):
		byts_label.text = "Byts: " + str(GameManager.get_currency())

func _on_close_pressed() -> void:
	hide()
	emit_signal("closed")

func _populate_shop(wave_idx: int) -> void:
	for c in items_container.get_children():
		c.queue_free()
		
	var pool = _get_shop_pool(wave_idx)
	pool.shuffle()
	
	if pool.is_empty():
		var lbl = Label.new()
		lbl.add_theme_color_override("font_color", Color.BLACK)
		lbl.text = "No items available."
		items_container.add_child(lbl)
		return
	
	var to_show = min(3, pool.size())
	for i in range(to_show):
		_create_shop_item(pool[i])

func _get_shop_pool(wave_idx: int) -> Array:
	var all_mods =[]
	var ItemResClass = load("res://scripts/resources/item_resource.gd")
	var dir = DirAccess.open("res://resources/mods/")
	
	if dir:
		dir.list_dir_begin()
		var f = dir.get_next()
		while f != "":
			if f.ends_with(".tres"):
				var res = load("res://resources/mods/" + f)
				if res is ItemResource and "MOD" in ItemResClass.EquipmentType.keys() and res.equipment_type == ItemResClass.EquipmentType.MOD:
					all_mods.append(res)
			f = dir.get_next()
			
	var pool =[]
	
	for mod in all_mods:
		var type = mod.modifiers.get("type", "building")
		if wave_idx == 0:
			if type == "core":
				pool.append(mod)
		else:
			pool.append(mod)
			
	return pool

func _create_shop_item(item: ItemResource) -> void:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	
	var panel_bg = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.95, 0.95, 0.95)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.8, 0.8, 0.8)
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	panel_bg.add_theme_stylebox_override("panel", style)
	panel_bg.custom_minimum_size = Vector2(120, 150)
	vbox.add_child(panel_bg)
	
	var inner_vbox = VBoxContainer.new()
	inner_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel_bg.add_child(inner_vbox)
	
	var icon = TextureRect.new()
	icon.texture = item.icon
	icon.custom_minimum_size = Vector2(40, 40)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	inner_vbox.add_child(icon)
	
	var name_lbl = Label.new()
	name_lbl.text = item.item_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_lbl.custom_minimum_size = Vector2(100, 0)
	name_lbl.add_theme_color_override("font_color", Color.BLACK)
	inner_vbox.add_child(name_lbl)
	
	var type_lbl = Label.new()
	type_lbl.text = "[" + item.modifiers.get("type", "Unknown").capitalize() + "]"
	type_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	type_lbl.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
	type_lbl.add_theme_font_size_override("font_size", 12)
	inner_vbox.add_child(type_lbl)
	
	var cost = int(item.modifiers.get("cost", 1))
	
	var buy_btn = Button.new()
	buy_btn.text = "Buy (" + str(cost) + " Byts)"
	buy_btn.custom_minimum_size = Vector2(100, 36)
	buy_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	buy_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.95, 0.95, 0.95)
	btn_style.border_width_left = 1
	btn_style.border_width_right = 1
	btn_style.border_width_top = 1
	btn_style.border_width_bottom = 1
	btn_style.border_color = Color(0.8, 0.8, 0.8)
	btn_style.corner_radius_top_left = 4
	btn_style.corner_radius_top_right = 4
	btn_style.corner_radius_bottom_left = 4
	btn_style.corner_radius_bottom_right = 4
	buy_btn.add_theme_stylebox_override("normal", btn_style)
	buy_btn.add_theme_color_override("font_color", Color.BLACK)
	
	buy_btn.pressed.connect(func():
		if GameManager.spend_currency(cost):
			PlayerManager.game_inventory.add_item(item, 1)
			buy_btn.text = "Bought"
			buy_btn.disabled = true
			var ui = GameManager.get_node_or_null("/root/Main/GameUI")
			if ui: ui.show_notification("Purchased " + item.item_name, Color.GREEN)
		else:
			var ui = GameManager.get_node_or_null("/root/Main/GameUI")
			if ui: ui.show_notification("Not enough Byts!", Color.RED)
	)
	
	vbox.add_child(buy_btn)
	items_container.add_child(vbox)
