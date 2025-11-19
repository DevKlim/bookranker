class_name RecipeResource
extends Resource

@export var recipe_name: String = "Recipe"
@export var input_item: ItemResource
@export var input_count: int = 1
@export var output_item: ItemResource
@export var output_count: int = 1
@export var craft_time: float = 2.0