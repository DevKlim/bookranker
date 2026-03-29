class_name PlayerMenu
extends Control

var positioning_layer: Control
var window_root: Control
var main_panel: PanelContainer
var details_panel: PanelContainer
var tabs: TabContainer
var mode_button: Button
var player_grid: GridContainer
var items_grid: GridContainer
var buildings_grid: GridContainer
var crafting_grid: GridContainer 
var mods_grid: GridContainer

# Core Tab UI
var core_tab: Control
var core_mods_grid: GridContainer
var core_stats_label: RichTextLabel

# Ally Specific UI
var ally_tab: Control
var ally_split: HBoxContainer
var ally_stats_label: RichTextLabel
var ally_equip_grid: GridContainer
var ally_backpack_grid: GridContainer

var craft_tab: Control
var build_tab: Control
var item_tab: Control
var mod_tab: Control

var details_content: VBoxContainer
var details_title: Label
var details_icon: TextureRect
var details_ingredients_grid: GridContainer
var craft_button: Button
var craft_progress: ProgressBar
var selected_recipe: RecipeResource = null

var current_ally: Node = null 
var all_items: Array[ItemResource] =[]
var all_mods: Array[ItemResource] =[]
var all_buildings: Array[BuildableResource] =[]
var basic_recipes: Array[RecipeResource] =[]

var dragging: bool = false
var drag_offset: Vector2

var d_dragging: bool = false
var d_drag_offset: Vector2

class CraftingButton extends Button:
	var recipe: RecipeResource
	func _make_custom_tooltip(_for_text: String) -> Object:
		var panel = PanelContainer.new()
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.9, 0.9, 0.9, 0.9)
		style.content_margin_left=8; style.content_margin_right=8; style.content_margin_top=8; style.content_margin_bottom=8
		panel.add_theme_stylebox_override("panel", style)
		var vbox = VBoxContainer.new(); panel.add_child(vbox)
		var label = Label.new(); label.text = recipe.recipe_name; label.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2)); vbox.add_child(label)
		return panel

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
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS 
	_build_ui_structure()
	_load_resources()
	mode_button.pressed.connect(_on_mode_toggle)
	PlayerManager.mode_changed.connect(_on_mode_changed)
	
	call_deferred("_setup_inventory_connections")

func _setup_inventory_connections() -> void:
	if PlayerManager.game_inventory:
		PlayerManager.game_inventory.inventory_changed.connect(_update_player_inventory)
		PlayerManager.game_inventory.inventory_changed.connect(_update_crafting_ui)
		_update_player_inventory()
	
	if PlayerManager.crafter:
		PlayerManager.crafter.progress_changed.connect(_on_craft_progress)
		PlayerManager.crafter.craft_started.connect(_on_craft_state_changed)
		PlayerManager.crafter.craft_finished.connect(_on_craft_state_changed)
	
	_on_mode_changed(PlayerManager.is_creative_mode)
	
	call_deferred("_update_tabs_visibility")
	
	var vp_size = get_viewport_rect().size
	var p_size = window_root.size
	if p_size.x <= 10: p_size = Vector2(950, 600)
	window_root.position = (vp_size - p_size) / 2.0

func _process(_delta: float) -> void:
	if not visible or not is_instance_valid(current_ally): return
	if tabs.current_tab >= 0 and tabs.current_tab < tabs.get_child_count():
		if tabs.get_child(tabs.current_tab) == ally_tab:
			_rebuild_ally_tab()

