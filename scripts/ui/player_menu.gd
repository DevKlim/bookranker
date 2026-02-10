class_name PlayerMenu
extends Control

var main_panel: PanelContainer
var details_panel: PanelContainer
var tabs: TabContainer
var mode_button: Button
var player_grid: GridContainer
var items_grid: GridContainer
var buildings_grid: GridContainer
var crafting_grid: GridContainer 

# Ally Specific UI
var ally_tab: Control
var ally_split: HBoxContainer
var ally_stats_label: RichTextLabel
var ally_equip_grid: GridContainer
var ally_backpack_grid: GridContainer

var craft_tab: Control
var build_tab: Control
var item_tab: Control

var details_content: VBoxContainer
var details_title: Label
var details_icon: TextureRect
var details_ingredients_grid: GridContainer
var craft_button: Button
var craft_progress: ProgressBar
var selected_recipe: RecipeResource = null

var current_ally: Node = null 
var all_items: Array[ItemResource] = []
var all_buildings: Array[BuildableResource] = []
var basic_recipes: Array[RecipeResource] = []

class CraftingButton extends Button:
	var recipe: RecipeResource
	func _make_custom_tooltip(_for_text: String) -> Object:
		var panel = PanelContainer.new()
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
		style.content_margin_left=8; style.content_margin_right=8; style.content_margin_top=8; style.content_margin_bottom=8
		panel.add_theme_stylebox_override("panel", style)
		var vbox = VBoxContainer.new(); panel.add_child(vbox)
		var label = Label.new(); label.text = recipe.recipe_name; label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0)); vbox.add_child(label)
		return panel

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS 
	_build_ui_structure()
	_load_resources()
	mode_button.pressed.connect(_on_mode_toggle)
	PlayerManager.mode_changed.connect(_on_mode_changed)
	PlayerManager.game_inventory.inventory_changed.connect(_update_player_inventory)
	PlayerManager.game_inventory.inventory_changed.connect(_update_crafting_ui)
	if PlayerManager.crafter:
		PlayerManager.crafter.progress_changed.connect(_on_craft_progress)
		PlayerManager.crafter.craft_started.connect(_on_craft_state_changed)
		PlayerManager.crafter.craft_finished.connect(_on_craft_state_changed)
	_on_mode_changed(PlayerManager.is_creative_mode)
	_update_player_inventory()
	main_panel.item_rect_changed.connect(_update_details_position)
	get_viewport().size_changed.connect(_update_details_position)
	call_deferred("_update_tabs_visibility")
	call_deferred("_update_details_position")

