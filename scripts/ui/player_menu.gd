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
var power_graph: PowerGraph

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
var all_mods: Array[ItemResource] = []
var all_buildings: Array[BuildableResource] =[]
var basic_recipes: Array[RecipeResource] =[]

var dragging: bool = false
var drag_offset: Vector2

var d_dragging: bool = false
var d_drag_offset: Vector2

var _last_ally_update: int = 0
var _cached_wave: int = -1

class PowerGraph extends Control:
	var demand_data: Array[float] = []
	var gen_data: Array[float] =[]
	
	func _draw():
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.1, 0.1, 0.5))
		
		var max_val = 10.0
		for v in demand_data: max_val = max(max_val, v)
		for v in gen_data: max_val = max(max_val, v)
		max_val *= 1.1 
		
		var points = 60
		var step_x = size.x / max(1, points - 1)
		
		draw_line(Vector2(0, size.y/2), Vector2(size.x, size.y/2), Color(1,1,1,0.1))
		
		var d_pts = PackedVector2Array()
		var g_pts = PackedVector2Array()
		
		var start_idx = max(0, points - demand_data.size())
		
		for i in range(demand_data.size()):
			var x = (start_idx + i) * step_x
			var dy = size.y - (demand_data[i] / max_val) * size.y
			var gy = size.y - (gen_data[i] / max_val) * size.y
			d_pts.append(Vector2(x, dy))
			g_pts.append(Vector2(x, gy))
			
		if d_pts.size() > 1:
			draw_polyline(d_pts, Color(1.0, 0.3, 0.3), 2.0)
		if g_pts.size() > 1:
			draw_polyline(g_pts, Color(0.3, 1.0, 0.3), 2.0)

class CraftingButton extends Button:
	var recipe: RecipeResource
	func _make_custom_tooltip(_for_text: String) -> Object:
		var out = recipe.get_main_output()
		if out:
			var tt = load("res://scripts/ui/custom_tooltip.gd")
			if tt: return tt.new(out)
		return null

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
	
	btn.add_theme_color_override("font_color", Color.BLACK)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	return btn

func _apply_liquid_glass(win: Control, corner_radius: float = 12.0) -> void:
	WindowUtils.apply_liquid_glass(win, corner_radius)

func _recursive_override_size(node: Node, target_size: Vector2) -> void:
	if node is Control:
		if node is TextureRect or node is CenterContainer or node is Panel:
			node.custom_minimum_size = target_size
	for child in node.get_children():
		_recursive_override_size(child, target_size)

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
	
	if is_instance_valid(PlayerManager.player_entity):
		set_current_ally(PlayerManager.player_entity)
		
	call_deferred("_update_tabs_visibility")
	
	var vp_size = get_viewport_rect().size
	var p_size = window_root.size
	if p_size.x <= 10: p_size = Vector2(950, 720)
	window_root.position = (vp_size - p_size) / 2.0

func _process(_delta: float) -> void:
	var current_wave = 1
	if is_instance_valid(GameManager) and "game_data" in GameManager:
		current_wave = GameManager.game_data.get("wave", 1)
		
	if current_wave != _cached_wave:
		_cached_wave = current_wave
		_load_recipes()
		_populate_grids()
		_update_tabs_visibility()
		
	if not visible: return
	
	if tabs.current_tab >= 0 and tabs.current_tab < tabs.get_child_count():
		var current_t = tabs.get_child(tabs.current_tab)
		if current_t == ally_tab and is_instance_valid(current_ally):
			if Time.get_ticks_msec() - _last_ally_update > 500:
				_last_ally_update = Time.get_ticks_msec()
				_rebuild_ally_tab()
		elif current_t == core_tab:
			if Time.get_ticks_msec() - _last_ally_update > 1000:
				_last_ally_update = Time.get_ticks_msec()
				_update_core_tab()