func _build_ui_structure() -> void:
	for c in get_children(): c.queue_free()
	
	positioning_layer = Control.new()
	positioning_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	positioning_layer.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(positioning_layer)
	
	window_root = Control.new()
	window_root.size = Vector2(950, 600)
	window_root.clip_contents = true
	positioning_layer.add_child(window_root)
	
	main_panel = PanelContainer.new()
	main_panel.name = "MainPanel"
	main_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_panel.clip_contents = true
	
	_apply_liquid_glass(main_panel, 12.0)
	window_root.add_child(main_panel)
	
	var main_margin = MarginContainer.new()
	main_margin.add_theme_constant_override("margin_left", 4)
	main_margin.add_theme_constant_override("margin_right", 4)
	main_margin.add_theme_constant_override("margin_top", -2)
	main_margin.add_theme_constant_override("margin_bottom", 4)
	main_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_panel.add_child(main_margin)
	
	var wrapper_vbox = VBoxContainer.new()
	wrapper_vbox.add_theme_constant_override("separation", 0)
	main_margin.add_child(wrapper_vbox)
	
	var title_bar = PanelContainer.new()
	title_bar.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	title_bar.custom_minimum_size = Vector2(0, 30)
	title_bar.gui_input.connect(_on_title_gui_input)
	wrapper_vbox.add_child(title_bar)
	
	var title_margin = MarginContainer.new()
	title_margin.add_theme_constant_override("margin_bottom", 5)
	title_margin.add_theme_constant_override("margin_top", 10)
	title_margin.add_theme_constant_override("margin_left", 12)
	title_margin.add_theme_constant_override("margin_right", 12)
	title_bar.add_child(title_margin)
	
	var title_hbox = HBoxContainer.new()
	title_margin.add_child(title_hbox)
	
	var title_lbl = Label.new()
	title_lbl.text = "  Player Menu"
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
	
	var min_btn = _create_xp_btn("X")
	min_btn.pressed.connect(func(): hide())
	btn_hbox.add_child(min_btn)
	
	var scale_wrapper = Control.new()
	scale_wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scale_wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scale_wrapper.clip_contents = true
	wrapper_vbox.add_child(scale_wrapper)
	
	var scale_root = Control.new()
	scale_wrapper.add_child(scale_root)
	
	var frame_margin = MarginContainer.new()
	frame_margin.add_theme_constant_override("margin_left", 4)
	frame_margin.add_theme_constant_override("margin_right", 4)
	frame_margin.add_theme_constant_override("margin_bottom", 4)
	frame_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	content_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frame_margin.add_child(content_bg)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20); margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20); margin.add_theme_constant_override("margin_bottom", 20)
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_bg.add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(vbox)
	
	var header = HBoxContainer.new()
	vbox.add_child(header)
	mode_button = Button.new(); mode_button.text = "Normal"; mode_button.focus_mode = Control.FOCUS_NONE
	var mb_style = StyleBoxFlat.new()
	mb_style.bg_color = Color(0.75, 0.75, 0.75, 0.5)
	mb_style.corner_radius_top_left = 4; mb_style.corner_radius_top_right = 4
	mb_style.corner_radius_bottom_left = 4; mb_style.corner_radius_bottom_right = 4
	mode_button.add_theme_stylebox_override("normal", mb_style)
	mode_button.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	header.add_child(mode_button)
	
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	var tab_bg = StyleBoxFlat.new()
	tab_bg.bg_color = Color.TRANSPARENT
	tab_bg.content_margin_left = 16; tab_bg.content_margin_right = 16
	tab_bg.content_margin_top = 8; tab_bg.content_margin_bottom = 8
	tab_bg.expand_margin_bottom = 0
	
	var tab_fg = StyleBoxFlat.new()
	tab_fg.bg_color = Color(0.95, 0.95, 0.95, 0.6)
	tab_fg.content_margin_left = 16; tab_fg.content_margin_right = 16
	tab_fg.content_margin_top = 8; tab_fg.content_margin_bottom = 8
	tab_fg.corner_radius_top_left = 6; tab_fg.corner_radius_top_right = 6
	tab_fg.expand_margin_bottom = 0
	
	tabs.add_theme_stylebox_override("tab_unselected", tab_bg)
	tabs.add_theme_stylebox_override("tab_selected", tab_fg)
	tabs.add_theme_stylebox_override("tab_hovered", tab_fg)
	tabs.add_theme_stylebox_override("panel", tab_fg)
	tabs.add_theme_color_override("font_selected_color", Color(0.1, 0.1, 0.1))
	tabs.add_theme_color_override("font_unselected_color", Color(0.4, 0.4, 0.4))
	
	vbox.add_child(tabs)
	
	craft_tab = _create_grid_tab("Crafting"); crafting_grid = craft_tab.get_node("Scroll/Grid")
	build_tab = _create_grid_tab("Buildings"); buildings_grid = build_tab.get_node("Scroll/Grid")
	item_tab = _create_grid_tab("Items"); items_grid = item_tab.get_node("Scroll/Grid")
	mod_tab = _create_grid_tab("Mods"); mods_grid = mod_tab.get_node("Scroll/Grid")
	
	core_tab = MarginContainer.new()
	core_tab.name = "Core"
	core_tab.add_theme_constant_override("margin_left", 10); core_tab.add_theme_constant_override("margin_right", 10)
	core_tab.add_theme_constant_override("margin_top", 10); core_tab.add_theme_constant_override("margin_bottom", 10)
	var core_vbox = VBoxContainer.new()
	core_tab.add_child(core_vbox)
	
	core_stats_label = RichTextLabel.new()
	core_stats_label.bbcode_enabled = true
	core_stats_label.fit_content = true
	core_vbox.add_child(core_stats_label)
	
	core_vbox.add_child(HSeparator.new())
	var cmod_lbl = Label.new(); cmod_lbl.text = "Core Mod Slots"; cmod_lbl.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
	core_vbox.add_child(cmod_lbl)
	
	core_mods_grid = GridContainer.new()
	core_mods_grid.columns = 3
	core_mods_grid.add_theme_constant_override("h_separation", 6); core_mods_grid.add_theme_constant_override("v_separation", 6)
	core_vbox.add_child(core_mods_grid)

	# Custom Ally Tab
	ally_tab = MarginContainer.new()
	ally_tab.name = "Ally"
	ally_tab.add_theme_constant_override("margin_left", 10); ally_tab.add_theme_constant_override("margin_right", 10)
	ally_tab.add_theme_constant_override("margin_top", 10); ally_tab.add_theme_constant_override("margin_bottom", 10)
	
	ally_split = HBoxContainer.new()
	ally_split.add_theme_constant_override("separation", 20)
	ally_tab.add_child(ally_split)
	
	var ally_left = VBoxContainer.new()
	ally_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ally_split.add_child(ally_left)
	
	ally_stats_label = RichTextLabel.new()
	ally_stats_label.bbcode_enabled = true
	ally_stats_label.fit_content = true
	ally_stats_label.text = "[color=black][b]Stats[/b][/color]"
	ally_left.add_child(ally_stats_label)
	
	ally_left.add_child(HSeparator.new())
	var eq_lbl = Label.new(); eq_lbl.text = "Equipment"; eq_lbl.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
	ally_left.add_child(eq_lbl)
	
	ally_equip_grid = GridContainer.new()
	ally_equip_grid.columns = 2
	ally_equip_grid.add_theme_constant_override("h_separation", 6); ally_equip_grid.add_theme_constant_override("v_separation", 6)
	ally_left.add_child(ally_equip_grid)

	var ally_right = VBoxContainer.new()
	ally_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ally_right.size_flags_stretch_ratio = 1.5
	ally_split.add_child(ally_right)
	
	var pack_lbl = Label.new(); pack_lbl.text = "Inventory"; pack_lbl.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
	ally_right.add_child(pack_lbl)
	
	var pack_scroll = ScrollContainer.new()
	pack_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ally_right.add_child(pack_scroll)
	
	ally_backpack_grid = GridContainer.new()
	ally_backpack_grid.columns = 5
	ally_backpack_grid.add_theme_constant_override("h_separation", 4); ally_backpack_grid.add_theme_constant_override("v_separation", 4)
	pack_scroll.add_child(ally_backpack_grid)
	
	vbox.add_child(HSeparator.new())
	var b_lbl = Label.new(); b_lbl.text = "Player Hotbar & Backpack"; b_lbl.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
	vbox.add_child(b_lbl)
	var p_scroll = ScrollContainer.new(); p_scroll.custom_minimum_size = Vector2(0, 180); vbox.add_child(p_scroll)
	player_grid = GridContainer.new(); player_grid.columns = 10
	player_grid.add_theme_constant_override("h_separation", 4); player_grid.add_theme_constant_override("v_separation", 4)
	p_scroll.add_child(player_grid)
	
	details_panel = PanelContainer.new()
	details_panel.name = "DetailsPanel"
	details_panel.size = Vector2(300, 600)
	details_panel.visible = false
	details_panel.clip_contents = true
	_apply_liquid_glass(details_panel, 12.0)
	positioning_layer.add_child(details_panel)
	
	var det_margin = MarginContainer.new()
	det_margin.add_theme_constant_override("margin_left", 4)
	det_margin.add_theme_constant_override("margin_top", -2)
	det_margin.add_theme_constant_override("margin_right", 4)
	det_margin.add_theme_constant_override("margin_bottom", 4)
	det_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	details_panel.add_child(det_margin)
	
	var d_vbox = VBoxContainer.new()
	d_vbox.add_theme_constant_override("separation", 0)
	det_margin.add_child(d_vbox)
	
	var d_title_bar = PanelContainer.new()
	d_title_bar.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	d_title_bar.custom_minimum_size = Vector2(0, 30)
	d_title_bar.gui_input.connect(_on_d_title_gui_input)
	d_vbox.add_child(d_title_bar)
	
	var d_title_margin = MarginContainer.new()
	d_title_margin.add_theme_constant_override("margin_top", 10)
	d_title_margin.add_theme_constant_override("margin_bottom", 5)
	d_title_margin.add_theme_constant_override("margin_left", 12)
	d_title_margin.add_theme_constant_override("margin_right", 12)
	d_title_bar.add_child(d_title_margin)
	
	var d_title_hbox = HBoxContainer.new()
	d_title_margin.add_child(d_title_hbox)
	
	var d_title_lbl = Label.new()
	d_title_lbl.text = " Recipe Details"
	d_title_lbl.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	d_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	d_title_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	d_title_lbl.clip_text = true
	d_title_hbox.add_child(d_title_lbl)
	
	var d_close_btn = _create_xp_btn("X")
	d_close_btn.pressed.connect(func(): details_panel.hide())
	d_title_hbox.add_child(d_close_btn)
	
	var d_scale_wrapper = Control.new()
	d_scale_wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	d_scale_wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	d_scale_wrapper.clip_contents = true
	d_vbox.add_child(d_scale_wrapper)
	
	var d_scale_root = Control.new()
	d_scale_wrapper.add_child(d_scale_root)
	
	var d_frame_margin = MarginContainer.new()
	d_frame_margin.add_theme_constant_override("margin_left", 0)
	d_frame_margin.add_theme_constant_override("margin_right", 0)
	d_frame_margin.add_theme_constant_override("margin_bottom", 0)
	d_frame_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	d_frame_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	d_scale_root.add_child(d_frame_margin)
	
	var d_content_bg = PanelContainer.new()
	var d_cbg_style = StyleBoxFlat.new()
	d_cbg_style.bg_color = Color.WHITE
	d_cbg_style.corner_radius_bottom_left = 6
	d_cbg_style.corner_radius_bottom_right = 6
	d_cbg_style.corner_radius_top_left = 6
	d_cbg_style.corner_radius_top_right = 6
	d_content_bg.add_theme_stylebox_override("panel", d_cbg_style)
	d_content_bg.size_flags_vertical = Control.SIZE_EXPAND_FILL
	d_content_bg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	d_frame_margin.add_child(d_content_bg)
	
	var d_margin = MarginContainer.new()
	d_margin.add_theme_constant_override("margin_left", 20); d_margin.add_theme_constant_override("margin_right", 20)
	d_margin.add_theme_constant_override("margin_top", 20); d_margin.add_theme_constant_override("margin_bottom", 20)
	d_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	d_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	d_content_bg.add_child(d_margin)
	
	details_content = VBoxContainer.new()
	details_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	d_margin.add_child(details_content)
	
	details_title = Label.new(); details_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; details_title.add_theme_font_size_override("font_size", 22)
	details_title.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
	details_content.add_child(details_title)
	
	var c_icon = CenterContainer.new(); details_content.add_child(c_icon)
	var i_panel = Panel.new(); i_panel.custom_minimum_size = Vector2(80, 80); c_icon.add_child(i_panel)
	var center2 = CenterContainer.new(); center2.set_anchors_preset(Control.PRESET_FULL_RECT); i_panel.add_child(center2)
	
	details_icon = TextureRect.new()
	details_icon.custom_minimum_size = Vector2(64, 64)
	details_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	details_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	details_icon.texture_filter = Control.TEXTURE_FILTER_NEAREST
	center2.add_child(details_icon)
	
	var spacer = Control.new(); spacer.custom_minimum_size = Vector2(0, 20); details_content.add_child(spacer)
	var req_l = Label.new(); req_l.text = "Requirements:"; req_l.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
	details_content.add_child(req_l)
	var i_scroll = ScrollContainer.new(); i_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; details_content.add_child(i_scroll)
	details_ingredients_grid = GridContainer.new(); details_ingredients_grid.columns = 1; i_scroll.add_child(details_ingredients_grid)
	craft_progress = ProgressBar.new(); craft_progress.visible = false; details_content.add_child(craft_progress)
	craft_button = Button.new(); craft_button.text = "Craft"; craft_button.custom_minimum_size = Vector2(0, 40)
	craft_button.add_theme_color_override("font_color", Color.BLACK)
	craft_button.pressed.connect(_on_craft_button_pressed); details_content.add_child(craft_button)

	_setup_window_resizing(window_root, scale_wrapper, scale_root, frame_margin, 950, 600)
	_setup_window_resizing(details_panel, d_scale_wrapper, d_scale_root, d_frame_margin, 300, 600)

