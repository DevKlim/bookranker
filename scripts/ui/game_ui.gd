class_name GameUI
extends CanvasLayer

## Manages the main game UI elements.
## Handles instantiation of sub-components like DevUI, Inventory, and Menus.

@onready var debug_coords_label: Label = $DebugCoordsLabel
@onready var hotbar: PanelContainer = $Hotbar
@onready var inventory_gui: PanelContainer = $InventoryGUI

# Dynamically instantiated components
var dev_ui_panel: Panel 
var player_menu: PlayerMenu
var pause_menu: PauseMenu 
var network_stats_panel: PanelContainer
var network_stats_label: RichTextLabel
var notification_label: Label
var shop_menu: ShopMenu
var currency_label: Label
var core_hp_label: Label
var timer_label: Label
var respawns_label: Label
var _core_ref: Node

# Context Menu
var context_menu_panel: PanelContainer
var context_menu_vbox: VBoxContainer

# macOS / Glass Wrappers
var taskbar: PanelContainer
var taskbar_hbox: HBoxContainer
var stats_window: PanelContainer
var dev_window: PanelContainer
var hotbar_window: PanelContainer
var bottom_left_content: Control

var global_theme: Theme
var active_respawns: Array =[]

const DEV_UI_SCRIPT = preload("res://scripts/ui/dev_ui.gd")
const PAUSE_MENU_SCENE = preload("res://scenes/ui/pause_menu.tscn")

func _ready() -> void:
	var font = load("res://assets/fonts/v2-fs-tahoma-8px.otf")
	if not font:
		font = SystemFont.new()
		font.font_names = PackedStringArray(["Tahoma", "Helvetica Neue", "Arial", "sans-serif"])
	
	ThemeDB.fallback_font = font
	ThemeDB.fallback_font_size = 24
	
	global_theme = Theme.new()
	global_theme.default_font = font
	global_theme.default_font_size = 24
	
	for child in get_children():
		if child is Control:
			child.theme = global_theme
	
	var backdrop = ColorRect.new()
	backdrop.name = "UIBackdrop"
	backdrop.color = Color(0, 0, 0, 0.2)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	move_child(backdrop, 0)
	
	var drop_zone = WorldDropTarget.new()
	drop_zone.name = "WorldDropZone"
	drop_zone.set_anchors_preset(Control.PRESET_FULL_RECT)
	drop_zone.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(drop_zone)
	move_child(drop_zone, 1)

	_setup_taskbar()
	_setup_network_stats_ui()
	_setup_pause_menu_instance()
	_setup_notification_label()
	_setup_context_menu()
	_setup_bottom_left_ui()
	_setup_timer_ui()
	_setup_shop_menu()
	
	GameManager.shop_requested.connect(_on_shop_requested)
	GameManager.run_data_changed.connect(_update_currency_ui)
	GameManager.time_updated.connect(_on_time_updated)
	
	_setup_dev_ui()

	if debug_coords_label:
		debug_coords_label.text = "Tile: (-, -)"
	
	if inventory_gui:
		inventory_gui.hide()
		inventory_gui.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
	
	if is_instance_valid(GameManager):
		GameManager.reset_state()
		_initialize_recipe_database()
	
	player_menu = PlayerMenu.new()
	player_menu.name = "PlayerMenu"
	player_menu.visible = false
	player_menu.theme = global_theme
	add_child(player_menu)

	var vp_size = get_viewport().get_visible_rect().size
	
	# Increased height to 200 and shifted up to gracefully fit multiple respawning lines
	stats_window = _create_glass_window("Stats", bottom_left_content, Vector2(20, vp_size.y - 230), "Stats", Vector2(280, 200))
	
	dev_window = _create_glass_window("Dev Tools", dev_ui_panel, Vector2(vp_size.x - 260, 20), "Dev Tools", Vector2(250, 200))
	hotbar_window = _create_glass_window("Hotbar", hotbar, Vector2((vp_size.x - 750) / 2.0, vp_size.y - 180), "Hotbar", Vector2(800, 160))
	
	var pm_btn = Button.new()
	pm_btn.text = "Player Menu"
	pm_btn.custom_minimum_size = Vector2(100, 30)
	var tb_style = StyleBoxFlat.new()
	tb_style.bg_color = Color(0.85, 0.85, 0.85, 0)
	tb_style.corner_radius_top_left = 6; tb_style.corner_radius_top_right = 6
	tb_style.corner_radius_bottom_left = 6; tb_style.corner_radius_bottom_right = 6
	pm_btn.add_theme_stylebox_override("normal", tb_style)
	pm_btn.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
	pm_btn.pressed.connect(func(): toggle_player_menu())
	taskbar_hbox.add_child(pm_btn)

