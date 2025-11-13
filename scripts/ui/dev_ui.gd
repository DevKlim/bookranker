extends Panel

## Handles the developer UI buttons for controlling waves.

func _on_spawn_wave_button_pressed() -> void:
	WaveManager.start_wave()

func _on_stop_wave_button_pressed() -> void:
	WaveManager.stop_wave()
