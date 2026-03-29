class_name BaseWiring
extends Node3D

## Base class for wiring components like wires and levers.
## It provides common functionality without the health/power needs of BaseBuilding.

var grid_component: Node

# Set by BuildManager during instantiation
var visual_offset: Vector3 = Vector3.ZERO

func _ready() -> void:
	if visual_offset != Vector3.ZERO:
		for child in get_children():
			if child.name == "GridComponent": continue
			if child is Node3D:
				child.position += visual_offset

	if not has_node("GridComponent"):
		# Use class_name directly
		grid_component = GridComponent.new()
		grid_component.name = "GridComponent"
		grid_component.layer = "wire"
		# Enable snapping for wires to ensure they hit the tile center Z-index correctly
		if "snap_to_grid" in grid_component:
			grid_component.snap_to_grid = true
		add_child(grid_component)
	else:
		grid_component = get_node("GridComponent")

func get_sprite_frames() -> SpriteFrames:
	var animated_sprite = get_node_or_null("AnimatedSprite3D")
	if is_instance_valid(animated_sprite):
		return animated_sprite.sprite_frames
	return null

# Virtual methods to prevent crashes if subclass is missing/detached
# Underscore prefix indicates unused parameters in base class implementation
func set_powered(_is_powered: bool) -> void:
	pass

func set_connections(_connections: Array[int]) -> void:
	pass

