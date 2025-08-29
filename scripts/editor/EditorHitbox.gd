@tool
extends ColorRect

## The frame this hitbox becomes active (inclusive).
@export var start_frame: int = 0
## The frame this hitbox becomes inactive (exclusive).
@export var end_frame: int = 1

func _enter_tree():
	# This runs in the editor when the node is added to the scene.
	if Engine.is_editor_hint():
		# Use a unique name to avoid conflicts when adding multiple.
		name = "EditorHitbox_" + str(randi_range(1000, 9999))
		
		# Set visual properties.
		color = Color(1.0, 0.2, 0.2, 0.5) # Red, semi-transparent
		
		# Set a default size if it's new.
		if size == Vector2(0, 0):
			size = Vector2(40, 20)
			position = Vector2(-20, -10) # Center it initially