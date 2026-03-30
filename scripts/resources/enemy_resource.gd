class_name EnemyResource
extends Resource

## Defines an enemy type, its stats, visuals, and movement behavior.

enum WaveMovement {
	BLOCK_BY_BLOCK,
	CONTINUOUS
}

enum FieldMovement {
	WANDER,
	STATIC
}

@export var enemy_name: String = "Enemy"
@export var scene: PackedScene
@export var tags: Array[String] =[]

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

@export_group("Formulas")
@export var speed_equation: String = ""
@export var health_equation: String = ""
@export var defense_equation: String = ""
@export var stat_weights: Dictionary = {}

@export_group("Movement")
@export var wave_movement: WaveMovement = WaveMovement.BLOCK_BY_BLOCK
@export var field_movement: FieldMovement = FieldMovement.WANDER

@export_group("Combat")
@export var attack_damage: float = 10.0
@export var attack_speed: float = 1.0
@export var attack_element: ElementResource

@export_subgroup("Range Configuration")
## How many tiles in front (towards X=0) the enemy can attack.
@export var attack_range_depth: int = 1
## How many tiles sideways (Lanes) the enemy can attack. 0 = Same Lane Only.
@export var attack_range_width: int = 0

@export_group("Rewards")
## Array of dictionaries: { "item": "item_id", "min": 1, "max": 1, "chance": 1.0 }
@export var drops: Array =[]
