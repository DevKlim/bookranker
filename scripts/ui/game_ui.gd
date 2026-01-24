class_name GameUI
extends CanvasLayer

## Manages the main game UI elements.

@onready var debug_coords_label: Label = $DebugCoordsLabel
@onready var hotbar: PanelContainer = $Hotbar
@onready var dev_ui_panel: Panel = $DevUIPanel
@onready var inventory_gui: PanelContainer = $InventoryGUI

var player_menu: PlayerMenu
var pause_menu: PauseMenu # Now typed as PauseMenu class
var network_stats_panel: PanelContainer
var network_stats_label: RichTextLabel
var notification_label: Label

const PAUSE_MENU_SCENE = preload("res://scenes/ui/pause_menu.tscn")

func _ready() -> void:
	# --- World Drop Zone Setup ---
	var drop_zone = WorldDropTarget.new()
	drop_zone.name = "WorldDropZone"
	drop_zone.set_anchors_preset(Control.PRESET_FULL_RECT)
	drop_zone.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(drop_zone)
	move_child(drop_zone, 0) # Ensure it is behind other UI elements
	# -----------------------------

	_setup_network_stats_ui()
	_setup_pause_menu_instance()
	_setup_notification_label()

	if debug_coords_label:
		debug_coords_label.text = "Tile (Physical): (-, -)\nTile (Relative): N/A"
	if inventory_gui: 
		inventory_gui.hide()
	
	if is_instance_valid(GameManager):
		GameManager.reset_state()
		_initialize_recipe_database()
	
	# Instantiate Player Menu
	player_menu = PlayerMenu.new()
	player_menu.name = "PlayerMenu"
	player_menu.visible = false
	
	# Style the Panel
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.95)
	player_menu.add_theme_stylebox_override("panel", style)
	
	# Center it
	player_menu.anchors_preset = Control.PRESET_CENTER
	player_menu.custom_minimum_size = Vector2(600, 500)
	
	add_child(player_menu)

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
	notification_label.position = Vector2(0, -150) # Just above hotbar roughly

func show_notification(text: String, color: Color = Color.WHITE) -> void:
	if not notification_label: return
	notification_label.text = text
	notification_label.modulate = color
	notification_label.modulate.a = 1.0
	
	# Center horizontally at bottom
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
		pause_menu.show()
		pause_menu.focus_resume()
		get_tree().paused = true

func is_pause_menu_open() -> bool:
	return pause_menu.visible

func _setup_network_stats_ui() -> void:
	network_stats_panel = PanelContainer.new()
	network_stats_panel.name = "NetworkStats"
	network_stats_panel.visible = false
	
	# Styling for visibility
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.05, 0.9)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.4, 0.6, 1.0, 0.5) # Neon blue accent
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	network_stats_panel.add_theme_stylebox_override("panel", style)
	
	add_child(network_stats_panel)
	
	# Correct Positioning: Top Right
	network_stats_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	network_stats_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	
	network_stats_panel.position = Vector2.ZERO 
	network_stats_panel.offset_top = 80
	network_stats_panel.offset_right = -20
	
	network_stats_panel.custom_minimum_size = Vector2(250, 0)
	
	network_stats_label = RichTextLabel.new()
	network_stats_label.fit_content = true
	network_stats_label.bbcode_enabled = true
	network_stats_label.scroll_active = false
	network_stats_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	network_stats_panel.add_child(network_stats_label)