func apply_liquid_glass(win: Control, corner_radius: float = 12.0) -> void:
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

func _setup_taskbar() -> void:
	taskbar = PanelContainer.new()
	taskbar.theme = global_theme
	taskbar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	taskbar.offset_left = 100
	taskbar.offset_right = -100
	taskbar.offset_top = -50
	taskbar.offset_bottom = -5
	add_child(taskbar)
	apply_liquid_glass(taskbar, 16.0)

	var taskbar_margin = MarginContainer.new()
	taskbar_margin.add_theme_constant_override("margin_left", 12)
	taskbar_margin.add_theme_constant_override("margin_right", 12)
	taskbar_margin.add_theme_constant_override("margin_top", 4)
	taskbar_margin.add_theme_constant_override("margin_bottom", 4)
	taskbar_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	taskbar.add_child(taskbar_margin)
	
	taskbar_hbox = HBoxContainer.new()
	taskbar_hbox.add_theme_constant_override("separation", 15)
	taskbar_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	taskbar_margin.add_child(taskbar_hbox)

func _create_glass_window(title: String, content: Control, start_pos: Vector2, icon_text: String, base_min_size: Vector2) -> PanelContainer:
	var win = PanelContainer.new()
	win.theme = global_theme
	win.clip_contents = true
	add_child(win)
	win.position = start_pos
	win.size = base_min_size
	
	apply_liquid_glass(win, 12.0)

	var win_margin = MarginContainer.new()
	win_margin.add_theme_constant_override("margin_left", 0)
	win_margin.add_theme_constant_override("margin_right", 0)
	win_margin.add_theme_constant_override("margin_top", -2)
	win_margin.add_theme_constant_override("margin_bottom", 0)
	win_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	win.add_child(win_margin)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 0)
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	win_margin.add_child(main_vbox)
	
	# Title bar stays outside the scaled container!
	var title_bar = PanelContainer.new()
	title_bar.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	title_bar.custom_minimum_size = Vector2(0, 30)
	main_vbox.add_child(title_bar)
	
	var title_margin = MarginContainer.new()
	title_margin.add_theme_constant_override("margin_bottom", 5)
	title_margin.add_theme_constant_override("margin_left", 12)
	title_margin.add_theme_constant_override("margin_right", 12)
	title_margin.add_theme_constant_override("margin_top", 8)
	title_bar.add_child(title_margin)
	
	var title_hbox = HBoxContainer.new()
	title_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	title_margin.add_child(title_hbox)
	
	var title_lbl = Label.new()
	title_lbl.text = " " + title
	title_lbl.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_lbl.clip_text = true
	title_hbox.add_child(title_lbl)

	var btn_hbox = HBoxContainer.new()
	btn_hbox.add_theme_constant_override("separation", 2)
	btn_hbox.alignment = BoxContainer.ALIGNMENT_END
	title_hbox.add_child(btn_hbox)
	
	var min_btn = _create_window_btn("-")
	min_btn.pressed.connect(func(): win.hide())
	btn_hbox.add_child(min_btn)
	
	# Only scale the area BELOW the title bar
	var scale_wrapper = Control.new()
	scale_wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scale_wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scale_wrapper.clip_contents = true
	main_vbox.add_child(scale_wrapper)
	
	var scale_root = Control.new()
	scale_wrapper.add_child(scale_root)
	
	# Liquid Glass Frame with Solid White Content BG
	var frame_margin = MarginContainer.new()
	frame_margin.add_theme_constant_override("margin_left", 4)
	frame_margin.add_theme_constant_override("margin_right", 4)
	frame_margin.add_theme_constant_override("margin_bottom", 4)
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
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_bg.add_child(margin)
	
	var parent = content.get_parent()
	if parent: parent.remove_child(content)
	
	content.set_anchors_preset(Control.PRESET_TOP_LEFT)
	content.position = Vector2.ZERO
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	margin.add_child(content)
	
	var dragging =[false]
	var drag_offset =[Vector2()]
	title_bar.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging[0] = true
				drag_offset[0] = event.global_position - win.global_position
			else:
				dragging[0] = false
		elif event is InputEventMouseMotion and dragging[0]:
			win.global_position = event.global_position - drag_offset[0]
	)
	
	_setup_window_resizing(win, base_min_size, scale_wrapper, scale_root, frame_margin)
	
	var task_btn = Button.new()
	task_btn.text = icon_text
	task_btn.custom_minimum_size = Vector2(100, 30)
	var tb_style = StyleBoxFlat.new()
	tb_style.bg_color = Color(0.85, 0.85, 0.85, 0)
	tb_style.corner_radius_top_left = 6; tb_style.corner_radius_top_right = 6
	tb_style.corner_radius_bottom_left = 6; tb_style.corner_radius_bottom_right = 6
	task_btn.add_theme_stylebox_override("normal", tb_style)
	task_btn.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
	task_btn.pressed.connect(func(): win.visible = !win.visible)
	taskbar_hbox.add_child(task_btn)
	
	return win

