class_name RecipeResource
extends Resource

@export_enum("assembly", "smelting", "basic") var category: String = "assembly"
@export var recipe_name: String = "Recipe"
@export var tier: int = 1
@export var craft_time: float = 2.0

## Array of Dictionaries: { "resource": Resource, "count": int }
## Supports mixed ItemResource and BuildableResource
@export var inputs: Array = []

## Array of Dictionaries: { "resource": Resource, "count": int }
@export var outputs: Array = []

# Helper to get the "primary" output for UI display icons
func get_main_output() -> Resource:
	if outputs.is_empty(): return null
	return outputs[0].resource
