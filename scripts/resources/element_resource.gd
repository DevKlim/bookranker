class_name ElementResource
extends Resource

@export var element_name: String = "None"
@export var color: Color = Color.WHITE

## Dictionary defining what happens when this element touches another status.
## Format: { "existing_status_id": "reaction_name" }
@export var reaction_rules: Dictionary = {}

## Dictionary defining the status effect properties.
## E.g. { "damage_per_second": 5.0, "duration": 3.0, "stun": false }
@export var effect_data: Dictionary = {}
