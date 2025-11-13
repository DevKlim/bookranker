extends Node

## Manages the overall state of the game (e.g., pre-wave, wave in progress).
## Emits signals when the state changes so other parts of the game can react.


## Signal emitted when the game state changes.
signal game_state_changed(new_state)
## Signal for game over, passing a boolean for win/loss.
signal game_over(player_won)


## Defines the possible states of the game.
enum GameState {
	PRE_WAVE,        # The time before a wave starts, for building and preparation.
	WAVE_IN_PROGRESS,# An enemy wave is currently active.
	POST_WAVE,       # The time after a wave is cleared, for rewards and upgrades.
	PAUSED,          # The game is paused.
	GAME_OVER        # The game has ended.
}


## The current state of the game.
var current_state: GameState = GameState.PRE_WAVE:
	# When the state is changed, emit a signal to notify listeners.
	set(value):
		if current_state != value:
			current_state = value
			emit_signal("game_state_changed", current_state)
			# For debugging, print the new state to the console.
			print("Game state changed to: ", GameState.keys()[current_state])


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("GameManager Initialized.")


## Ends the current game run.
func end_game(player_won: bool) -> void:
	# Only proceed if the game isn't already over.
	if current_state != GameState.GAME_OVER:
		self.current_state = GameState.GAME_OVER
		emit_signal("game_over", player_won)
		
		if not player_won:
			print("Game Over - The Core was destroyed.")
		
		# For now, this will close the game. In the future, it could
		# transition to a Game Over screen.
		get_tree().quit()
