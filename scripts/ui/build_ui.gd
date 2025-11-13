extends Control

## This script handles the UI for building. It connects button presses
## to the BuildManager.


# Preload the turret scene so we can tell the BuildManager what to build.
@export var turret_scene: PackedScene


## Called when the "Build Turret" button is pressed.
func _on_build_turret_button_pressed() -> void:
	# This UI is deprecated. The functionality has moved to the hotbar.
	# For now, it will do nothing to prevent conflicts.
	# To use this again, you would need to adapt it to the new
	# BuildableResource system.
	
	# Example of old logic:
	# if turret_scene:
	# 	BuildManager.enter_build_mode(turret_scene)
	# else:
	# 	printerr("BuildTurretButton: turret_scene is not set!")
	pass