func _create_window_btn(txt: String) -> Button:
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

func _setup_window_resizing(win: Control, base_min: Vector2, scale_wrapper: Control, scale_root: Control, content_node: Control) -> void:
	var m = 12
	var configs =[[0, -1, Control.CURSOR_VSIZE],[0, 1, Control.CURSOR_VSIZE],[-1, 0, Control.CURSOR_HSIZE],[1, 0, Control.CURSOR_HSIZE],[-1, -1, Control.CURSOR_FDIAGSIZE],[1, -1, Control.CURSOR_BDIAGSIZE],[-1, 1, Control.CURSOR_BDIAGSIZE],[1, 1, Control.CURSOR_FDIAGSIZE]]
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
				var absolute_min = Vector2(80, 80)
				
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
		
		var target_x = max(1.0, base_min.x - 24.0)
		var target_y = max(1.0, base_min.y - 54.0)
		
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

func _setup_bottom_left_ui() -> void:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	
	currency_label = Label.new()
	currency_label.add_theme_font_size_override("font_size", 20)
	currency_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
	currency_label.text = "Byts: 0"
	vbox.add_child(currency_label)
	
	core_hp_label = Label.new()
	core_hp_label.add_theme_font_size_override("font_size", 24)
	core_hp_label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
	core_hp_label.text = "Core HP: ---"
	vbox.add_child(core_hp_label)
	
	respawns_label = Label.new()
	respawns_label.add_theme_font_size_override("font_size", 16)
	respawns_label.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))
	respawns_label.text = ""
	vbox.add_child(respawns_label)
	
	bottom_left_content = vbox
	_update_currency_ui()

func register_ally_respawn(a_name: String, time: float, lives_left: String = "") -> void:
	active_respawns.append({"name": a_name, "time": time, "lives": lives_left})

func _update_currency_ui() -> void:
	if currency_label:
		currency_label.text = "Byts: " + str(GameManager.get_currency())

func _setup_timer_ui() -> void:
	var panel = PanelContainer.new()
	panel.theme = global_theme
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	style.corner_radius_bottom_left = 8; style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", style)
	
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.position = Vector2(-80, 0)
	panel.custom_minimum_size = Vector2(160, 40)
	
	timer_label = Label.new()
	timer_label.add_theme_font_size_override("font_size", 24)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	timer_label.text = "Phase 1 - 00:00"
	panel.add_child(timer_label)
	
	add_child(panel)

func _on_time_updated(time_left: float, is_day: bool) -> void:
	if not timer_label: return
	var phase = GameManager.game_data.get("wave", 1)
	if is_day:
		var mins = int(time_left) / 60
		var secs = int(time_left) % 60
		timer_label.text = "Phase %d - %02d:%02d" %[phase, mins, secs]
		timer_label.add_theme_color_override("font_color", Color.WHITE)
	else:
		timer_label.text = "Phase %d - WAVE" % phase
		timer_label.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))

func _setup_shop_menu() -> void:
	shop_menu = ShopMenu.new()
	shop_menu.name = "ShopMenu"
	shop_menu.visible = false
	shop_menu.theme = global_theme
	add_child(shop_menu)
	shop_menu.closed.connect(_on_shop_closed)

