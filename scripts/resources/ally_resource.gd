class_name AllyResource
extends Resource

@export var ally_name: String = "Ally"
@export var scene: PackedScene
@export var icon: Texture2D

@export_group("Stats")
## Maximum HP capacity.
@export var max_health: float = 100.0
## Gives a separate flat health bar that can regenerate. No defenses are applied to it.
@export var security: float = 0.0
## Walking / Movement Speed.
@export var speed: float = 5.0
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

@export_group("Inventory Settings")
@export var inventory_slots: int = 8
@export var has_tool_slot: bool = true
@export var has_weapon_slot: bool = true
@export var has_armor_slot: bool = true
@export var has_artifact_slot: bool = true

@export_group("Respawns")
@export var respawns_count: int = 0
@export var respawns_unlimited: bool = false
@export var respawns_cooldown: float = 5.0

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