func _setup_window_resizing(win: Control, scale_wrapper: Control, scale_root: Control, content_node: Control, target_w: float, target_h: float) -> void:
	var m = 12
	var configs = [[0, -1, Control.CURSOR_VSIZE],[0, 1, Control.CURSOR_VSIZE],[-1, 0, Control.CURSOR_HSIZE],[1, 0, Control.CURSOR_HSIZE],[-1, -1, Control.CURSOR_FDIAGSIZE],[1, -1, Control.CURSOR_BDIAGSIZE],[-1, 1, Control.CURSOR_BDIAGSIZE],[1, 1, Control.CURSOR_FDIAGSIZE]]
	
	var handles =[]
	var sync_ref =[]
	
	var update_scale = func():
		var c_size = scale_wrapper.size
		if c_size.x < 1 or c_size.y < 1: return
		
		var target_x = max(1.0, target_w - 24.0)
		var target_y = max(1.0, target_h - 54.0)
		
		var s = min(1.0, min(c_size.x / target_x, c_size.y / target_y))
		if s >= 0.99:
			s = 1.0
			
		scale_root.scale = Vector2(s, s)
		content_node.size = (c_size / s).ceil()
		content_node.position = Vector2.ZERO
		
	scale_wrapper.item_rect_changed.connect(update_scale)
	
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
				var absolute_min = Vector2(100, 100)
				
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
	
	var update_vis = func():
		var is_vis = win.is_visible_in_tree()
		for h in handles:
			if is_instance_valid(h.node):
				h.node.visible = is_vis
		if is_vis:
			if win.is_inside_tree():
				await win.get_tree().process_frame
				await win.get_tree().process_frame
			if is_instance_valid(win):
				win.emit_signal("resized")
			if is_instance_valid(scale_wrapper):
				scale_wrapper.emit_signal("item_rect_changed")

	win.visibility_changed.connect(update_vis)
	if win != self:
		self.visibility_changed.connect(update_vis)
		
	update_vis.call()

