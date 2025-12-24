class_name ItemResource
extends Resource

@export var item_name: String = "Item"
@export var icon: Texture2D
@export var color: Color = Color.WHITE
@export var stack_size: int = 50
@export var damage: float = 10.0

## The element associated with this item.
## Typed as Resource to prevent parsing order errors, but expects ElementResource.
@export var element: Resource

## Dictionary for building mods (e.g., {"damage_multiplier": 1.5})
@export var modifiers: Dictionary = {}

@export_group("Ore Data")
## If true, LaneManager will treat this item as a valid ore to generate on the map.
@export var is_ore: bool = false
## The coordinates on the Ore Tileset Atlas (Source 0) for this ore.
@export var ore_atlas_coords: Vector2i = Vector2i.ZERO
