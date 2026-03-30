class_name AllyResource
extends Resource

@export var ally_name: String = "Ally"
@export var scene: PackedScene
@export var icon: Texture2D

@export_group("Stats")
@export var health: float = 100.0
@export var speed: float = 5.0
@export var defense: float = 0.0
@export var weight: float = 10.0

@export_group("Formulas")
@export var speed_equation: String = ""
@export var health_equation: String = ""
@export var defense_equation: String = ""
@export var stat_weights: Dictionary = {}

@export_group("Inventory")
@export var inventory_slots: int = 8
@export var has_tool_slot: bool = true
@export var has_weapon_slot: bool = true
@export var has_armor_slot: bool = true
@export var has_artifact_slot: bool = true

@export_group("Respawns")
@export var respawns_count: int = 0
@export var respawns_unlimited: bool = false
@export var respawns_cooldown: float = 5.0

@export_group("Visuals")
@export var texture: Texture2D
