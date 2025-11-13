class_name BuildableResource
extends Resource

## Defines a buildable item for the game, including its type, scene/tile data, and UI info.

enum BuildLayer {
	WIRING, # For items like dust and levers, placed on the Wiring TileMap
	MECH    # For items like turrets and drills, placed as scenes
}

@export var buildable_name: String = ""
@export var icon: Texture2D
@export var layer: BuildLayer = BuildLayer.MECH

## For MECH layer items
@export_group("Mech Settings")
@export var scene: PackedScene

## For WIRING layer items
@export_group("Wiring Settings")
@export var tile_source_id: int = 0
@export var tile_atlas_coords: Vector2i = Vector2i.ZERO