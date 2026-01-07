class_name EnemyResource
extends Resource

## Defines an enemy type, its stats, and visuals.

@export var enemy_name: String = "Enemy"
@export var scene: PackedScene

@export_group("Stats")
@export var health: float = 50.0
@export var speed: float = 40.0
@export var defense: float = 0.0
## Key: Element ID (String), Value: Resistance % (0.0 to 1.0)
@export var elemental_resistances: Dictionary = {}
@export var innate_element: ElementResource

@export_group("Combat")
@export var attack_damage: float = 10.0
@export var attack_speed: float = 1.0
@export var attack_element: ElementResource

@export_group("Rewards")
## Array of dictionaries: { "item": "item_id", "min": 1, "max": 1, "chance": 1.0 }
@export var drops: Array = []
