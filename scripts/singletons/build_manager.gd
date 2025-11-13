extends Node

## Manages the player's building actions. Tracks build mode status,
## which buildable is currently selected, and placement on the grid.

signal build_mode_changed(is_building)
signal selected_buildable_changed(buildable_resource)
signal build_rotation_changed(new_rotation_degrees)

var is_building: bool = false:
	set(value):
		if is_building != value:
			is_building = value
			emit_signal("build_mode_changed", is_building)

var selected_buildable: BuildableResource = null:
	set(value):
		if selected_buildable != value:
			selected_buildable = value
			emit_signal("selected_buildable_changed", selected_buildable)

var build_rotation_degrees: float = 0.0

var tile_map: TileMapLayer
var wiring_layer: TileMapLayer
var _occupied_mech_tiles: Dictionary = {}
var _occupied_wiring_tiles: Dictionary = {}

func _ready() -> void:
	print("BuildManager Initialized.")
	call_deferred("_initialize_tilemaps")

func _initialize_tilemaps() -> void:
	var main_scene = get_tree().current_scene
	if main_scene:
		tile_map = main_scene.get_node_or_null("TileMapLayer")
		wiring_layer = main_scene.get_node_or_null("WiringLayer")
	
	if not is_instance_valid(tile_map):
		printerr("BuildManager: Could not find TileMapLayer node!")
	if not is_instance_valid(wiring_layer):
		printerr("BuildManager: Could not find WiringLayer node!")

func enter_build_mode(buildable_to_build: BuildableResource) -> void:
	self.selected_buildable = buildable_to_build
	self.is_building = true
	self.build_rotation_degrees = 0.0 # Reset rotation
	emit_signal("build_rotation_changed", build_rotation_degrees)
	print("Entering build mode for: ", buildable_to_build.buildable_name)

func exit_build_mode() -> void:
	self.is_building = false
	self.selected_buildable = null
	self.build_rotation_degrees = 0.0
	print("Exiting build mode.")

func rotate_buildable() -> void:
	if not is_building: return
	build_rotation_degrees = fmod(build_rotation_degrees + 90.0, 360.0)
	emit_signal("build_rotation_changed", build_rotation_degrees)


func can_build_at(world_position: Vector2) -> bool:
	if not is_instance_valid(tile_map) or not selected_buildable:
		return false

	var tile_coord = tile_map.local_to_map(world_position)
	var has_tile = tile_map.get_cell_source_id(tile_coord) != -1
	if not has_tile:
		return false

	match selected_buildable.layer:
		BuildableResource.BuildLayer.MECH:
			return not _occupied_mech_tiles.has(tile_coord)
		BuildableResource.BuildLayer.WIRING:
			# Allow placing wires under mechs.
			return not _occupied_wiring_tiles.has(tile_coord)
	
	return false

func place_buildable(world_position: Vector2) -> void:
	if not is_building or not selected_buildable or not can_build_at(world_position):
		return

	var tile_coord = tile_map.local_to_map(world_position)
	
	match selected_buildable.layer:
		BuildableResource.BuildLayer.MECH:
			_place_mech(tile_coord)
		BuildableResource.BuildLayer.WIRING:
			_place_wiring(tile_coord)


func remove_buildable_at(world_position: Vector2) -> void:
	if not is_instance_valid(tile_map): return
	
	var tile_coord = tile_map.local_to_map(world_position)
	
	# Priority: Remove mech first, then wiring.
	if _occupied_mech_tiles.has(tile_coord):
		var building = _occupied_mech_tiles[tile_coord]
		if is_instance_valid(building):
			building.queue_free() # The _on_mech_destroyed callback will handle cleanup.
		else: # If instance is invalid, clean up dictionary manually.
			_occupied_mech_tiles.erase(tile_coord)
		print("Removed mech at ", tile_coord)
	elif _occupied_wiring_tiles.has(tile_coord):
		wiring_layer.set_cell(tile_coord, -1) # -1 source_id clears the tile.
		_occupied_wiring_tiles.erase(tile_coord)
		print("Removed wiring at ", tile_coord)


func _place_mech(tile_coord: Vector2i):
	var snapped_position = tile_map.map_to_local(tile_coord)
	var new_instance = selected_buildable.scene.instantiate()
	var buildings_container = get_tree().current_scene.get_node("Buildings")
	buildings_container.add_child(new_instance)
	new_instance.global_position = snapped_position
	new_instance.rotation_degrees = build_rotation_degrees # Apply rotation
	
	_occupied_mech_tiles[tile_coord] = new_instance
	new_instance.tree_exiting.connect(_on_mech_destroyed.bind(tile_coord))
	print("Placed mech '%s' at tile %s" % [selected_buildable.buildable_name, tile_coord])


func _place_wiring(tile_coord: Vector2i):
	wiring_layer.set_cell(
		tile_coord, 
		selected_buildable.tile_source_id, 
		selected_buildable.tile_atlas_coords
	)
	_occupied_wiring_tiles[tile_coord] = true # Just mark as occupied.
	print("Placed wiring '%s' at tile %s" % [selected_buildable.buildable_name, tile_coord])


func register_preplaced_building(building_node: Node2D) -> void:
	await get_tree().process_frame
	if not is_instance_valid(tile_map) or not is_instance_valid(building_node): return

	var tile_coord = tile_map.local_to_map(building_node.global_position)
	if not _occupied_mech_tiles.has(tile_coord):
		_occupied_mech_tiles[tile_coord] = building_node
		building_node.tree_exiting.connect(_on_mech_destroyed.bind(tile_coord))
		print("Pre-placed building '%s' registered at tile %s" % [building_node.name, tile_coord])

func _on_mech_destroyed(tile_coord: Vector2i):
	if _occupied_mech_tiles.has(tile_coord):
		_occupied_mech_tiles.erase(tile_coord)
		print("Mech tile ", tile_coord, " is now free.")