func _build_ui_structure() -> void:
	for c in get_children(): c.queue_free()
	
	positioning_layer = Control.new()
	positioning_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	positioning_layer.mouse_filter = Control.MOUSE_FILTER_PASS
	positioning_layer.set_drag_forwarding(Callable(), Callable(UIHelper, "can_drop_trash"), Callable(UIHelper, "drop_trash"))
	add_child(positioning_layer)
	
	window_root = Control.new()
	window_root.size = Vector2(950, 720)
	window_root.clip_contents = true
	window_root.set_drag_forwarding(Callable(), Callable(UIHelper, "can_drop_trash"), Callable(UIHelper, "drop_trash"))
	positioning_layer.add_child(window_root)
	
	main_panel = PanelContainer.new()
	main_panel.name = "MainPanel"
	main_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_panel.clip_contents = true
	main_panel.set_drag_forwarding(Callable(), Callable(UIHelper, "can_drop_trash"), Callable(UIHelper, "drop_trash"))
	
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
	
	var core_split = HBoxContainer.new()
	core_split.add_theme_constant_override("separation", 20)
	core_tab.add_child(core_split)
	
	var core_left = VBoxContainer.new()
	core_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	core_split.add_child(core_left)
	
	core_stats_label = RichTextLabel.new()
	core_stats_label.bbcode_enabled = true
	core_stats_label.fit_content = true
	core_stats_label.add_theme_color_override("default_color", Color(0.1, 0.1, 0.1))
	core_left.add_child(core_stats_label)
	
	core_left.add_child(HSeparator.new())
	var cmod_lbl = Label.new(); cmod_lbl.text = "Core Mod Disk Drives"; cmod_lbl.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
	core_left.add_child(cmod_lbl)
	
	core_mods_grid = GridContainer.new()
	core_mods_grid.columns = 3
	core_mods_grid.add_theme_constant_override("h_separation", 6); core_mods_grid.add_theme_constant_override("v_separation", 6)
	core_left.add_child(core_mods_grid)
	
	var core_right = VBoxContainer.new()
	core_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	core_split.add_child(core_right)
	
	var graph_lbl = RichTextLabel.new()
	graph_lbl.bbcode_enabled = true
	graph_lbl.fit_content = true
	graph_lbl.text = "Energy Usage (Past Minute)\n[color=#55ff55]Generation[/color] /[color=#ff5555]Demand[/color]"
	graph_lbl.add_theme_color_override("default_color", Color(0.2, 0.2, 0.2))
	core_right.add_child(graph_lbl)
	
	power_graph = PowerGraph.new()
	power_graph.custom_minimum_size = Vector2(0, 200)
	core_right.add_child(power_graph)

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
	ally_left.custom_minimum_size = Vector2(250, 0)
	ally_split.add_child(ally_left)
	
	ally_stats_label = RichTextLabel.new()
	ally_stats_label.bbcode_enabled = true
	ally_stats_label.fit_content = true
	ally_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	ally_stats_label.add_theme_color_override("default_color", Color(0.1, 0.1, 0.1))
	ally_stats_label.custom_minimum_size = Vector2(200, 200)
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
	var p_scroll = ScrollContainer.new(); p_scroll.custom_minimum_size = Vector2(0, 280); vbox.add_child(p_scroll)
	player_grid = GridContainer.new(); player_grid.columns = 10
	player_grid.add_theme_constant_override("h_separation", 4); player_grid.add_theme_constant_override("v_separation", 4)
	p_scroll.add_child(player_grid)
	
	details_panel = PanelContainer.new()
	details_panel.name = "DetailsPanel"
	details_panel.size = Vector2(300, 720)
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
	
	var c_icon_margin = MarginContainer.new()
	c_icon_margin.custom_minimum_size = Vector2(80, 80)
	c_icon_margin.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	details_content.add_child(c_icon_margin)
	
	details_icon = TextureRect.new()
	details_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	details_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	details_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	details_icon.texture_filter = Control.TEXTURE_FILTER_NEAREST
	c_icon_margin.add_child(details_icon)
	
	var spacer = Control.new(); spacer.custom_minimum_size = Vector2(0, 20); details_content.add_child(spacer)
	var req_l = Label.new(); req_l.text = "Requirements:"; req_l.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
	details_content.add_child(req_l)
	var i_scroll = ScrollContainer.new(); i_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; details_content.add_child(i_scroll)
	details_ingredients_grid = GridContainer.new(); details_ingredients_grid.columns = 1; i_scroll.add_child(details_ingredients_grid)
	craft_progress = ProgressBar.new(); craft_progress.visible = false; details_content.add_child(craft_progress)
	craft_button = Button.new(); craft_button.text = "Craft"; craft_button.custom_minimum_size = Vector2(0, 40)
	craft_button.add_theme_color_override("font_color", Color.BLACK)
	craft_button.pressed.connect(_on_craft_button_pressed); details_content.add_child(craft_button)

	WindowUtils.setup_window_resizing(window_root, scale_wrapper, scale_root, frame_margin, Vector2(950, 720))
	WindowUtils.setup_window_resizing(details_panel, d_scale_wrapper, d_scale_root, d_frame_margin, Vector2(300, 720))

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
	if not is_instance_valid(ally) and is_instance_valid(PlayerManager.player_entity):
		ally = PlayerManager.player_entity
		
	if current_ally == ally: 
		return
		
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