func _build_ui_structure() -> void:
	for c in get_children(): c.queue_free()
	
	# Center Container wrapper
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(center)
	
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	center.add_child(hbox)
	
	# Left: Main Panel
	main_panel = PanelContainer.new()
	main_panel.name = "MainPanel"
	main_panel.custom_minimum_size = Vector2(650, 600)
	var p_style = StyleBoxFlat.new()
	p_style.bg_color = Color(0.08, 0.08, 0.1, 0.95)
	p_style.border_width_left=2; p_style.border_width_right=2; p_style.border_width_top=2; p_style.border_width_bottom=2
	p_style.border_color = Color(0.3, 0.3, 0.35)
	p_style.corner_radius_top_left=8; p_style.corner_radius_top_right=4
	p_style.corner_radius_bottom_right=4; p_style.corner_radius_bottom_left=8
	main_panel.add_theme_stylebox_override("panel", p_style)
	hbox.add_child(main_panel)
	
	var vbox = VBoxContainer.new()
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20); margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20); margin.add_theme_constant_override("margin_bottom", 20)
	main_panel.add_child(margin)
	margin.add_child(vbox)
	
	var header = HBoxContainer.new()
	vbox.add_child(header)
	var title = Label.new()
	title.text = "MENU"; title.add_theme_font_size_override("font_size", 28); title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	mode_button = Button.new(); mode_button.text = "Normal"; mode_button.focus_mode = Control.FOCUS_NONE
	header.add_child(mode_button)
	
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(tabs)
	
	craft_tab = _create_grid_tab("Crafting"); crafting_grid = craft_tab.get_node("Scroll/Grid")
	build_tab = _create_grid_tab("Buildings"); buildings_grid = build_tab.get_node("Scroll/Grid")
	item_tab = _create_grid_tab("Items"); items_grid = item_tab.get_node("Scroll/Grid")
	
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
	ally_stats_label.text = "[b]Stats[/b]"
	ally_left.add_child(ally_stats_label)
	
	ally_left.add_child(HSeparator.new())
	var eq_lbl = Label.new(); eq_lbl.text = "Equipment"; eq_lbl.add_theme_color_override("font_color", Color.GRAY)
	ally_left.add_child(eq_lbl)
	
	ally_equip_grid = GridContainer.new()
	ally_equip_grid.columns = 2
	ally_equip_grid.add_theme_constant_override("h_separation", 8); ally_equip_grid.add_theme_constant_override("v_separation", 8)
	ally_left.add_child(ally_equip_grid)

	var ally_right = VBoxContainer.new()
	ally_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ally_right.size_flags_stretch_ratio = 1.5
	ally_split.add_child(ally_right)
	
	var pack_lbl = Label.new(); pack_lbl.text = "Inventory"; pack_lbl.add_theme_color_override("font_color", Color.GRAY)
	ally_right.add_child(pack_lbl)
	
	var pack_scroll = ScrollContainer.new()
	pack_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ally_right.add_child(pack_scroll)
	
	ally_backpack_grid = GridContainer.new()
	ally_backpack_grid.columns = 5
	ally_backpack_grid.add_theme_constant_override("h_separation", 4); ally_backpack_grid.add_theme_constant_override("v_separation", 4)
	pack_scroll.add_child(ally_backpack_grid)
	
	vbox.add_child(HSeparator.new())
	var b_lbl = Label.new(); b_lbl.text = "Player Hotbar & Backpack"; b_lbl.modulate = Color(0.7,0.7,0.7)
	vbox.add_child(b_lbl)
	var p_scroll = ScrollContainer.new(); p_scroll.custom_minimum_size = Vector2(0, 160); vbox.add_child(p_scroll)
	player_grid = GridContainer.new(); player_grid.columns = 10
	player_grid.add_theme_constant_override("h_separation", 4); player_grid.add_theme_constant_override("v_separation", 4)
	p_scroll.add_child(player_grid)
	
	details_panel = PanelContainer.new()
	details_panel.name = "DetailsPanel"
	details_panel.custom_minimum_size = Vector2(300, 0)
	details_panel.visible = false
	var d_style = StyleBoxFlat.new()
	d_style.bg_color = Color(0.12, 0.12, 0.15, 0.95)
	d_style.border_width_right=2; d_style.border_width_top=2; d_style.border_width_bottom=2
	d_style.border_color = Color(0.3, 0.3, 0.35)
	d_style.corner_radius_top_right=8; d_style.corner_radius_bottom_right=8
	details_panel.add_theme_stylebox_override("panel", d_style)
	hbox.add_child(details_panel)
	
	var d_margin = MarginContainer.new()
	d_margin.add_theme_constant_override("margin_left", 20); d_margin.add_theme_constant_override("margin_right", 20)
	d_margin.add_theme_constant_override("margin_top", 20); d_margin.add_theme_constant_override("margin_bottom", 20)
	details_panel.add_child(d_margin)
	
	details_content = VBoxContainer.new()
	d_margin.add_child(details_content)
	details_title = Label.new(); details_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; details_title.add_theme_font_size_override("font_size", 22)
	details_content.add_child(details_title)
	
	var c_icon = CenterContainer.new(); details_content.add_child(c_icon)
	var i_panel = Panel.new(); i_panel.custom_minimum_size = Vector2(100, 100); c_icon.add_child(i_panel)
	details_icon = TextureRect.new(); details_icon.custom_minimum_size = Vector2(80, 80); details_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; details_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	details_icon.position = Vector2(10, 10); i_panel.add_child(details_icon)
	
	var spacer = Control.new(); spacer.custom_minimum_size = Vector2(0, 20); details_content.add_child(spacer)
	var req_l = Label.new(); req_l.text = "Requirements:"; details_content.add_child(req_l)
	var i_scroll = ScrollContainer.new(); i_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL; details_content.add_child(i_scroll)
	details_ingredients_grid = GridContainer.new(); details_ingredients_grid.columns = 1; i_scroll.add_child(details_ingredients_grid)
	craft_progress = ProgressBar.new(); craft_progress.visible = false; details_content.add_child(craft_progress)
	craft_button = Button.new(); craft_button.text = "Craft"; craft_button.custom_minimum_size = Vector2(0, 50)
	craft_button.pressed.connect(_on_craft_button_pressed); details_content.add_child(craft_button)

