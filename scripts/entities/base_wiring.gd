class_name BaseWiring
extends Node2D

## Base class for wiring components like wires and levers.
## It provides common functionality without the health/power needs of BaseBuilding.

# A helper to get the main sprite's frames, used by the build preview.
func get_sprite_frames() -> SpriteFrames:
	var animated_sprite = get_node_or_null("AnimatedSprite2D")
	if is_instance_valid(animated_sprite):
		return animated_sprite.sprite_frames
	return null
