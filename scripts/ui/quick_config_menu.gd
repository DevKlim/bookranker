class_name QuickConfigMenu
extends RefCounted

static func open(slot_data: Dictionary, parent: Control) -> void:
	var layer_root = CanvasLayer.new()
	layer_root.layer = 160
	layer_root.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Consume unhandled cancel inputs natively without alerting Main (Preserves UI priority hierarchy)
	var script = GDScript.new()
	script.source_code = """
extends CanvasLayer
func _input(event):
	if event.is_action_pressed("ui_cancel"):
		queue_free()
		get_viewport().set_input_as_handled()
"""
	script.reload()
	layer_root.set_script(script)
	
	# Pause the game to block background interaction (raycasting, etc.)
	parent.get_tree().paused = true
	layer_root.tree_exited.connect(func(): parent.get_tree().paused = false)
	
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.4)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	layer_root.add_child(bg)
	
	var window_root = Control.new()
	var vp_size = DisplayServer.window_get_size()
	window_root.size = Vector2(450, 550)
	window_root.position = (Vector2(vp_size) - window_root.size) / 2.0
	layer_root.add_child(window_root)
	
	var scale_wrapper = Control.new()
	scale_wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scale_wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scale_wrapper.clip_contents = true
	scale_wrapper.set_anchors_preset(Control.PRESET_FULL_RECT)
	window_root.add_child(scale_wrapper)
	
	var scale_root = Control.new()
	scale_wrapper.add_child(scale_root)
	
	var frame_margin = MarginContainer.new()
	frame_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scale_root.add_child(frame_margin)
	
	var panel = PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	var custom_theme = Theme.new()
	var font = load("res://assets/fonts/v2-fs-tahoma-8px.otf")
	if font:
		custom_theme.default_font = font
		custom_theme.default_font_size = 16
	panel.theme = custom_theme
	
	if ClassDB.class_exists("WindowUtils") or ResourceLoader.exists("res://scripts/ui/window_utils.gd"):
		var wu = load("res://scripts/ui/window_utils.gd")
		wu.apply_liquid_glass(panel, 12.0)
	frame_margin.add_child(panel)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)
	
	# Main VBox holds Top Bar, Scroll Area, and Bottom Save Button
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 15)
	margin.add_child(main_vbox)
	
	if not slot_data.has("meta"): slot_data["meta"] = {}
	var meta = slot_data["meta"]
	
	var top_hbox = HBoxContainer.new()
	var title_lbl = Label.new()
	title_lbl.text = "Pre-Configure Attack Spawner"
	title_lbl.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(title_lbl)
	
	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(30, 30)
	var cls_style = StyleBoxFlat.new()
	cls_style.bg_color = Color(1.0, 0.3, 0.3, 0.5)
	cls_style.corner_radius_top_left = 6; cls_style.corner_radius_top_right = 6
	cls_style.corner_radius_bottom_left = 6; cls_style.corner_radius_bottom_right = 6
	close_btn.add_theme_stylebox_override("normal", cls_style)
	close_btn.pressed.connect(layer_root.queue_free)
	top_hbox.add_child(close_btn)
	main_vbox.add_child(top_hbox)
	
	# Handles physical Window Dragging logic by using the top container Box
	var drag_data = {"dragging": false, "offset": Vector2.ZERO}
	top_hbox.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			drag_data.dragging = event.pressed
			if event.pressed:
				drag_data.offset = event.global_position - window_root.global_position
		elif event is InputEventMouseMotion and drag_data.dragging:
			window_root.global_position = event.global_position - drag_data.offset
	)
	
	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(scroll)
	
	var scroll_vbox = VBoxContainer.new()
	scroll_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_vbox.add_theme_constant_override("separation", 15)
	scroll.add_child(scroll_vbox)
	
	var mode_opt = OptionButton.new()
	mode_opt.add_item("Attack Mode")
	mode_opt.add_item("Element Sequence Mode")
	mode_opt.selected = meta.get("mode", 0)
	scroll_vbox.add_child(mode_opt)
	
	var atk_files = []
	var a_dir = DirAccess.open("res://resources/attacks/")
	if a_dir:
		a_dir.list_dir_begin()
		var file = a_dir.get_next()
		while file != "":
			if file.ends_with(".tres"): atk_files.append(file.get_basename())
			file = a_dir.get_next()
			
	var atk_opt = OptionButton.new()
	for a in atk_files: atk_opt.add_item(a)
	if meta.has("attack_id"):
		for i in range(atk_files.size()):
			if atk_files[i] == meta["attack_id"]: atk_opt.selected = i
	scroll_vbox.add_child(atk_opt)
	
	var h_line = ColorRect.new()
	h_line.custom_minimum_size = Vector2(0, 2)
	h_line.color = Color(0, 0, 0, 0.2)
	scroll_vbox.add_child(h_line)
	
	var el_files = []
	var e_dir = DirAccess.open("res://resources/elements/")
	if e_dir:
		e_dir.list_dir_begin()
		var file = e_dir.get_next()
		while file != "":
			if file.ends_with(".tres"):
				var res = load("res://resources/elements/" + file) as ElementResource
				if res: el_files.append(res.element_name)
			file = e_dir.get_next()
	
	var seq_opt = OptionButton.new()
	for e in el_files: seq_opt.add_item(e)
	scroll_vbox.add_child(seq_opt)
	
	var el_seq = meta.get("sequence", []).duplicate()
	var seq_lbl = Label.new()
	seq_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	seq_lbl.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
	var refresh_seq = func(): seq_lbl.text = "Sequence: " + ", ".join(el_seq)
	refresh_seq.call()
	scroll_vbox.add_child(seq_lbl)
	
	var btn_hbox = HBoxContainer.new()
	var add_btn = Button.new()
	add_btn.text = "Add to Sequence"
	add_btn.add_theme_color_override("font_color", Color.BLACK)
	add_btn.pressed.connect(func():
		if el_files.size() > 0:
			el_seq.append(el_files[seq_opt.selected])
			refresh_seq.call()
	)
	var clear_btn = Button.new()
	clear_btn.text = "Clear"
	clear_btn.add_theme_color_override("font_color", Color.BLACK)
	clear_btn.pressed.connect(func(): el_seq.clear(); refresh_seq.call())
	btn_hbox.add_child(add_btn)
	btn_hbox.add_child(clear_btn)
	scroll_vbox.add_child(btn_hbox)
	
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 15)
	grid.add_theme_constant_override("v_separation", 8)
	scroll_vbox.add_child(grid)
	
	var _create_spin = func(lbl_text, val, parent_grid):
		var l = Label.new()
		l.text = lbl_text
		l.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
		parent_grid.add_child(l)
		var s = SpinBox.new()
		s.max_value = 99999
		s.step = 0.1
		s.value = val
		parent_grid.add_child(s)
		return s
		
	var units_s = _create_spin.call("Elemental Units:", meta.get("units", 1), grid)
	var dmg_s = _create_spin.call("Source Damage:", meta.get("dmg", 10.0), grid)
	var aoe_s = _create_spin.call("AOE Radius:", meta.get("aoe", 2.0), grid)
	var cd_s = _create_spin.call("Cooldown:", meta.get("cd", 0.5), grid)
	
	var pop_check = CheckBox.new()
	pop_check.text = "Play On Place (Auto-Removes)"
	pop_check.button_pressed = meta.get("play_on_place", false)
	pop_check.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	pop_check.add_theme_color_override("font_hover_color", Color(0.3, 0.3, 0.3))
	pop_check.add_theme_color_override("font_pressed_color", Color.BLACK)
	scroll_vbox.add_child(pop_check)
	
	var h_line2 = ColorRect.new()
	h_line2.custom_minimum_size = Vector2(0, 2)
	h_line2.color = Color(0, 0, 0, 0.2)
	scroll_vbox.add_child(h_line2)
	
	var stats_title = Label.new()
	stats_title.text = "Building Stat Overrides"
	stats_title.add_theme_color_override("font_color", Color(0.1, 0.1, 0.5))
	scroll_vbox.add_child(stats_title)
	
	var stats_grid = GridContainer.new()
	stats_grid.columns = 2
	stats_grid.add_theme_constant_override("h_separation", 15)
	stats_grid.add_theme_constant_override("v_separation", 8)
	scroll_vbox.add_child(stats_grid)
	
	var stat_names = [
		"lux_stat", "max_health", "security", "max_energy", 
		"power_consumption", "speed", "compute", "networking", 
		"attack_damage", "process_speed", "defense", "firewall", 
		"space", "ping", "malware", "entity_scale"
	]
	
	# Mapping sensible building defaults
	var defaults = {
		"lux_stat": 0.0, "max_health": 100.0, "security": 0.0, "max_energy": 50.0,
		"power_consumption": 5.0, "speed": 5.0, "compute": 1.0, "networking": 0.0,
		"attack_damage": 0.0, "process_speed": 1.0, "defense": 0.0, "firewall": 0.0,
		"space": 10.0, "ping": 1.0, "malware": 0.0, "entity_scale": 1.0
	}
	
	var stat_spins = {}
	for sn in stat_names:
		stat_spins[sn] = _create_spin.call(sn.capitalize() + ":", meta.get(sn, defaults[sn]), stats_grid)
	
	var save_btn = Button.new()
	save_btn.text = "Save Quick Config"
	save_btn.custom_minimum_size = Vector2(0, 40)
	save_btn.add_theme_color_override("font_color", Color.BLACK)
	save_btn.pressed.connect(func():
		meta["mode"] = mode_opt.selected
		meta["attack_id"] = atk_files[atk_opt.selected] if atk_files.size() > 0 else ""
		meta["sequence"] = el_seq
		meta["units"] = int(units_s.value)
		meta["dmg"] = dmg_s.value
		meta["aoe"] = aoe_s.value
		meta["cd"] = cd_s.value
		meta["play_on_place"] = pop_check.button_pressed
		
		for sn in stat_names:
			meta[sn] = stat_spins[sn].value
		
		# Propagate visually directly
		if parent.has_method("_update_visuals"): parent._update_visuals()
		layer_root.queue_free()
	)
	main_vbox.add_child(save_btn)
	
	var toggle_vis = func(_idx):
		var is_attack = (mode_opt.selected == 0)
		atk_opt.visible = is_attack
		seq_opt.visible = not is_attack
		seq_lbl.visible = not is_attack
		btn_hbox.visible = not is_attack
		grid.visible = not is_attack
	
	mode_opt.item_selected.connect(toggle_vis)
	toggle_vis.call(mode_opt.selected)
	
	# Add directly to the tree's root to avoid canvas layer clipping
	parent.get_tree().root.add_child(layer_root)
	
	# Register standard window resizing edges setup
	if ClassDB.class_exists("WindowUtils") or ResourceLoader.exists("res://scripts/ui/window_utils.gd"):
		var wu = load("res://scripts/ui/window_utils.gd")
		wu.setup_window_resizing(window_root, scale_wrapper, scale_root, frame_margin, Vector2(450, 500))