func _update_details_position() -> void:
	if not main_panel or not details_panel: return
	details_panel.custom_minimum_size.y = main_panel.size.y

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

func _rebuild_ally_tab() -> void:
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
	ally_stats_label.text = "[b][font_size=20]%s[/font_size][/b]\n\n" % name_str
	ally_stats_label.text += "[color=#ff8888]Health:[/color] %d / %d\n" % [int(hp), int(mhp)]
	ally_stats_label.text += "[color=#88ff88]Speed:[/color] %.1f\n" % spd
	ally_stats_label.text += "[color=#8888ff]Load:[/color] %d / %d slots" % [slots_used, max_s]

func _update_tabs_visibility() -> void:
	if not is_inside_tree(): return
	var prev_tab_idx = tabs.current_tab
	var prev_tab_ctrl = null
	if prev_tab_idx >= 0 and prev_tab_idx < tabs.get_child_count():
		prev_tab_ctrl = tabs.get_child(prev_tab_idx)
	
	for c in tabs.get_children(): tabs.remove_child(c)
	
	tabs.add_child(craft_tab)
	if PlayerManager.is_creative_mode:
		tabs.add_child(build_tab)
		tabs.add_child(item_tab)
	if current_ally:
		tabs.add_child(ally_tab)
		tabs.current_tab = tabs.get_child_count() - 1
		return
	
	if prev_tab_ctrl and prev_tab_ctrl.get_parent() == tabs:
		var idx = tabs.get_children().find(prev_tab_ctrl)
		tabs.current_tab = idx
	else:
		tabs.current_tab = 0

func _create_grid_tab(name: String) -> Control:
	var m = MarginContainer.new()
	m.name = name
	m.add_theme_constant_override("margin_left", 10); m.add_theme_constant_override("margin_right", 10)
	m.add_theme_constant_override("margin_top", 10); m.add_theme_constant_override("margin_bottom", 10)
	var s = ScrollContainer.new(); s.name = "Scroll"; m.add_child(s)
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
	_clear(items_grid); _clear(buildings_grid)
	if PlayerManager.is_creative_mode:
		for i in all_items: items_grid.add_child(_create_res_btn(i))
		for b in all_buildings: buildings_grid.add_child(_create_res_btn(b))

func _create_craft_btn(r: RecipeResource) -> Button:
	var b = CraftingButton.new(); b.recipe = r; b.custom_minimum_size = Vector2(64, 64); b.expand_icon = true
	var out = r.get_main_output()
	if out:
		if out.get("icon"): b.icon = out.icon
		if out.get("color"): b.modulate = out.color
	b.pressed.connect(func(): _select_recipe(r))
	return b