func _on_shop_requested(wave_idx: int) -> void:
	close_all_menus()
	shop_menu.open(wave_idx)
	get_tree().paused = true

func _on_shop_closed() -> void:
	get_tree().paused = false
	GameManager.start_day_phase()

func _setup_dev_ui() -> void:
	dev_ui_panel = Panel.new()
	dev_ui_panel.name = "DevUI"
	dev_ui_panel.set_script(DEV_UI_SCRIPT)
	dev_ui_panel.custom_minimum_size = Vector2(220, 180)

func _process(delta: float) -> void:
	var backdrop = get_node_or_null("UIBackdrop")
	if backdrop:
		var any_open = is_any_menu_open() or is_pause_menu_open()
		backdrop.visible = any_open
		backdrop.mouse_filter = Control.MOUSE_FILTER_STOP if any_open else Control.MOUSE_FILTER_IGNORE

	if not is_instance_valid(_core_ref):
		_core_ref = get_tree().get_first_node_in_group("core")
	if is_instance_valid(_core_ref) and core_hp_label:
		if _core_ref.health_component:
			core_hp_label.text = "Core HP: %d / %d" %[_core_ref.health_component.current_health, _core_ref.health_component.max_health]
			
	if active_respawns.size() > 0:
		var respawn_text = ""
		for i in range(active_respawns.size() - 1, -1, -1):
			active_respawns[i].time -= delta
			if active_respawns[i].time <= 0:
				active_respawns.remove_at(i)
			else:
				respawn_text += "Respawning %s (Lives: %s): %.1fs\n" %[active_respawns[i].name, active_respawns[i].lives, active_respawns[i].time]
		if respawns_label:
			respawns_label.text = respawn_text
	elif respawns_label and respawns_label.text != "":
		respawns_label.text = ""

func _setup_context_menu() -> void:
	context_menu_panel = PanelContainer.new()
	context_menu_panel.name = "ContextMenu"
	context_menu_panel.visible = false
	context_menu_panel.theme = global_theme
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.border_width_left = 1; style.border_width_right = 1
	style.border_width_top = 1; style.border_width_bottom = 1
	style.border_color = Color(0.8, 0.8, 0.8, 0.6)
	style.corner_radius_top_left = 6; style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6; style.corner_radius_bottom_left = 6
	style.shadow_color = Color(0, 0, 0, 0.15)
	style.shadow_size = 8
	context_menu_panel.add_theme_stylebox_override("panel", style)
	
	add_child(context_menu_panel)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	context_menu_panel.add_child(margin)
	
	context_menu_vbox = VBoxContainer.new()
	context_menu_vbox.add_theme_constant_override("separation", 2)
	margin.add_child(context_menu_vbox)

func show_context_menu(screen_pos: Vector2, options: Array) -> void:
	hide_context_menu()
	if options.is_empty(): return
	
	if BuildManager.is_building: BuildManager.exit_build_mode()
	if PlayerManager.equipped_item: PlayerManager.set_equipped_item(null)
	
	for child in context_menu_vbox.get_children(): child.queue_free()
	
	for opt in options:
		var btn = Button.new()
		btn.text = opt.label
		btn.add_theme_color_override("font_color", Color.BLACK)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.flat = true
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.pressed.connect(func(): 
			opt.callback.call()
			hide_context_menu()
		)
		context_menu_vbox.add_child(btn)
	
	var cancel = Button.new()
	cancel.text = "Cancel"
	cancel.alignment = HORIZONTAL_ALIGNMENT_LEFT
	cancel.flat = true
	cancel.modulate = Color(1, 0.5, 0.5)
	cancel.pressed.connect(hide_context_menu)
	context_menu_vbox.add_child(HSeparator.new())
	context_menu_vbox.add_child(cancel)
	
	context_menu_panel.position = screen_pos
	context_menu_panel.visible = true

func hide_context_menu() -> void:
	context_menu_panel.visible = false

func _input(event: InputEvent) -> void:
	if context_menu_panel.visible:
		if event is InputEventMouseButton and event.pressed:
			if not context_menu_panel.get_global_rect().has_point(event.position):
				hide_context_menu()
		if event.is_action_pressed("ui_cancel"):
			hide_context_menu()