func _on_title_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = true
				drag_offset = event.global_position - window_root.global_position
			else:
				dragging = false
	elif event is InputEventMouseMotion and dragging:
		window_root.global_position = event.global_position - drag_offset

func _on_d_title_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				d_dragging = true
				d_drag_offset = event.global_position - details_panel.global_position
			else:
				d_dragging = false
	elif event is InputEventMouseMotion and d_dragging:
		details_panel.global_position = event.global_position - d_drag_offset

func set_current_ally(ally: Node) -> void:
	if current_ally == ally: return
	if current_ally:
		var inv = _get_ally_inventory(current_ally)
		if inv and inv.is_connected("inventory_changed", _update_ally_grid):
			inv.inventory_changed.disconnect(_update_ally_grid)
	current_ally = ally
	if current_ally:
		var inv = _get_ally_inventory(current_ally)
		if inv and not inv.is_connected("inventory_changed", _update_ally_grid):
			inv.inventory_changed.connect(_update_ally_grid)
		_rebuild_ally_tab()
		_update_ally_grid()
	_update_tabs_visibility()

func _get_ally_inventory(ally: Node) -> InventoryComponent:
	if not is_instance_valid(ally): return null
	if "inventory_component" in ally: return ally.inventory_component
	if ally.get("inventory_component"): return ally.get("inventory_component")
	return null