func _select_recipe(r: RecipeResource) -> void:
	selected_recipe = r; details_panel.visible = true
	var out = r.get_main_output()
	if out:
		details_title.text = out.get("item_name") if "item_name" in out else out.get("buildable_name")
		if out.get("icon"): details_icon.texture = out.icon
		if out.get("color"): details_icon.modulate = out.color
	_clear(details_ingredients_grid)
	for entry in r.inputs:
		var hb = HBoxContainer.new()
		var ic = TextureRect.new(); ic.custom_minimum_size = Vector2(32, 32); ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if entry.resource.get("icon"): ic.texture = entry.resource.icon
		if entry.resource.get("color"): ic.modulate = entry.resource.color
		hb.add_child(ic)
		var lb = Label.new()
		var n = entry.resource.get("item_name") if "item_name" in entry.resource else entry.resource.get("buildable_name")
		lb.text = "%dx %s" % [entry.count, n]
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
			0: show = has_tool; label_txt = "TOOL"
			1: show = has_weap; label_txt = "WPN"
			2: show = has_arm; label_txt = "ARM"
			3: show = has_art; label_txt = "ART"
		
		if show:
			var b = _create_slot_button(inv, i)
			if inv.slots[i] == null:
				# Show placeholder text
				var l = Label.new()
				l.text = label_txt
				l.add_theme_color_override("font_color", Color(1,1,1,0.3))
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
	b.custom_minimum_size = Vector2(50, 50)
	return b

func _fill_slot_btn(b: Button, slot_data):
	# Use TextureRect inside Button to prevent overlaps
	if slot_data:
		var it = slot_data.item
		var tr = TextureRect.new()
		tr.texture = it.icon
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		tr.offset_left = 4; tr.offset_top = 4; tr.offset_right = -4; tr.offset_bottom = -4
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if it.get("color"): tr.modulate = it.color
		b.add_child(tr)
		
		var l = Label.new()
		l.text = str(slot_data.count)
		l.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		l.position -= Vector2(4, 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		b.add_child(l)

func _create_slot_button(inv, i) -> Button:
	var b = _create_slot_btn_base()
	_fill_slot_btn(b, inv.slots[i])
	b.set_drag_forwarding(Callable(self, "_drag_ally").bind(inv, i), Callable(self, "_can_drop_ally").bind(inv, i), Callable(self, "_drop_ally").bind(inv, i))
	return b

func _create_res_btn(res):
	var b = Button.new(); b.custom_minimum_size = Vector2(60, 60); b.expand_icon = true
	if res.get("icon"): b.icon = res.icon
	if res.get("color"): b.modulate = res.color
	
	# Enable mouse clicks to give items directly
	b.gui_input.connect(_on_res_btn_input.bind(res))
	
	# Keep drag for convenience
	b.set_drag_forwarding(Callable(self, "_drag_create").bind(res), Callable(), Callable())
	return b

func _on_res_btn_input(event: InputEvent, res: Resource):
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			# Give full stack
			var stack = 64
			if res is ItemResource: stack = res.stack_size
			PlayerManager.game_inventory.add_item(res, stack)
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			# Give 1
			PlayerManager.game_inventory.add_item(res, 1)

func _clear(p): for c in p.get_children(): c.queue_free()

func _drag_create(_p, r): 
	var t = TextureRect.new(); t.texture = r.icon; t.size = Vector2(40,40); t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; set_drag_preview(t)
	return { "type": "creative_spawn", "resource": r }

func _drag_inv(_p, i):
	var s = PlayerManager.game_inventory.slots[i]
	if not s: return null
	var t = TextureRect.new(); t.texture = s.item.icon; t.size = Vector2(40,40); t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; set_drag_preview(t)
	return { "type": "inventory_drag", "inventory": PlayerManager.game_inventory, "slot_index": i, "item": s.item, "count": s.count }

func _drag_ally(_p, inv, i):
	if i >= inv.slots.size() or not inv.slots[i]: return null
	var t = TextureRect.new(); t.texture = inv.slots[i].item.icon; t.size = Vector2(40,40); t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; set_drag_preview(t)
	return { "type": "inventory_drag", "inventory": inv, "slot_index": i, "item": inv.slots[i].item, "count": inv.slots[i].count }

func _can_drop(_p, d): 
	return d is Dictionary and d.has("type")

func _can_drop_ally(_p, d, inv, idx):
	if not (d is Dictionary and d.has("type") and d.has("item")): return false
	
	var item = d.item
	# Use component logic to check restriction
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
