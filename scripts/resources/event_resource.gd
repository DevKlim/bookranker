class_name EventResource
extends Resource

@export var id: String = "unknown_event"
@export var event_name: String = "Random Event"
@export_multiline var description: String = ""
@export var icon: Texture2D

@export_group("Event Conditions")
@export var min_level: int = 1
@export var weight: float = 1.0

@export_group("Event Mechanics")
@export var effect_type: String = ""
@export var duration: float = 0.0
@export var parameters: Dictionary = {}
