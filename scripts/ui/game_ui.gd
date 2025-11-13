extends CanvasLayer

## Manages the main game UI elements.

@onready var debug_coords_label: Label = $DebugCoordsLabel

func _ready() -> void:
	assert(debug_coords_label, "GameUI is missing a Label named DebugCoordsLabel!")
	debug_coords_label.text = "Tile Coords: (-, -)"

## Updates the text of the debug label with the given coordinates.
func update_debug_coords(coords: Vector2i) -> void:
	debug_coords_label.text = "Tile Coords: %s" % str(coords)