func _rebuild_ally_tab(_arg1 = null, _arg2 = null) -> void:
	if not current_ally: return
	
	var hp = 0.0; var mhp = 0.0; var sec = 0.0; var msec = 0.0;
	if current_ally.has_node("HealthComponent"):
		var hc = current_ally.get_node("HealthComponent")
		hp = float(hc.current_health); mhp = float(hc.max_health)
		sec = float(hc.current_security); msec = float(hc.max_security)

	var spd = 5.0; var p_spd = 1.0; var atk = 10.0; var def = 0.0;
	var fw = 0.0; var net = 0.0; var spc = 10.0; var luck = 0.0;
	var comp = 1.0; var scl = 1.0; var ping_val = 1.0; var mal = 0.0;

	if current_ally.has_method("get_stat"):
		spd = float(current_ally.get_stat("speed", 5.0))
		spc = float(current_ally.get_stat("space", 10.0))
		p_spd = float(current_ally.get_stat("process_speed", 1.0))
		atk = float(current_ally.get_stat("attack_damage", 10.0))
		def = float(current_ally.get_stat("defense", 0.0))
		fw = float(current_ally.get_stat("firewall", 0.0))
		net = float(current_ally.get_stat("networking", 0.0))
		luck = float(current_ally.get_stat("luck_stat", 0.0))
		comp = float(current_ally.get_stat("compute", 1.0))
		scl = float(current_ally.get_stat("scale", 1.0))
		ping_val = float(current_ally.get_stat("ping", 1.0))
		mal = float(current_ally.get_stat("malware", 0.0))

	var inv = _get_ally_inventory(current_ally)
	var slots_used = 0
	if inv: for s in inv.slots: if s: slots_used += 1
	var max_s = inv.max_slots if inv else 0

	var name_str = "Ally"
	if current_ally.get("stats") and current_ally.stats.get("ally_name") != null: 
		name_str = str(current_ally.stats.get("ally_name"))
	elif "display_name" in current_ally: name_str = str(current_ally.display_name)
	elif "ally_name" in current_ally: name_str = str(current_ally.ally_name)

	ally_tab.name = name_str
	var txt = "[font_size=20][b]%s[/b][/font_size]\n\n" % name_str
	txt += "[table=2]"
	txt += "[cell][color=#aa0000]Health:[/color] %d / %d     [/cell]" %[int(hp), int(mhp)]
	if msec > 0:
		txt += "[cell][color=#0055aa]Security:[/color] %d / %d[/cell]" %[int(sec), int(msec)]
	else:
		txt += "[cell][/cell]"
	txt += "[cell][color=#00aa00]Speed:[/color] %.1f     [/cell][cell][color=#555555]Space:[/color] %.1f[/cell]" %[spd, spc]
	txt += "[cell][color=#aa0000]Attack:[/color] %.1f     [/cell][cell][color=#aa5500]Process:[/color] %.1f[/cell]" %[atk, p_spd]
	txt += "[cell][color=#555555]Defense:[/color] %.1f[/cell][cell][color=#00aaaa]Firewall:[/color] %.1f[/cell]" %[def, fw]
	txt += "[cell][color=#00aa00]Luck:[/color] %.1f     [/cell][cell][color=#aa00aa]Network:[/color] %.1f[/cell]" %[luck, net]
	txt += "[cell][color=#aaaa00]Compute:[/color] %.1f     [/cell][cell][color=#555555]Scale:[/color] %.1f[/cell]" % [comp, scl]
	txt += "[cell][color=#00aaaa]Ping:[/color] %.1f     [/cell][cell][color=#aa0000]Malware:[/color] %.1f[/cell]" %[ping_val, mal]
	txt += "[/table]"
	txt += "\n[color=#0000aa]Load:[/color] %d / %d slots" %[slots_used, max_s]

	ally_stats_label.text = txt

