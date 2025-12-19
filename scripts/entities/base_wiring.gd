class_name BaseWiring
extends Node2D

## Base class for wiring components like wires and levers.
## It provides common functionality without the health/power needs of BaseBuilding.

const GridComponentScript = preload("res://scripts/components/grid_component.gd")
var grid_component: Node

# Set by BuildManager during instantiation
var visual_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Apply Visual Offset to the main visual child
	var animated_sprite = get_node_or_null("AnimatedSprite2D")
	if animated_sprite:
		# Correction for visual misalignment (-0.5, -0.5 tile offset)
		# Assuming standard 32x16 iso tile? 0.5 logical unit might be 16x8 pixels.
		# However, usually map_to_local centers it.
		# If it's visually offset, we center it by setting it to (0,0) (centered) 
		# plus the explicit visual_offset from resource (usually 0,0 for wires).
		
		# NOTE: If user says it is currently offset by (-0.5, -0.5), we apply a fix
		# This is often due to texture offset or pivot. We force it to local 0,0 + offset.
		animated_sprite.position = visual_offset

	if not has_node("GridComponent"):
		grid_component = GridComponentScript.new()
		grid_component.name = "GridComponent"
		grid_component.layer = "wire"
		# Enable snapping for wires to ensure they hit the tile center Z-index correctly
		if "snap_to_grid" in grid_component:
			grid_component.snap_to_grid = true
		add_child(grid_component)
	else:
		grid_component = get_node("GridComponent")

func get_sprite_frames() -> SpriteFrames:
	var animated_sprite = get_node_or_null("AnimatedSprite2D")
	if is_instance_valid(animated_sprite):
		return animated_sprite.sprite_frames
	return null
