class_name BuildableResource
extends Resource

## Defines a buildable item for the game, including its type, scene/tile data, and UI info.

enum BuildLayer {
	WIRING, # For items like dust and levers, placed on the Wiring TileMap
	MECH,   # For items like turrets and drills, placed as scenes
	TOOL    # For non-placing tools like the remover
}

@export var buildable_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var layer: BuildLayer = BuildLayer.MECH

@export_group("Dimensions")
@export var width: int = 1
@export var height: int = 1

@export_group("Functional Settings")
@export var has_input: bool = true
@export var has_output: bool = true

@export_group("Visual Settings")
## The visual offset from the tile center (snapped position) for this building.
## Defaults to (0, -8) which centers a standard 32x32 sprite on a 32x16 isometric tile.
@export var display_offset: Vector2 = Vector2(0, -8)

## For MECH layer items
@export_group("Mech Settings")
@export var scene: PackedScene

## For WIRING layer items
@export_group("Wiring Settings")
@export var tile_source_id: int = 0
@export var tile_atlas_coords: Vector2i = Vector2i.ZERO
