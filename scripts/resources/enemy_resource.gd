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
## Maximum HP capacity.
@export var max_health: float = 20.0
## Gives a separate flat health bar that can regenerate. No defenses are applied to it.
@export var security: float = 0.0
## Walking / Movement Speed.
@export var speed: float = 40.0
## Rate of weapon fire or melee strikes.
@export var process_speed: float = 1.0
## Flat bonus/Multiplier to physical attacks.
@export var attack_damage: float = 10.0
## Armor rating (flat damage reduction).
@export var defense: float = 0.0
## Multiplier scaling resistance to elemental debuffs.
@export var firewall: float = 0.0
## Magic damage scaling for spells, reactions, and ticks.
@export var networking: float = 0.0
## Physics mass. High space(weight) resists ragdolling.
@export var space: float = 10.0
## Critical hit chance and dodge percentage.
@export var luck_stat: float = 0.0
## Stamina / Energy consumption rate.
@export var compute: float = 1.0
## Size of entity/attack.
@export var scale: float = 1.0
## Mult against CC duration.
@export var ping: float = 1.0
## Vulnerability/Difficulty (+10% extra damage taken).
@export var malware: float = 0.0

@export var elemental_cd: float = 0.0
@export var elemental_resistances: Dictionary = {}

@export_subgroup("Shield Configuration")
@export var security_regen_delay: float = 5.0
@export var security_regen_time: float = 5.0

@export_subgroup("Innate Element")
@export var innate_element: ElementResource
@export var innate_reapply_interval: float = 1.0
@export var innate_instant_react: bool = true

@export_group("Formulas")
@export var max_health_equation: String = ""
@export var security_equation: String = ""
@export var speed_equation: String = ""
@export var process_speed_equation: String = ""
@export var attack_damage_equation: String = ""
@export var defense_equation: String = ""
@export var firewall_equation: String = ""
@export var networking_equation: String = ""
@export var space_equation: String = ""
@export var luck_stat_equation: String = ""
@export var compute_equation: String = ""
@export var scale_equation: String = ""
@export var ping_equation: String = ""
@export var malware_equation: String = ""
@export var stat_weights: Dictionary = {}

@export_group("Movement")
@export var wave_movement: WaveMovement = WaveMovement.BLOCK_BY_BLOCK
@export var field_movement: FieldMovement = FieldMovement.WANDER

@export_group("Combat")
@export var attack_element: ElementResource

@export_subgroup("Range Configuration")
@export var attack_range_depth: int = 1
@export var attack_range_width: int = 0

@export_group("Rewards")
@export var drops: Array =[]