func _update_tabs_visibility() -> void:
	if not is_inside_tree(): return
	var prev_tab_idx = tabs.current_tab
	var prev_name = ""
	if prev_tab_idx >= 0 and prev_tab_idx < tabs.get_child_count():
		prev_name = tabs.get_child(prev_tab_idx).name
	
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
	
	var found = false
	for i in range(tabs.get_child_count()):
		if tabs.get_child(i).name == prev_name:
			tabs.current_tab = i
			found = true
			break
			
	if not found:
		tabs.current_tab = 0

func _update_core_tab() -> void:
	var core_node = get_tree().get_first_node_in_group("core")
	if not core_node: 
		core_stats_label.text = "Core not found."
		return
	
	var hp = core_node.health_component.current_health if core_node.health_component else 0
	var mhp = core_node.health_component.max_health if core_node.health_component else 0
	
	var def = core_node.get_stat("defense", 0.0) if core_node.has_method("get_stat") else 0.0
	var fwl = core_node.get_stat("firewall", 0.0) if core_node.has_method("get_stat") else 0.0
	var atk = core_node.get_stat("attack_damage", 0.0) if core_node.has_method("get_stat") else 0.0
	
	var gen = PowerGridManager.total_power_generation
	var dem = PowerGridManager.total_power_demand
	
	core_stats_label.text = "[font_size=20][b]Core Systems[/b][/font_size]\n\n"
	core_stats_label.text += "[color=#aa0000]Health:[/color] %d / %d\n" %[int(hp), int(mhp)]
	core_stats_label.text += "[color=#555555]Defense Base:[/color] %.1f\n" % def
	core_stats_label.text += "[color=#00aaaa]Firewall Base:[/color] %.1f\n" % fwl
	core_stats_label.text += "[color=#aa0000]Attack Base:[/color] %.1f\n" % atk
	core_stats_label.text += "\n[color=#aaaa00]Total Capacity (Gen):[/color] %d W\n" % int(gen)
	core_stats_label.text += "[color=#aa5500]Total Usage (Demand):[/color] %d W\n" % int(dem)
	
	if power_graph:
		power_graph.demand_data = PowerGridManager.history_demand
		power_graph.gen_data = PowerGridManager.history_generation
		power_graph.queue_redraw()
	
	var mod_inv = core_node.get_node_or_null("ModInventory")
	if mod_inv:
		# Guarantee slots are fully initialized
		if mod_inv.slots.size() != mod_inv.max_slots:
			if mod_inv.has_method("set_capacity"):
				mod_inv.set_capacity(mod_inv.max_slots)
			else:
				mod_inv.slots.resize(mod_inv.max_slots)
		
		if not mod_inv.is_connected("inventory_changed", _update_core_mods):
			mod_inv.inventory_changed.connect(_update_core_mods)
			
		_update_core_mods()

