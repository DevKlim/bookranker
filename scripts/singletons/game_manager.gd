extends Node

## Central manager for global game state, recipe database, and unlocks.

# Restored Enum to support referencing GameState.WAVE_IN_PROGRESS, PRE_WAVE, and POST_WAVE
enum GameState {
	IDLE,
	PRE_WAVE,
	WAVE_IN_PROGRESS,
	POST_WAVE
}

var current_state: GameState = GameState.IDLE

# Renamed the dictionary to 'game_data' to avoid conflict with the Enum
var game_data: Dictionary = {
	"wave": 0,
	"currency": 0
}

var _recipes: Array[RecipeResource] = []

func _ready() -> void:
	pass

func reset_state() -> void:
	_recipes.clear()
	game_data = { "wave": 0, "currency": 0 }
	current_state = GameState.IDLE

func register_recipes(list: Array[RecipeResource]) -> void:
	_recipes = list

func get_available_recipes() -> Array[RecipeResource]:
	return _recipes