func _setup_pause_menu_instance() -> void:
	pause_menu = PAUSE_MENU_SCENE.instantiate()
	pause_menu.name = "PauseMenu"
	pause_menu.visible = false
	pause_menu.theme = global_theme
	add_child(pause_menu)
	pause_menu.resume_requested.connect(toggle_pause_menu)
	pause_menu.quit_requested.connect(func(): get_tree().quit())

func _setup_notification_label() -> void:
	notification_label = Label.new()
	notification_label.name = "NotificationLabel"
	notification_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	notification_label.add_theme_constant_override("shadow_offset_x", 1)
	notification_label.add_theme_constant_override("shadow_offset_y", 1)
	var font = load("res://assets/fonts/v2-fs-tahoma-8px.otf")
	if font:
		notification_label.add_theme_font_override("font", font)
	notification_label.add_theme_font_size_override("font_size", 24)
	notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notification_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	notification_label.modulate.a = 0.0
	add_child(notification_label)
	notification_label.anchors_preset = Control.PRESET_CENTER_BOTTOM
	notification_label.position = Vector2(0, -150)

func show_notification(text: String, color: Color = Color.WHITE) -> void:
	if not notification_label: return
	notification_label.text = text
	notification_label.modulate = color
	notification_label.modulate.a = 1.0
	
	var vp_size = get_viewport().get_visible_rect().size
	notification_label.position = Vector2((vp_size.x - notification_label.size.x) / 2.0, vp_size.y - 180)

	var tween = create_tween()
	tween.tween_property(notification_label, "position", notification_label.position - Vector2(0, 50), 1.5).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(notification_label, "modulate:a", 0.0, 1.5).set_delay(0.5)

func toggle_pause_menu() -> void:
	if pause_menu.visible:
		pause_menu.hide()
		get_tree().paused = false
	else:
		close_all_menus()
		pause_menu.show()
		pause_menu.focus_resume()
		get_tree().paused = true

func is_pause_menu_open() -> bool:
	return pause_menu.visible

func _setup_network_stats_ui() -> void:
	network_stats_panel = PanelContainer.new()
	network_stats_panel.name = "NetworkStats"
	network_stats_panel.visible = false
	network_stats_panel.theme = global_theme
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.05, 0.9)
	style.content_margin_left = 12; style.content_margin_right = 12
	style.content_margin_top = 12; style.content_margin_bottom = 12
	network_stats_panel.add_theme_stylebox_override("panel", style)
	add_child(network_stats_panel)
	network_stats_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	network_stats_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	network_stats_panel.position = Vector2(-20, 80)
	
	network_stats_label = RichTextLabel.new()
	network_stats_label.fit_content = true
	network_stats_label.bbcode_enabled = true
	network_stats_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	network_stats_panel.add_child(network_stats_label)

func show_network_stats(stats: Dictionary) -> void:
	if stats.is_empty():
		network_stats_panel.visible = false; return
	
	var status = stats.get("status", "Unknown")
	var status_col = "white"
	if status == "Stable": status_col = "green"
	elif status == "Overloaded": status_col = "red"
	elif status == "Unpowered": status_col = "yellow"

	var txt = "[right][b]Network Stats[/b][/right]\n[right]Status:[color=%s]%s[/color][/right]\n" %[status_col, status]
	txt += "[right]Gen: %.0f W | Dem: %.0f W[/right]" %[stats.get("total_generation", 0), stats.get("total_demand", 0)]
	network_stats_label.text = txt
	network_stats_panel.visible = true

func hide_network_stats() -> void:
	network_stats_panel.visible = false

func _spawn_world_drop_text(world_pos: Vector3, text: String, color: Color) -> void:
	var label = Label3D.new()
	label.text = text
	label.pixel_size = 0.02
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 100
	label.modulate = color
	
	var font = load("res://assets/fonts/v2-fs-tahoma-8px.otf")
	if font: label.font = font
	
	var root = get_tree().current_scene
	if root:
		root.add_child(label)
		label.global_position = world_pos + Vector3(0, 1.5, 0)
		
		var tween = label.create_tween()
		tween.tween_property(label, "global_position:y", label.global_position.y + 1.0, 1.0)
		tween.parallel().tween_property(label, "modulate:a", 0.0, 1.0)
		tween.tween_callback(label.queue_free)

