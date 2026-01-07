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
	
	# 0. Get the specific layer offset from LaneManager (e.g., Wire Offset)
	# This returns Vector3 in 3D
	var offset_vector = LaneManager.get_layer_offset(layer)
	
	# 1. Determine tile based on global position CORRECTED by the offset.
	# We subtract the offset to find the "Logical Center" of the tile this object belongs to.
	tile_coord = LaneManager.world_to_tile(parent.global_position - offset_vector)
	
	# 2. Check overlap logic strictly via Grid State
	var existing = LaneManager.get_entity_at(tile_coord, layer)
	if existing and existing != parent:
		print("GridComponent: Collision detected at %s layer %s. Destroying duplicate %s." % [tile_coord, layer, parent.name])
		parent.queue_free()
		return
	
	# 3. Enforce Grid Alignment (The Snap)
	# This moves the Parent Root to the Tile Center + Visual Offset
	if snap_to_grid:
		LaneManager.snap_node_to_grid(parent, layer)
		# Re-verify coord matches snapped position (should be exact same if offset logic works)
		tile_coord = LaneManager.world_to_tile(parent.global_position - offset_vector)
	
	# 4. Register to Grid Authority
	LaneManager.register_entity(parent, tile_coord, layer)
		
	parent.tree_exiting.connect(_unregister)

func _unregister() -> void:
	if tile_coord != Vector2i(-1, -1):
		# Only unregister if WE are the one registered
		var current = LaneManager.get_entity_at(tile_coord, layer)
		if current == get_parent():
			LaneManager.unregister_entity(tile_coord, layer)
