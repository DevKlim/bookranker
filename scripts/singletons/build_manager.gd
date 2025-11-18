extends Node

signal build_mode_changed(is_building)
signal selected_buildable_changed(buildable_resource)
signal build_rotation_changed(new_rotation_anim_name)

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

const ROTATION_ANIMS: Array[StringName] = [&"idle_down", &"idle_left", &"idle_up", &"idle_right"]
var _current_rotation_index: int = 0

var tile_map: TileMapLayer
var _occupied_mech_tiles: Dictionary = {}

@onready var wiring_manager = get_node("/root/WiringManager")

func _ready():
	call_deferred("_initialize_tilemaps")

func _initialize_tilemaps():
	var main = get_tree().current_scene
	tile_map = main.get_node_or_null("TileMapLayer")

func enter_build_mode(buildable: BuildableResource):
	self.selected_buildable = buildable
	self.is_building = true
	_current_rotation_index = 0
	emit_signal("build_rotation_changed", ROTATION_ANIMS[0])

func exit_build_mode():
	self.is_building = false
	self.selected_buildable = null

func rotate_buildable():
	if not is_building: return
	if selected_buildable and selected_buildable.layer != BuildableResource.BuildLayer.MECH:
		return # Only mechs can be rotated for now
	_current_rotation_index = (_current_rotation_index + 1) % ROTATION_ANIMS.size()
	emit_signal("build_rotation_changed", ROTATION_ANIMS[_current_rotation_index])

func can_build_at(pos: Vector2) -> bool:
	if not selected_buildable: return false
	var tile_coord = tile_map.local_to_map(pos)
	if tile_map.get_cell_source_id(tile_coord) == -1: return false

	match selected_buildable.layer:
		BuildableResource.BuildLayer.MECH: return not _occupied_mech_tiles.has(tile_coord)
		BuildableResource.BuildLayer.WIRING: return not wiring_manager.has_wire(tile_coord)
		BuildableResource.BuildLayer.TOOL: return has_removable_at(pos)
	return false

func has_removable_at(world_pos: Vector2) -> bool:
	var tile_coord = tile_map.local_to_map(world_pos)
	return _occupied_mech_tiles.has(tile_coord) or wiring_manager.has_wire(tile_coord)

func place_buildable(pos: Vector2):
	if not is_building or not selected_buildable or not can_build_at(pos): return
	var tile_coord = tile_map.local_to_map(pos)

	match selected_buildable.layer:
		BuildableResource.BuildLayer.MECH: _place_mech(tile_coord)
		BuildableResource.BuildLayer.WIRING: _place_wiring(tile_coord)
		BuildableResource.BuildLayer.TOOL: _remove_at_tile(tile_coord)
	

func remove_buildable_at(pos: Vector2):
	_remove_at_tile(tile_map.local_to_map(pos))

func _remove_at_tile(coord: Vector2i):
	if _occupied_mech_tiles.has(coord):
		var building = _occupied_mech_tiles[coord]
		if is_instance_valid(building): building.queue_free()
		else: _occupied_mech_tiles.erase(coord)
	elif wiring_manager.has_wire(coord):
		wiring_manager.remove_wire(coord)

func _place_mech(coord: Vector2i):
	var snapped_pos = tile_map.map_to_local(coord)
	var instance = selected_buildable.scene.instantiate()
	get_tree().current_scene.get_node("Buildings").add_child(instance)
	instance.global_position = snapped_pos + Vector2(0, -8)
	if instance.has_method("set_build_rotation"):
		instance.set_build_rotation(ROTATION_ANIMS[_current_rotation_index])
	
	_occupied_mech_tiles[coord] = instance
	LaneManager.register_buildable_at_tile(instance, coord)
	instance.tree_exiting.connect(_on_mech_destroyed.bind(coord))

func _place_wiring(coord: Vector2i):
	var snapped_pos = tile_map.map_to_local(coord)
	var instance = selected_buildable.scene.instantiate()
	get_tree().current_scene.get_node("Wiring").add_child(instance)
	instance.global_position = snapped_pos + Vector2(0, -8)

	wiring_manager.add_wire(coord, instance)
	instance.tree_exiting.connect(wiring_manager.remove_wire.bind(coord))


func register_preplaced_building(node: Node2D):
	await get_tree().process_frame
	var coord = tile_map.local_to_map(node.global_position)
	if not _occupied_mech_tiles.has(coord):
		_occupied_mech_tiles[coord] = node
		LaneManager.register_buildable_at_tile(node, coord)
		node.tree_exiting.connect(_on_mech_destroyed.bind(coord))

func _on_mech_destroyed(coord: Vector2i):
	if _occupied_mech_tiles.has(coord):
		_occupied_mech_tiles.erase(coord)
		LaneManager.unregister_buildable_at_tile(coord)

func get_mech_at(coord: Vector2i) -> Node2D:
	return _occupied_mech_tiles.get(coord, null)

