class_name ElementResource
extends Resource

@export var element_name: String = "None"
@export var icon: Texture2D
@export var color: Color = Color.WHITE
@export var duration: float = 5.0

## Time in seconds before this specific element can be applied to the same target again.
## e.g. Super Plasma might have 0.5s to prevent instant re-proc.
@export var application_cooldown: float = 0.0

@export_group("Formulas")
@export var damage_equation: String = ""
@export var cooldown_equation: String = ""
@export var unit_equation: String = ""
@export var reaction_damage_equation: String = ""
@export var cc_scaling_equation: String = ""
@export var stat_weights: Dictionary = {}

@export var reaction_rules: Dictionary = {}
@export var stat_modifiers: Dictionary = {}
@export var effect_script: Script
