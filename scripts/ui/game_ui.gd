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

# Context Menu
var context_menu_panel: PanelContainer
var context_menu_vbox: VBoxContainer

const DEV_UI_SCRIPT = preload("res://scripts/ui/dev_ui.gd")
const PAUSE_MENU_SCENE = preload("res://scenes/ui/pause_menu.tscn")

func _ready() -> void:
	# Backdrop for when menus are open
	var backdrop = ColorRect.new()
	backdrop.name = "UIBackdrop"
	backdrop.color = Color(0, 0, 0, 0.4)
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

	_setup_network_stats_ui()
	_setup_pause_menu_instance()
	_setup_notification_label()
	_setup_context_menu()
	
	# Re-add Enemy Spawning UI (Dev UI)
	_setup_dev_ui()

	if debug_coords_label:
		debug_coords_label.text = "Tile: (-, -)"
	
	# Force Inventory GUI to center and reset offsets
	if inventory_gui:
		inventory_gui.hide()
		inventory_gui.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_KEEP_SIZE)
	
	if is_instance_valid(GameManager):
		GameManager.reset_state()
		_initialize_recipe_database()
	
	player_menu = PlayerMenu.new()
	player_menu.name = "PlayerMenu"
	player_menu.visible = false
	add_child(player_menu)

func _setup_dev_ui() -> void:
	# Instantiate and configure the DevUI panel programmatically
	dev_ui_panel = Panel.new()
	dev_ui_panel.name = "DevUI"
	dev_ui_panel.set_script(DEV_UI_SCRIPT)
	
	# Layout: Position Top Right
	dev_ui_panel.custom_minimum_size = Vector2(220, 180)
	dev_ui_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	dev_ui_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	dev_ui_panel.position = Vector2(-240, 20) # Offset from right edge
	
	add_child(dev_ui_panel)

func _process(_delta: float) -> void:
	var backdrop = get_node_or_null("UIBackdrop")
	if backdrop:
		var any_open = is_any_menu_open() or is_pause_menu_open()
		backdrop.visible = any_open
		# Stop mouse clicks from going to world when backdrop is visible (menu open)
		backdrop.mouse_filter = Control.MOUSE_FILTER_STOP if any_open else Control.MOUSE_FILTER_IGNORE

func _setup_context_menu() -> void:
	context_menu_panel = PanelContainer.new()
	context_menu_panel.name = "ContextMenu"
	context_menu_panel.visible = false
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.15, 0.95)
	style.border_width_left = 1; style.border_width_right = 1
	style.border_width_top = 1; style.border_width_bottom = 1
	style.border_color = Color(0.3, 0.3, 0.35)
	style.corner_radius_top_left = 6; style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6; style.corner_radius_bottom_left = 6
	style.shadow_color = Color(0, 0, 0, 0.5)
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
	# Close previous
	hide_context_menu()
	if options.is_empty(): return
	
	# Build buttons
	for child in context_menu_vbox.get_children(): child.queue_free()
	
	for opt in options:
		var btn = Button.new()
		btn.text = opt.label
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.flat = true
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.pressed.connect(func(): 
			opt.callback.call()
			hide_context_menu()
		)
		context_menu_vbox.add_child(btn)
	
	# Cancel Button
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
	add_child(pause_menu)
	pause_menu.resume_requested.connect(toggle_pause_menu)
	pause_menu.quit_requested.connect(func(): get_tree().quit())

func _setup_notification_label() -> void:
	notification_label = Label.new()
	notification_label.name = "NotificationLabel"
	notification_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	notification_label.add_theme_constant_override("shadow_offset_x", 1)
	notification_label.add_theme_constant_override("shadow_offset_y", 1)
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
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.05, 0.9)
	style.border_width_left = 2; style.border_color = Color(0.4, 0.6, 1.0, 0.5)
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

	var txt = "[right][b]Network Stats[/b][/right]\n[right]Status: [color=%s]%s[/color][/right]\n" % [status_col, status]
	txt += "[right]Gen: %.0f W | Dem: %.0f W[/right]" % [stats.get("total_generation", 0), stats.get("total_demand", 0)]
	network_stats_label.text = txt
	network_stats_panel.visible = true

func hide_network_stats() -> void:
	network_stats_panel.visible = false

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
		
		if not source_inv.slots[data.slot_index] or source_inv.slots[data.slot_index].item != item: return

		if target.has_method("receive_item"):
			if target.receive_item(item):
				source_inv.remove_item(item, 1) 
				if count_to_add > 1:
					for i in range(count_to_add - 1):
						if not target.receive_item(item): break
						source_inv.remove_item(item, 1)
				return

		var inv_comp = target.get("inventory_component")
		if not inv_comp: inv_comp = target.get_node_or_null("InventoryComponent")
		
		if inv_comp and inv_comp.has_method("add_item") and inv_comp.has_space_for(item):
			var remainder = inv_comp.add_item(item, count_to_add)
			var taken = count_to_add - remainder
			if taken > 0:
				source_inv.remove_item(item, taken)
				show_notification("Dropped %d %s" % [taken, item.item_name], Color.GREEN)

func _initialize_recipe_database() -> void:
	var path = "res://resources/recipes/"
	if not DirAccess.dir_exists_absolute(path): return
	var dir = DirAccess.open(path)
	var recipes: Array[RecipeResource] = []
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
		close_inventory()
		player_menu.show()

func set_debug_text(text: String) -> void:
	if debug_coords_label: debug_coords_label.text = text

func open_inventory(inventory: InventoryComponent, title: String = "Storage", context: Object = null) -> void:
	if inventory_gui:
		if player_menu: player_menu.hide()
		inventory_gui.open(inventory, title, context)

func close_inventory() -> void:
	if inventory_gui: inventory_gui.close()

func set_inventory_screen_position(_screen_pos: Vector2) -> void: pass 

func get_ui_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if hotbar: rects.append(hotbar.get_global_rect())
	if dev_ui_panel: rects.append(dev_ui_panel.get_global_rect())
	if inventory_gui and inventory_gui.visible: rects.append(inventory_gui.get_global_rect())
	if player_menu and player_menu.visible:
		if player_menu.main_panel: rects.append(player_menu.main_panel.get_global_rect())
		if player_menu.details_panel and player_menu.details_panel.visible: rects.append(player_menu.details_panel.get_global_rect())
	if context_menu_panel and context_menu_panel.visible: rects.append(context_menu_panel.get_global_rect())
	return rects

func is_any_menu_open() -> bool:
	if player_menu and player_menu.visible: return true
	if inventory_gui and inventory_gui.visible: return true
	return false

func close_all_menus() -> void:
	if player_menu: player_menu.hide()
	hide_context_menu()
	close_inventory()

func set_selected_ally(ally: Node) -> void:
	if player_menu: player_menu.set_current_ally(ally)
