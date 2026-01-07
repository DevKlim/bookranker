class_name ItemResource
extends Resource

@export var item_name: String = "New Item"
@export var icon: Texture2D
@export var color: Color = Color.WHITE
@export var stack_size: int = 50
@export var is_projectile: bool = false

@export_group("Combat Specs")
@export var damage: float = 0.0
## If is_projectile is true, this scene is instantiated.
## Otherwise, the generic projectile scene is used with the item's icon.
@export var projectile_scene: PackedScene
@export var element: ElementResource
@export var modifiers: Dictionary = {}

@export_group("Ore Generation")
@export var is_ore: bool = false
@export var ore_block_name: String = ""
@export var min_depth: int = 0
@export var max_depth: int = 30
@export_range(0.0, 1.0) var rarity: float = 0.0
