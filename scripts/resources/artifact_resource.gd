class_name ArtifactResource
extends Resource

## Data-driven resource for Roguelike Artifacts or Run Modifiers.
## Easily moddable and fully compatible with the Data Importer.

@export var id: String = "artifact_01"
@export var artifact_name: String = "Unknown Artifact"
@export_multiline var description: String = ""
@export var icon: Texture2D

## Dictionary of global stat modifiers. 
## Examples: { "ally_health": 1.1, "ally_damage": 1.2, "building_efficiency": 1.5 }
@export var stat_multipliers: Dictionary = {}