func _rebuild_ally_tab(arg1 = null, arg2 = null) -> void:
	if not current_ally: return
	var hp = 0; var mhp = 0; var spd = 0
	if current_ally.has_node("HealthComponent"):
		var hc = current_ally.get_node("HealthComponent")
		hp = hc.current_health; mhp = hc.max_health
	if current_ally.get("move_component"):
		spd = current_ally.move_component.move_speed
	elif current_ally.has_node("MoveComponent"):
		spd = current_ally.get_node("MoveComponent").move_speed
	
	var inv = _get_ally_inventory(current_ally)
	var slots_used = 0
	if inv: for s in inv.slots: if s: slots_used += 1
	var max_s = inv.max_slots if inv else 0
	
	var name_str = "Ally"
	if "display_name" in current_ally: name_str = current_ally.display_name
	elif "ally_name" in current_ally: name_str = current_ally.ally_name
	
	ally_tab.name = name_str
	ally_stats_label.text = "[color=black][b][font_size=20]%s[/font_size][/b]\n\n" % name_str
	ally_stats_label.text += "[color=#aa0000]Health:[/color] %d / %d\n" %[int(hp), int(mhp)]
	ally_stats_label.text += "[color=#00aa00]Speed:[/color] %.1f\n" % spd
	ally_stats_label.text += "[color=#0000aa]Load:[/color] %d / %d slots[/color]" %[slots_used, max_s]

func _update_tabs_visibility() -> void:
	if not is_inside_tree(): return
	var prev_tab_idx = tabs.current_tab
	var prev_tab_ctrl = null
	if prev_tab_idx >= 0 and prev_tab_idx < tabs.get_child_count():
		prev_tab_ctrl = tabs.get_child(prev_tab_idx)
	
	for c in tabs.get_children(): tabs.remove_child(c)
	
	tabs.add_child(craft_tab)
	tabs.add_child(core_tab)
	_update_core_tab()
	
	if PlayerManager.is_creative_mode:
		tabs.add_child(build_tab)
		tabs.add_child(item_tab)
		tabs.add_child(mod_tab)
	if current_ally:
		tabs.add_child(ally_tab)
		tabs.current_tab = tabs.get_child_count() - 1
		return
	
	if prev_tab_ctrl and prev_tab_ctrl.get_parent() == tabs:
		var idx = tabs.get_children().find(prev_tab_ctrl)
		tabs.current_tab = idx
	else:
		tabs.current_tab = 0