func _update_core_mods() -> void:
	var core_node = get_tree().get_first_node_in_group("core")
	if not core_node: return
	var mod_inv = core_node.get_node_or_null("ModInventory")
	if not mod_inv: return
	
	if mod_inv.slots.size() != mod_inv.max_slots:
		if mod_inv.has_method("set_capacity"):
			mod_inv.set_capacity(mod_inv.max_slots)
		else:
			mod_inv.slots.resize(mod_inv.max_slots)

	if core_mods_grid.get_child_count() != mod_inv.slots.size():
		_clear(core_mods_grid)
		for i in range(mod_inv.slots.size()):
			var b = _create_slot_button(mod_inv, i, false)
			b.custom_minimum_size = Vector2(128, 128)
			_recursive_override_size(b, Vector2(128, 128))
			core_mods_grid.add_child(b)

	for i in range(mod_inv.slots.size()):
		var b = core_mods_grid.get_child(i)
		UIHelper.fill_slot_btn(b, mod_inv.slots[i])
		_recursive_override_size(b, Vector2(128, 128))
		
		# Clean up any previously generated overlays
		for c in b.get_children():
			if c is Label and c.text in ["DISK"]:
				c.queue_free()
			elif c is TextureRect and c.texture and c.texture.resource_path.ends_with("trojan.png"):
				c.queue_free()
				
		if mod_inv.slots[i] == null:
			var l = Label.new()
			l.text = "DISK"
			l.add_theme_font_size_override("font_size", 24)
			l.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2, 0.4))
			l.set_anchors_preset(Control.PRESET_CENTER)
			b.add_child(l)
			b.modulate = Color(1,1,1,0.8)
			b.tooltip_text = ""
			b.set_meta("tooltip_res", null)
		else:
			var is_perm = mod_inv.slots[i].item.modifiers.get("permanent", false)
			b.modulate = Color(1.0, 0.6, 0.8) if is_perm else Color(0.8, 1.0, 1.0)
			b.tooltip_text = " "
			b.set_meta("tooltip_res", mod_inv.slots[i].item)
			
			# Spinning DVD Animation for Core Mod slot icons
			var tex_rect = null
			for c in b.get_children():
				if c is MarginContainer:
					for mc in c.get_children():
						if mc is TextureRect:
							tex_rect = mc
							break
			
			if tex_rect:
				tex_rect.pivot_offset = tex_rect.size / 2.0
				var spin_script = GDScript.new()
				spin_script.source_code = """
extends TextureRect
func _process(delta):
	rotation += 2.0 * delta
"""
				spin_script.reload()
				tex_rect.set_script(spin_script)
				tex_rect.set_process(true)
			
			# Trojan icon for Eternal Disks
			if is_perm:
				var trojan_icon = TextureRect.new()
				var t_tex = load("res://assets/icons/trojan.png")
				if t_tex:
					trojan_icon.texture = t_tex
				trojan_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				trojan_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				trojan_icon.custom_minimum_size = Vector2(32, 32)
				trojan_icon.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
				trojan_icon.position = Vector2(-36, -36)
				trojan_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
				b.add_child(trojan_icon)

func _create_grid_tab(name: String) -> Control:
	var m = MarginContainer.new()
	m.name = name
	m.add_theme_constant_override("margin_left", 10); m.add_theme_constant_override("margin_right", 10)
	m.add_theme_constant_override("margin_top", 10); m.add_theme_constant_override("margin_bottom", 10)
	var s = ScrollContainer.new(); s.name = "Scroll"; m.add_child(s)
	
	s.set_drag_forwarding(Callable(), Callable(UIHelper, "can_drop_trash"), Callable(UIHelper, "drop_trash"))
	
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

func _load_recipes() -> void:
	basic_recipes.clear()
	var current_wave = 1
	if is_instance_valid(GameManager) and "game_data" in GameManager:
		current_wave = GameManager.game_data.get("wave", 1)
		
	var menu_cats = ["assembly", "basic"]
	if is_instance_valid(GameManager) and GameManager.current_level_config.has("menu_recipe_categories"):
		var raw_cats = GameManager.current_level_config.get("menu_recipe_categories")
		if typeof(raw_cats) == TYPE_ARRAY:
			menu_cats =[]
			for c in raw_cats: menu_cats.append(str(c))
			
	if GameManager.has_method("get_available_recipes"):
		for r in GameManager.get_available_recipes():
			if r.category in menu_cats and r.tier <= current_wave:
				basic_recipes.append(r)

