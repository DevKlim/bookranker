class_name GridComponent
extends Node

## A component that registers the parent entity to the central LaneManager (Grid).
## Ensures that the entity is tracked in the grid_state and aligned visually.

@export var layer: String = "building" # Options: "building", "wire"
@export var snap_to_grid: bool = true

var tile_coord: Vector2i = Vector2i(-1, -1)

func _ready() -> void:
	# Don't register if parent is a preview ghost
	if get_parent().has_meta("is_preview"): return
	
	# Deferred to ensure parent's transform is ready and LaneManager is initialized
	call_deferred("_register")

func _register() -> void:
	var parent = get_parent()
	if not parent or not parent is Node3D: 
		printerr("GridComponent: Parent must be a Node3D.")
		return
	
	var offset_vector = LaneManager.get_layer_offset(layer)
	tile_coord = LaneManager.world_to_tile(parent.global_position - offset_vector)
	
	var existing = LaneManager.get_entity_at(tile_coord, layer)
	if existing and existing != parent:
		parent.queue_free()
		return
	
	if snap_to_grid:
		LaneManager.snap_node_to_grid(parent, layer)
		tile_coord = LaneManager.world_to_tile(parent.global_position - offset_vector)
	
	LaneManager.register_entity(parent, tile_coord, layer)
	parent.tree_exiting.connect(_unregister)

	# FIX: Ensure PowerGrid re-evaluates immediately so buildings on powered wires turn on.
	if layer == "building" and is_instance_valid(PowerGridManager):
		PowerGridManager.update_grid()

func _unregister() -> void:
	if tile_coord != Vector2i(-1, -1):
		var current = LaneManager.get_entity_at(tile_coord, layer)
		if current == get_parent():
			LaneManager.unregister_entity(tile_coord, layer)
			# FIX: Use global singleton check instead of absolute path to avoid tree exit errors
			if layer == "building" and is_instance_valid(PowerGridManager):
				PowerGridManager.update_grid()
