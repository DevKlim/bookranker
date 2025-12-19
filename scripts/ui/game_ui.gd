class_name GameUI
extends CanvasLayer

## Manages the main game UI elements, including the HUD, Inventory, and Builder Library.

@onready var debug_coords_label: Label = $DebugCoordsLabel
@onready var hotbar: PanelContainer = $Hotbar
@onready var dev_ui_panel: Panel = $DevUIPanel
@onready var inventory_gui: PanelContainer = $InventoryGUI

# Builder Library (The "All Items" menu)
var builder_library_panel: PanelContainer
var all_buildables: Array[BuildableResource] = []
var library_button: Button

func _ready() -> void:
	assert(debug_coords_label, "GameUI is missing DebugCoordsLabel!")
	debug_coords_label.text = "Tile (Physical): (-, -)\nTile (Relative): N/A"
	
	if inventory_gui:
		inventory_gui.hide()
		
	_initialize_builder_library()
	_setup_library_button()

func _process(_delta: float) -> void:
	# Keep the library button anchored near the hotbar
	if is_instance_valid(library_button) and is_instance_valid(hotbar):
		# Position to the right of the hotbar
		var hb_rect = hotbar.get_global_rect()
		library_button.global_position = Vector2(hb_rect.end.x + 10, hb_rect.position.y + (hb_rect.size.y - library_button.size.y) / 2)

func _setup_library_button() -> void:
	library_button = Button.new()
	library_button.text = "+"
	library_button.tooltip_text = "Open Item Library"
	library_button.custom_minimum_size = Vector2(32, 32)
	library_button.pressed.connect(toggle_builder_library)
	add_child(library_button)

func _initialize_builder_library() -> void:
	# Load all buildables from resources
	_load_all_buildables()
	
	# Create UI elements via code to avoid scene dependencies
	builder_library_panel = PanelContainer.new()
	builder_library_panel.name = "BuilderLibrary"
	builder_library_panel.visible = false
	
	# Center it
	builder_library_panel.anchors_preset = Control.PRESET_CENTER
	# Add some background styling or size
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.1, 0.9)
	builder_library_panel.add_theme_stylebox_override("panel", panel_style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	builder_library_panel.add_child(margin)
	
	var grid = GridContainer.new()
	grid.columns = 10
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	margin.add_child(grid)
	
	add_child(builder_library_panel)
	
	# Populate Grid
	for buildable in all_buildables:
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(64, 64)
		btn.icon = buildable.icon
		btn.expand_icon = true
		btn.tooltip_text = buildable.buildable_name
		
		# Define Drag Data
		# We use a Callable to handle the drag data generation to keep scope clean
		btn.set_drag_forwarding(Callable(self, "_get_library_drag_data").bind(buildable), Callable(), Callable())
		
		grid.add_child(btn)

func _load_all_buildables() -> void:
	var path = "res://resources/buildables/"
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var res = load(path + file_name)
				if res is BuildableResource:
					all_buildables.append(res)
			file_name = dir.get_next()
	else:
		printerr("GameUI: Could not access buildables directory.")

func _get_library_drag_data(_at_position: Vector2, buildable: BuildableResource) -> Variant:
	var preview = TextureRect.new()
	preview.texture = buildable.icon
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.size = Vector2(64, 64)
	preview.modulate = Color(1, 1, 1, 0.8)
	
	# GameUI is a CanvasLayer, not a Control, so we must call set_drag_preview on a Control child.
	builder_library_panel.set_drag_preview(preview)
	
	return { "type": "buildable", "resource": buildable }

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_inv"): # Ensure this action exists in Input Map
		toggle_builder_library()

func toggle_builder_library() -> void:
	if builder_library_panel.visible:
		builder_library_panel.hide()
	else:
		builder_library_panel.show()
		# Close other UIs
		close_inventory()

## Sets the text of the debug label.
func set_debug_text(text: String) -> void:
	if debug_coords_label:
		debug_coords_label.text = text

func open_inventory(inventory: InventoryComponent, title: String = "Storage", context: Object = null) -> void:
	if inventory_gui:
		inventory_gui.open(inventory, title, context)
		# Hide library if opening machine inventory
		if builder_library_panel: builder_library_panel.hide()

func close_inventory() -> void:
	if inventory_gui:
		inventory_gui.close()

func set_inventory_screen_position(screen_pos: Vector2) -> void:
	if inventory_gui and inventory_gui.visible:
		inventory_gui.global_position = screen_pos + Vector2(40, -inventory_gui.size.y / 2.0)

func get_ui_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = [hotbar.get_global_rect(), dev_ui_panel.get_global_rect()]
	if inventory_gui and inventory_gui.visible:
		rects.append(inventory_gui.get_global_rect())
	if builder_library_panel and builder_library_panel.visible:
		rects.append(builder_library_panel.get_global_rect())
	if library_button and library_button.visible:
		rects.append(library_button.get_global_rect())
	return rects