func _on_mode_toggle() -> void: PlayerManager.is_creative_mode = !PlayerManager.is_creative_mode
func _on_mode_changed(creative: bool) -> void:
	mode_button.text = "Mode: Creative" if creative else "Mode: Normal"
	if creative:
		details_panel.visible = false; selected_recipe = null
	_populate_grids()
	_update_tabs_visibility()

func _populate_grids() -> void:
	_clear(crafting_grid)
	for r in basic_recipes:
		crafting_grid.add_child(_create_craft_btn(r))
			
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
		var margin = MarginContainer.new()
		margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		margin.add_theme_constant_override("margin_left", 4)
		margin.add_theme_constant_override("margin_right", 4)
		margin.add_theme_constant_override("margin_top", 4)
		margin.add_theme_constant_override("margin_bottom", 4)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(margin)

		var tr = TextureRect.new()
		tr.texture = out.icon
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = Control.TEXTURE_FILTER_NEAREST
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_child(tr)
		
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
		var margin = MarginContainer.new()
		margin.custom_minimum_size = Vector2(32, 32)
		var ic = TextureRect.new()
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture_filter = Control.TEXTURE_FILTER_NEAREST
		if entry.resource.get("icon"): ic.texture = entry.resource.icon
		margin.add_child(ic)
		hb.add_child(margin)
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

func _custom_can_drop(pos, data) -> bool:
	if typeof(data) == TYPE_DICTIONARY and data.get("type") == "creative_copy": return true
	return UIHelper.can_drop(pos, data)

func _custom_can_drop_ally(pos, data, inv, idx) -> bool:
	if typeof(data) == TYPE_DICTIONARY and data.get("type") == "creative_copy": return true
	return UIHelper.can_drop_ally(pos, data, inv, idx)

func _custom_drag_inv(pos, inv, idx, btn):
	var slot = inv.slots[idx]
	if slot and slot.item:
		if slot.item.equipment_type == ItemResource.EquipmentType.MOD:
			if slot.item.modifiers.get("permanent", false) and not PlayerManager.is_creative_mode:
				var tween = btn.create_tween()
				tween.tween_property(btn, "modulate", Color(1, 0, 0), 0.1)
				tween.tween_property(btn, "modulate", Color.WHITE, 0.1)
				return null
				
	if PlayerManager.is_creative_mode and Input.is_action_pressed("build_copy"):
		if slot:
			btn.set_drag_preview(WindowUtils.create_drag_preview(slot.item.icon))
			return { "type": "creative_copy", "item": slot.item, "count": slot.item.stack_size }
	return UIHelper.drag_inv(pos, inv, idx, btn)

func _custom_drop_inv(pos, data, inv, idx):
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

func _custom_drop_ally(pos, data, inv, idx):
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
	UIHelper.drop_ally(pos, data, inv, idx)

func _update_player_inventory() -> void:
	_clear(player_grid)
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
		)
		
		if slots[i]:
			btn.set_meta("tooltip_res", slots[i].item)
			btn.tooltip_text = " "
			btn.pressed.connect(func():
				if Input.is_key_pressed(KEY_SHIFT):
					UIHelper.handle_shift_click(PlayerManager.game_inventory, i)
			)
			btn.set_drag_forwarding(Callable(self, "_custom_drag_inv").bind(PlayerManager.game_inventory, i, btn), Callable(self, "_custom_can_drop"), Callable(self, "_custom_drop_inv").bind(PlayerManager.game_inventory, i))
		else:
			btn.set_drag_forwarding(Callable(), Callable(self, "_custom_can_drop"), Callable(self, "_custom_drop_inv").bind(PlayerManager.game_inventory, i))
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
			var b = _create_slot_button(inv, i, true)
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
		var b = _create_slot_button(inv, i, true)
		ally_backpack_grid.add_child(b)