func _update_core_tab() -> void:
	var core_node = get_tree().get_first_node_in_group("core")
	if not core_node: 
		core_stats_label.text = "[color=black]Core not found.[/color]"
		_clear(core_mods_grid)
		return
	
	var hp = core_node.health_component.current_health if core_node.health_component else 0
	var mhp = core_node.health_component.max_health if core_node.health_component else 0
	var gen = core_node.power_provider.power_generation if core_node.power_provider else 0
	
	core_stats_label.text = "[color=black][b][font_size=20]Core Systems[/font_size][/b]\n\n"
	core_stats_label.text += "[color=#aa0000]Health:[/color] %d / %d\n" %[int(hp), int(mhp)]
	core_stats_label.text += "[color=#aaaa00]Power Gen:[/color] %d W\n[/color]" % int(gen)
	
	_clear(core_mods_grid)
	if core_node.mod_inventory:
		if not core_node.mod_inventory.is_connected("inventory_changed", _update_core_tab):
			core_node.mod_inventory.inventory_changed.connect(_update_core_tab)
		for i in range(core_node.mod_inventory.slots.size()):
			var b = _create_slot_button(core_node.mod_inventory, i)
			if core_node.mod_inventory.slots[i] == null:
				var l = Label.new()
				l.text = "MOD"
				l.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2, 0.4))
				l.set_anchors_preset(Control.PRESET_CENTER)
				b.add_child(l)
				b.modulate = Color(1,1,1,0.8)
			else:
				b.modulate = Color(0.8, 1.0, 1.0)
			core_mods_grid.add_child(b)

func _create_grid_tab(name: String) -> Control:
	var m = MarginContainer.new()
	m.name = name
	m.add_theme_constant_override("margin_left", 10); m.add_theme_constant_override("margin_right", 10)
	m.add_theme_constant_override("margin_top", 10); m.add_theme_constant_override("margin_bottom", 10)
	var s = ScrollContainer.new(); s.name = "Scroll"; m.add_child(s)
	
	s.set_drag_forwarding(Callable(), Callable(self, "_can_drop_trash"), Callable(self, "_drop_trash"))
	
	var g = GridContainer.new(); g.name = "Grid"; g.columns = 8; g.add_theme_constant_override("h_separation", 6); g.add_theme_constant_override("v_separation", 6); s.add_child(g)
	return m

func _load_resources() -> void:
	var load_all = func(path, arr, type):
		var dir = DirAccess.open(path)
		if dir:
			dir.list_dir_begin(); var f = dir.get_next()
			while f != "":
				if f.ends_with(".tres"):
					var res = load(path + f)
					if is_instance_of(res, type): arr.append(res)
				f = dir.get_next()
	load_all.call("res://resources/items/", all_items, ItemResource)
	load_all.call("res://resources/buildables/", all_buildings, BuildableResource)
	load_all.call("res://resources/mods/", all_mods, ItemResource)
	if GameManager.has_method("get_available_recipes"):
		for r in GameManager.get_available_recipes():
			if r.category == "basic": basic_recipes.append(r)

func _on_mode_toggle() -> void: PlayerManager.is_creative_mode = !PlayerManager.is_creative_mode
func _on_mode_changed(creative: bool) -> void:
	mode_button.text = "Mode: Creative" if creative else "Mode: Normal"
	if creative:
		details_panel.visible = false; selected_recipe = null
	_populate_grids()
	_update_tabs_visibility()

func _populate_grids() -> void:
	_clear(crafting_grid)
	for r in basic_recipes: crafting_grid.add_child(_create_craft_btn(r))
	_clear(items_grid); _clear(buildings_grid); _clear(mods_grid)
	if PlayerManager.is_creative_mode:
		for i in all_items: items_grid.add_child(_create_res_btn(i))
		for b in all_buildings: buildings_grid.add_child(_create_res_btn(b))
		for m in all_mods: mods_grid.add_child(_create_res_btn(m))

func _create_craft_btn(r: RecipeResource) -> Button:
	var b = CraftingButton.new()
	b.recipe = r
	b.custom_minimum_size = Vector2(64, 64)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	var out = r.get_main_output()
	if out and out.get("icon"):
		var center = CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(center)

		var tr = TextureRect.new()
		tr.texture = out.icon
		tr.custom_minimum_size = Vector2(64, 64)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = Control.TEXTURE_FILTER_NEAREST
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(tr)
		
	b.pressed.connect(func(): _select_recipe(r))
	return b