func handle_world_drop(screen_pos: Vector2, data: Dictionary) -> void:
	var cam = get_viewport().get_camera_3d()
	if not cam: return
	
	var from = cam.project_ray_origin(screen_pos)
	var to = from + cam.project_ray_normal(screen_pos) * 1000.0
	var space = cam.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = space.intersect_ray(query)
	
	if result and result.collider:
		var target = result.collider
		var item = data.item
		var source_inv = data.inventory
		var count_to_add = data.count
		var spawn_pos = target.global_position
		
		if not source_inv.slots[data.slot_index] or source_inv.slots[data.slot_index].item != item: return

		if target.has_method("receive_item"):
			if target.receive_item(item):
				source_inv.remove_item(item, 1) 
				var taken = 1
				if count_to_add > 1:
					for i in range(count_to_add - 1):
						if not target.receive_item(item): break
						source_inv.remove_item(item, 1)
						taken += 1
				
				var i_name = "Item"
				if "item_name" in item: i_name = item.item_name
				elif "buildable_name" in item: i_name = item.buildable_name
				_spawn_world_drop_text(spawn_pos, "-%d %s" %[taken, i_name], Color.GREEN)
				return

		var inv_comp = target.get("inventory_component")
		if not inv_comp: inv_comp = target.get_node_or_null("InventoryComponent")
		
		if inv_comp and inv_comp.has_method("add_item") and inv_comp.has_space_for(item):
			var remainder = inv_comp.add_item(item, count_to_add)
			var taken = count_to_add - remainder
			if taken > 0:
				source_inv.remove_item(item, taken)
				var i_name = "Item"
				if "item_name" in item: i_name = item.item_name
				elif "buildable_name" in item: i_name = item.buildable_name
				_spawn_world_drop_text(spawn_pos, "-%d %s" %[taken, i_name], Color.GREEN)

func _initialize_recipe_database() -> void:
	var path = "res://resources/recipes/"
	if not DirAccess.dir_exists_absolute(path): return
	var dir = DirAccess.open(path)
	var recipes: Array[RecipeResource] =[]
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var res = load(path + file_name)
				if res is RecipeResource: recipes.append(res)
			file_name = dir.get_next()
		if is_instance_valid(GameManager): GameManager.register_recipes(recipes)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_inv"): 
		if is_pause_menu_open(): return
		toggle_player_menu()

func toggle_player_menu() -> void:
	if player_menu.visible: player_menu.hide()
	else:
		player_menu.show()
		if BuildManager.is_building: BuildManager.exit_build_mode()
		if PlayerManager.equipped_item: PlayerManager.set_equipped_item(null)

func set_debug_text(text: String) -> void:
	if debug_coords_label: debug_coords_label.text = text

func open_inventory(inventory: InventoryComponent, title: String = "Storage", context: Object = null) -> void:
	if inventory_gui:
		inventory_gui.open(inventory, title, context)
		if BuildManager.is_building: BuildManager.exit_build_mode()
		if PlayerManager.equipped_item: PlayerManager.set_equipped_item(null)

func close_inventory() -> void:
	if inventory_gui: inventory_gui.close()

func set_inventory_screen_position(_screen_pos: Vector2) -> void: pass 

func get_ui_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if hotbar: rects.append(hotbar.get_global_rect())
	if dev_ui_panel: rects.append(dev_ui_panel.get_global_rect())
	if inventory_gui and inventory_gui.visible: rects.append(inventory_gui.get_global_rect())
	if player_menu and player_menu.visible:
		if player_menu.window_root: rects.append(player_menu.window_root.get_global_rect())
	if context_menu_panel and context_menu_panel.visible: rects.append(context_menu_panel.get_global_rect())
	if shop_menu and shop_menu.visible and shop_menu.panel: rects.append(shop_menu.panel.get_global_rect())
	return rects

func is_any_menu_open() -> bool:
	if player_menu and player_menu.visible: return true
	if inventory_gui and inventory_gui.visible: return true
	if shop_menu and shop_menu.visible: return true
	return false

func close_all_menus() -> void:
	if player_menu: player_menu.hide()
	hide_context_menu()
	close_inventory()

func set_selected_ally(ally: Node) -> void:
	if player_menu: player_menu.set_current_ally(ally)

