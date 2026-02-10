class_name EnemyResource
extends Resource

## Defines an enemy type, its stats, visuals, and movement behavior.

enum MovementType {
	BLOCK_BY_BLOCK,
	CONTINUOUS
}

@export var enemy_name: String = "Enemy"
@export var scene: PackedScene

@export_group("Stats")
@export var health: float = 50.0
@export var speed: float = 40.0
@export var defense: float = 0.0
@export var weight: float = 10.0 ## Base mass of the enemy. Higher weight resists knockback.

## Higher Magical Defense increases the cooldown time before the same element
## can be applied to this unit again (Multiplier).
@export var magical_defense: float = 0.0
## Flat increase to elemental application cooldown (Seconds).
@export var elemental_cd: float = 0.0
## Key: Element ID (String), Value: Resistance % (0.0 to 1.0)
@export var elemental_resistances: Dictionary = {}
@export var innate_element: ElementResource

@export_group("Movement")
@export var movement_type: MovementType = MovementType.BLOCK_BY_BLOCK

@export_group("Combat")
@export var attack_damage: float = 10.0
@export var attack_speed: float = 1.0
@export var attack_element: ElementResource

@export_subgroup("Range Configuration")
## How many tiles in front (towards X=0) the enemy can attack.
@export var attack_range_depth: int = 1
## How many tiles sideways (Lanes) the enemy can attack. 0 = Same Lane Only.
@export var attack_range_width: int = 0

@export_group("Field Behavior")
## If true, this enemy can spawn naturally in the field.
@export var is_field_enemy: bool = false
@export var field_spawn_min_depth: int = 15
@export var field_spawn_max_depth: int = 60
## How often (seconds) the game attempts to spawn this enemy naturally.
@export var field_spawn_interval: float = 10.0
@export_range(0.0, 1.0) var field_spawn_chance: float = 0.5
@export var max_field_spawns: int = 5
## Distance at which a field enemy detects targets.
@export var aggro_range: float = 10.0
## Radius for random wandering when idle.
@export var wander_radius: float = 5.0
@export var idle_time: float = 2.0

@export_group("Rewards")
## Array of dictionaries: { "item": "item_id", "min": 1, "max": 1, "chance": 1.0 }
@export var drops: Array = []