func _create_slot_button(inv: InventoryComponent, i: int, is_ally: bool = false) -> Button:
	var b = UIHelper.create_slot_btn_base()
	b.set_script(preload("res://scripts/ui/slot_button.gd"))
	UIHelper.fill_slot_btn(b, inv.slots[i])
	
	b.gui_input.connect(func(event: InputEvent):
		if event.is_action_pressed("build_copy") and PlayerManager.is_creative_mode:
			var slot = inv.slots[i]
			if slot:
				var drag_data = { "type": "creative_copy", "item": slot.item, "count": slot.item.stack_size }
				b.force_drag(drag_data, WindowUtils.create_drag_preview(slot.item.icon))
	)


	if inv.slots[i]:
		b.set_meta("tooltip_res", inv.slots[i].item)
		b.tooltip_text = " "
		b.pressed.connect(func():
			if Input.is_key_pressed(KEY_SHIFT):
				var slot = inv.slots[i]
				if slot and slot.item and slot.item.equipment_type == ItemResource.EquipmentType.MOD:
					if slot.item.modifiers.get("permanent", false) and not PlayerManager.is_creative_mode:
						var tween = b.create_tween()
						tween.tween_property(b, "modulate", Color(1, 0, 0), 0.1)
						tween.tween_property(b, "modulate", Color.WHITE, 0.1)
						return
				UIHelper.handle_shift_click(inv, i)
		)
		if is_ally:
			b.set_drag_forwarding(Callable(self, "_custom_drag_inv").bind(inv, i, b), Callable(self, "_custom_can_drop_ally").bind(inv, i), Callable(self, "_custom_drop_ally").bind(inv, i))
		else:
			b.set_drag_forwarding(Callable(self, "_custom_drag_inv").bind(inv, i, b), Callable(self, "_custom_can_drop"), Callable(self, "_custom_drop_inv").bind(inv, i))
	else:
		if is_ally:
			b.set_drag_forwarding(Callable(), Callable(self, "_custom_can_drop_ally").bind(inv, i), Callable(self, "_custom_drop_ally").bind(inv, i))
		else:
			b.set_drag_forwarding(Callable(), Callable(self, "_custom_can_drop"), Callable(self, "_custom_drop_inv").bind(inv, i))
	return b

func _create_res_btn(res):
	var b = Button.new()
	b.custom_minimum_size = Vector2(64, 64)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.set_script(preload("res://scripts/ui/slot_button.gd"))
	b.set_meta("tooltip_res", res)
	b.tooltip_text = " "
	
	if res.get("icon"): 
		var margin = MarginContainer.new()
		margin.set_anchors_preset(Control.PRESET_FULL_RECT)
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_theme_constant_override("margin_left", 4)
		margin.add_theme_constant_override("margin_right", 4)
		margin.add_theme_constant_override("margin_top", 4)
		margin.add_theme_constant_override("margin_bottom", 4)
		b.add_child(margin)
		
		var tr = TextureRect.new()
		tr.texture = res.icon
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = Control.TEXTURE_FILTER_NEAREST
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_child(tr)
	
	b.gui_input.connect(func(event: InputEvent):
		if event.is_action_pressed("build_copy") and PlayerManager.is_creative_mode:
			var stack = 64
			if res is ItemResource: stack = res.stack_size
			var drag_data = { "type": "creative_copy", "item": res, "count": stack }
			b.force_drag(drag_data, WindowUtils.create_drag_preview(res.icon))
		elif event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				var stack = 64
				if res is ItemResource: stack = res.stack_size
				PlayerManager.game_inventory.add_item(res, stack)
			elif event.button_index == MOUSE_BUTTON_RIGHT:
				PlayerManager.game_inventory.add_item(res, 1)
	)
	
	b.set_drag_forwarding(Callable(self, "_drag_create").bind(res, b), Callable(UIHelper, "can_drop_trash"), Callable(UIHelper, "drop_trash"))
	return b

func _clear(p): for c in p.get_children(): c.queue_free()

func _drag_create(_pos, r, btn: Control): 
	btn.set_drag_preview(WindowUtils.create_drag_preview(r.icon))
	if PlayerManager.is_creative_mode and Input.is_action_pressed("build_copy"):
		var stack = 64
		if r is ItemResource: stack = r.stack_size
		return { "type": "creative_copy", "item": r, "count": stack }
	return { "type": "creative_spawn", "resource": r }