func _select_recipe(r: RecipeResource) -> void:
	selected_recipe = r
	if not details_panel.visible:
		details_panel.global_position = window_root.global_position + Vector2(window_root.size.x + 10, 0)
		details_panel.size = Vector2(300, window_root.size.y)
	details_panel.visible = true
	var out = r.get_main_output()
	if out:
		details_title.text = out.get("item_name") if "item_name" in out else out.get("buildable_name")
		if out.get("icon"): details_icon.texture = out.icon
	_clear(details_ingredients_grid)
	for entry in r.inputs:
		var hb = HBoxContainer.new()
		var ic = TextureRect.new()
		ic.custom_minimum_size = Vector2(32, 32)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture_filter = Control.TEXTURE_FILTER_NEAREST
		if entry.resource.get("icon"): ic.texture = entry.resource.icon
		hb.add_child(ic)
		var lb = Label.new()
		var n = entry.resource.get("item_name") if "item_name" in entry.resource else entry.resource.get("buildable_name")
		lb.text = "%dx %s" %[entry.count, n]
		lb.add_theme_color_override("font_color", Color.BLACK)
		hb.add_child(lb)
		details_ingredients_grid.add_child(hb)
	_update_crafting_ui()

func _update_crafting_ui(_arg=null) -> void:
	if not selected_recipe or PlayerManager.is_creative_mode: return
	var can = PlayerManager.game_inventory.has_ingredients_for(selected_recipe)
	var busy = PlayerManager.crafter.is_busy()
	craft_button.disabled = !can or busy
	craft_button.text = "Crafting..." if busy else ("Craft" if can else "Need Mats")
	craft_progress.visible = busy

func _on_craft_button_pressed() -> void:
	if selected_recipe: PlayerManager.request_craft(selected_recipe); _update_crafting_ui()
func _on_craft_progress(v): craft_progress.value = v * 100
func _on_craft_state_changed(_r): _update_crafting_ui()

func _update_player_inventory() -> void:
	_clear(player_grid)
	var slots = PlayerManager.game_inventory.slots
	for i in range(slots.size()):
		var btn = _create_slot_btn_base()
		_fill_slot_btn(btn, slots[i])
		if slots[i]:
			btn.set_drag_forwarding(Callable(self, "_drag_inv").bind(i), Callable(self, "_can_drop"), Callable(self, "_drop_inv").bind(i))
		else:
			btn.set_drag_forwarding(Callable(), Callable(self, "_can_drop"), Callable(self, "_drop_inv").bind(i))
		player_grid.add_child(btn)

func _update_ally_grid(_arg=null):
	_clear(ally_equip_grid)
	_clear(ally_backpack_grid)
	if not current_ally: return
	var inv = _get_ally_inventory(current_ally)
	if not inv: return
	
	var res = current_ally.stats if "stats" in current_ally else null
	var has_tool = res.has_tool_slot if res else true
	var has_weap = res.has_weapon_slot if res else true
	var has_arm = res.has_armor_slot if res else true
	var has_art = res.has_artifact_slot if res else true
	
	for i in range(4):
		var show = false
		var label_txt = ""
		match i:
			0: show = has_tool; label_txt = "TL"
			1: show = has_weap; label_txt = "WP"
			2: show = has_arm; label_txt = "AR"
			3: show = has_art; label_txt = "AT"
		
		if show:
			var b = _create_slot_button(inv, i)
			if inv.slots[i] == null:
				var l = Label.new()
				l.text = label_txt
				l.add_theme_color_override("font_color", Color(0.2,0.2,0.2,0.4))
				l.set_anchors_preset(Control.PRESET_CENTER)
				b.add_child(l)
				b.modulate = Color(1,1,1,0.8)
			else:
				b.modulate = Color(0.8, 1.0, 1.0)
			ally_equip_grid.add_child(b)
	
	for i in range(4, inv.slots.size()):
		var b = _create_slot_button(inv, i)
		ally_backpack_grid.add_child(b)

func _create_slot_btn_base() -> Button:
	var b = Button.new()
	b.custom_minimum_size = Vector2(64, 64)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	var center = CenterContainer.new()
	center.name = "IconCenter"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(center)
	return b