func show_network_stats(stats: Dictionary) -> void:
	if stats.is_empty():
		network_stats_panel.visible = false
		return
	
	var status = stats.get("status", "Unknown")
	var status_color = "white"
	match status:
		"Stable": status_color = "green"
		"Overloaded": status_color = "red"
		"Unpowered": status_color = "yellow"
		"Idle": status_color = "gray"

	var txt = "[b][color=#44aaff]Wire Network Stats[/color][/b]\n"
	txt += "[color=#666666]-----------------------[/color]\n"
	txt += "Status: [color=%s]%s[/color]\n" % [status_color, status]
	txt += "Wires: %d\n" % stats.get("wire_count", 0)
	txt += "Generators: %d\n" % stats.get("generator_count", 0)
	txt += "Consumers: %d\n" % stats.get("consumer_count", 0)
	
	var gen = stats.get("total_generation", 0.0)
	var dem = stats.get("total_demand", 0.0)
	
	txt += "Power Gen: [color=green]%.1f W[/color]\n" % gen
	txt += "Demand: [color=orange]%.1f W[/color]\n" % dem
	
	var net = stats.get("net_power", 0.0)
	var net_color = "green" if net >= 0 else "red"
	txt += "Net Power: [color=%s]%.1f W[/color]" % [net_color, net]
	
	network_stats_label.text = txt
	network_stats_panel.visible = true
	
	# Force update layout to prevent 0-size glitches on first show
	network_stats_panel.reset_size()

func hide_network_stats() -> void:
	network_stats_panel.visible = false

# Handles logic when dropping an item from UI into the world
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
		
		# Validation
		if not source_inv.slots[data.slot_index] or source_inv.slots[data.slot_index].item != item:
			return

		# Priority 1: Smart Insert via receive_item
		if target.has_method("receive_item"):
			var success = target.receive_item(item)
			
			if success:
				source_inv.remove_item(item, 1) 
				if count_to_add > 1:
					# Try to add remainder
					for i in range(count_to_add - 1):
						if not target.receive_item(item):
							break
						source_inv.remove_item(item, 1)
				return

		# Priority 2: Direct Inventory Access (Legacy/Fallback)
		var inv_comp = target.get("inventory_component")
		if not inv_comp: inv_comp = target.get_node_or_null("InventoryComponent")
		if not inv_comp: inv_comp = target.get_node_or_null("InputInventory")
		
		if inv_comp and inv_comp.has_method("add_item") and inv_comp.has_space_for(item):
			var remainder = inv_comp.add_item(item, count_to_add)
			var taken = count_to_add - remainder
			
			if taken > 0:
				source_inv.remove_item(item, taken)
				print("Dropped %d %s into %s" % [taken, item.item_name, target.name])

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
		if is_instance_valid(GameManager):
			GameManager.register_recipes(recipes)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_inv"): 
		# If pause menu is open, don't allow opening inventory
		if is_pause_menu_open(): return
		toggle_player_menu()

func toggle_player_menu() -> void:
	if player_menu.visible:
		player_menu.hide()
	else:
		player_menu.show()
		close_inventory() # Close machine inventory if open

func set_debug_text(text: String) -> void:
	if debug_coords_label: debug_coords_label.text = text

func open_inventory(inventory: InventoryComponent, title: String = "Storage", context: Object = null) -> void:
	if inventory_gui:
		inventory_gui.open(inventory, title, context)
		if player_menu: player_menu.hide()

func close_inventory() -> void:
	if inventory_gui: inventory_gui.close()

func set_inventory_screen_position(screen_pos: Vector2) -> void:
	if inventory_gui and inventory_gui.visible:
		inventory_gui.global_position = screen_pos + Vector2(40, -inventory_gui.size.y / 2.0)

func get_ui_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	if hotbar: rects.append(hotbar.get_global_rect())
	if dev_ui_panel: rects.append(dev_ui_panel.get_global_rect())
	if inventory_gui and inventory_gui.visible:
		rects.append(inventory_gui.get_global_rect())
	if player_menu and player_menu.visible:
		rects.append(player_menu.get_global_rect())
	return rects

func is_any_menu_open() -> bool:
	if player_menu and player_menu.visible: return true
	if inventory_gui and inventory_gui.visible: return true
	return false

func close_all_menus() -> void:
	if player_menu: player_menu.hide()
	close_inventory()
