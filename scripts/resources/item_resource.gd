class_name ItemResource
extends Resource

enum EquipmentType { NONE, TOOL, WEAPON, ARMOR, ACCESSORY }

@export var item_name: String = "New Item"
@export var icon: Texture2D
@export var color: Color = Color.WHITE
@export var stack_size: int = 50
@export var is_projectile: bool = false
@export var equipment_type: EquipmentType = EquipmentType.NONE

@export_group("Combat Specs")
## If this is a weapon, this resource defines its attack behavior.
@export var attack_config: AttackResource
@export var damage: float = 0.0
@export var projectile_scene: PackedScene
@export var element: ElementResource
## The strength/quantity of the element applied.
@export var element_units: int = 1 
## If true, this item ignores the target's internal elemental cooldown.
@export var ignore_element_cooldown: bool = false
@export var modifiers: Dictionary = {}

@export_group("Ore Generation")
@export var is_ore: bool = false
@export var ore_block_name: String = ""
@export var min_depth: int = 0
@export var max_depth: int = 30
@export_range(0.0, 1.0) var rarity: float = 0.0
## Number of times this ore is guaranteed to attempt spawning on map generation, before random chance.
@export var guaranteed_spawns: int = 0

@export_group("Tool Specs")
@export var is_tool: bool = false
@export_enum("none", "drill", "wrench") var tool_type: String = "none"
@export var action_time: float = 1.0
## Visual offset for the grid cursor when this tool is equipped.
@export var highlight_offset: Vector3 = Vector3(0, 0, 0)
