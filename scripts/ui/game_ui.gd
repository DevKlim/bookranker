extends CanvasLayer

## Manages the main game UI elements.

@onready var debug_coords_label: Label = $DebugCoordsLabel
@onready var hotbar: PanelContainer = $Hotbar
@onready var dev_ui_panel: Panel = $DevUIPanel

func _ready() -> void:
	assert(debug_coords_label, "GameUI is missing DebugCoordsLabel!")
	debug_coords_label.text = "Tile (Physical): (-, -)\nTile (Relative): N/A"

## Updates the text of the debug label with physical and logical coordinates.
func update_debug_coords(physical: Vector2i, logical: Vector2i) -> void:
	var physical_text = "Tile (Physical): %s" % str(physical)
	var logical_text = "Tile (Relative): N/A"
	if logical.x != -1:
		logical_text = "Tile (Relative): (%d, %d)" % [logical.x, logical.y]
	debug_coords_label.text = physical_text + "\n" + logical_text

func get_ui_rects() -> Array[Rect2]:
	# Returns an array of global rectangles covered by UI elements
	return [hotbar.get_global_rect(), dev_ui_panel.get_global_rect()]