func _fill_slot_btn(b: Button, slot_data):
	if slot_data:
		var it = slot_data.item
		if "item_name" in it:
			b.tooltip_text = it.item_name
		elif "buildable_name" in it:
			b.tooltip_text = it.buildable_name
		
		var tr = TextureRect.new()
		tr.texture = it.icon
		tr.custom_minimum_size = Vector2(64, 64)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = Control.TEXTURE_FILTER_NEAREST
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		var center = b.get_node("IconCenter")
		if center:
			center.add_child(tr)
		
		var l = Label.new()
		l.text = str(slot_data.count)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		l.offset_right = 4
		l.offset_bottom = 2
		var font = load("res://assets/fonts/v2-fs-tahoma-8px.otf")
		if font:
			l.add_theme_font_override("font", font)
		l.add_theme_font_size_override("font_size", 16)
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", 4)
		b.add_child(l)

func _create_slot_button(inv, i) -> Button:
	var b = _create_slot_btn_base()
	_fill_slot_btn(b, inv.slots[i])
	b.set_drag_forwarding(Callable(self, "_drag_ally").bind(inv, i), Callable(self, "_can_drop_ally").bind(inv, i), Callable(self, "_drop_ally").bind(inv, i))
	return b

func _create_res_btn(res):
	var b = Button.new()
	b.custom_minimum_size = Vector2(64, 64)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	if res.get("icon"): 
		var center = CenterContainer.new()
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(center)
		
		var tr = TextureRect.new()
		tr.texture = res.icon
		tr.custom_minimum_size = Vector2(64, 64)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = Control.TEXTURE_FILTER_NEAREST
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(tr)
		
	if "item_name" in res: b.tooltip_text = res.item_name
	elif "buildable_name" in res: b.tooltip_text = res.buildable_name
	elif "ally_name" in res: b.tooltip_text = res.ally_name
	
	b.gui_input.connect(_on_res_btn_input.bind(res))
	b.set_drag_forwarding(Callable(self, "_drag_create").bind(res), Callable(self, "_can_drop_trash"), Callable(self, "_drop_trash"))
	return b

func _on_res_btn_input(event: InputEvent, res: Resource):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var stack = 64
			if res is ItemResource: stack = res.stack_size
			PlayerManager.game_inventory.add_item(res, stack)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			PlayerManager.game_inventory.add_item(res, 1)

func _clear(p): for c in p.get_children(): c.queue_free()

func _drag_create(_p, r): 
	var t = TextureRect.new()
	t.texture = r.icon
	t.size = Vector2(64, 64)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = Control.TEXTURE_FILTER_NEAREST
	set_drag_preview(t)
	return { "type": "creative_spawn", "resource": r }

func _drag_inv(_p, i):
	var s = PlayerManager.game_inventory.slots[i]
	if not s: return null
	var t = TextureRect.new()
	t.texture = s.item.icon
	t.size = Vector2(64, 64)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = Control.TEXTURE_FILTER_NEAREST
	set_drag_preview(t)
	return { "type": "inventory_drag", "inventory": PlayerManager.game_inventory, "slot_index": i, "item": s.item, "count": s.count }

func _drag_ally(_p, inv, i):
	if i >= inv.slots.size() or not inv.slots[i]: return null
	var t = TextureRect.new()
	t.texture = inv.slots[i].item.icon
	t.size = Vector2(64, 64)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = Control.TEXTURE_FILTER_NEAREST
	set_drag_preview(t)
	return { "type": "inventory_drag", "inventory": inv, "slot_index": i, "item": inv.slots[i].item, "count": inv.slots[i].count }

func _can_drop(_p, d): 
	return d is Dictionary and d.has("type")

func _can_drop_ally(_p, d, inv, idx):
	if not (d is Dictionary and d.has("type") and d.has("item")): return false
	var item = d.item
	if not inv.is_allowed_in_slot(item, idx): return false
	return true

func _drop_inv(_p, d, i): _generic_drop(d, PlayerManager.game_inventory, i)
func _drop_ally(_p, d, inv, i): _generic_drop(d, inv, i)

func _generic_drop(data, target_inv, target_idx):
	var src = data.inventory if data.has("inventory") else null
	var item = data.item if data.has("item") else data.resource
	var count = data.count if data.has("count") else 1
	
	if data.type == "creative_spawn": 
		target_inv.add_item(item, 64)
	elif data.type == "inventory_drag" and src:
		if src == target_inv:
			var temp = target_inv.slots[target_idx]; target_inv.slots[target_idx] = src.slots[data.slot_index]; src.slots[data.slot_index] = temp
			target_inv.inventory_changed.emit()
		else:
			var remainder = target_inv.add_item(item, count)
			var taken = count - remainder
			if taken > 0:
				src.remove_item(item, taken)

func _can_drop_trash(_pos, data) -> bool:
	if not PlayerManager.is_creative_mode: return false
	return data is Dictionary and data.has("type") and data.type == "inventory_drag"

func _drop_trash(_pos, data) -> void:
	if data.has("inventory") and data.has("item") and data.has("count"):
		data.inventory.remove_item(data.item, data.count)

