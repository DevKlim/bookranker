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
var _current_build_layout: Array[Vector2i] = [Vector2i.ZERO]

var tile_map: TileMapLayer

@onready var wiring_manager = get_node("/root/WiringManager")
@onready var lane_manager = get_node("/root/LaneManager")

func _ready():
	call_deferred("_initialize_tilemaps")

func _initialize_tilemaps():
	var main = get_tree().current_scene
	tile_map = main.get_node_or_null("TileMapLayer")

func enter_build_mode(buildable: BuildableResource):
	self.selected_buildable = buildable
	self.is_building = true
	_current_rotation_index = 0
	_update_current_layout_cache(ROTATION_ANIMS[0])
	emit_signal("build_rotation_changed", ROTATION_ANIMS[0])

func exit_build_mode():
	self.is_building = false
	self.selected_buildable = null

func rotate_buildable():
	if not is_building: return
	if selected_buildable and selected_buildable.layer != BuildableResource.BuildLayer.MECH:
		return 
	_current_rotation_index = (_current_rotation_index + 1) % ROTATION_ANIMS.size()
	var new_anim = ROTATION_ANIMS[_current_rotation_index]
	_update_current_layout_cache(new_anim)
	emit_signal("build_rotation_changed", new_anim)

func _update_current_layout_cache(anim_name: StringName) -> void:
	_current_build_layout = [Vector2i.ZERO]
	
	if not selected_buildable or not selected_buildable.scene: return
	
	var temp = selected_buildable.scene.instantiate()
	if temp.has_method("get_occupied_cells"):
		_current_build_layout = temp.get_occupied_cells(anim_name)
	else:
		var w = selected_buildable.width
		var h = selected_buildable.height
		if _current_rotation_index % 2 != 0:
			var swap = w; w = h; h = swap
		
		_current_build_layout.clear()
		for x in range(w):
			for y in range(h):
				_current_build_layout.append(Vector2i(x, y))
	temp.queue_free()

func _get_active_offset() -> Vector2:
	if not selected_buildable: return Vector2.ZERO
	if selected_buildable.layer == BuildableResource.BuildLayer.MECH:
		return lane_manager.get_layer_offset("building")
	elif selected_buildable.layer == BuildableResource.BuildLayer.WIRING:
		return lane_manager.get_layer_offset("wire")
	return Vector2.ZERO

func can_build_at(pos: Vector2) -> bool:
	if not selected_buildable: return false
	
	# Un-apply the visual offset to find the logical tile we are hovering over
	var offset = _get_active_offset()
	var origin_tile = LaneManager.world_to_tile(pos - offset)
	
	# New Check: Always ensure we are clicking on valid TileMap ground,
	# even if LaneManager logic says the lane is valid.
	if is_instance_valid(tile_map) and tile_map.get_cell_source_id(origin_tile) == -1:
		return false
	
	if selected_buildable.layer == BuildableResource.BuildLayer.MECH:
		var dynamic_layout = _get_dynamic_layout(origin_tile)
		for tile_offset in dynamic_layout:
			var t = origin_tile + tile_offset
			if not lane_manager.is_valid_tile(t): return false
			if lane_manager.get_entity_at(t, "building") != null: return false
		return true

	# Wires check: valid tile OR valid lane (relaxed check for flexibility)
	if selected_buildable.layer == BuildableResource.BuildLayer.WIRING:
		# Wires can be built anywhere there is ground, unless it clashes with existing wire
		return lane_manager.get_entity_at(origin_tile, "wire") == null

	# Check valid lane logic for other things
	if not lane_manager.is_valid_tile(origin_tile): return false

	if selected_buildable.layer == BuildableResource.BuildLayer.TOOL:
		return has_removable_at(pos)
		
	return false

func has_removable_at(world_pos: Vector2) -> bool:
	# Check for removal by accounting for offsets of both layers
	var b_offset = lane_manager.get_layer_offset("building")
	var w_offset = lane_manager.get_layer_offset("wire")
	
	var tile_b = LaneManager.world_to_tile(world_pos - b_offset)
	if lane_manager.get_entity_at(tile_b, "building") != null:
		return true
		
	var tile_w = LaneManager.world_to_tile(world_pos - w_offset)
	if lane_manager.get_entity_at(tile_w, "wire") != null:
		return true
		
	return false

func place_buildable(pos: Vector2):
	if not is_building or not selected_buildable or not can_build_at(pos): return
	
	# Calculate logical tile using the offset
	var offset = _get_active_offset()
	var tile_coord = LaneManager.world_to_tile(pos - offset)

	match selected_buildable.layer:
		BuildableResource.BuildLayer.MECH: _place_mech(tile_coord)
		BuildableResource.BuildLayer.WIRING: _place_wiring(tile_coord)
		BuildableResource.BuildLayer.TOOL: remove_buildable_at(pos) # Pass pos to handle dual offsets

func remove_buildable_at(pos: Vector2):
	# We need to check both layers with their respective offsets
	var b_offset = lane_manager.get_layer_offset("building")
	var w_offset = lane_manager.get_layer_offset("wire")
	
	var tile_b = LaneManager.world_to_tile(pos - b_offset)
	var tile_w = LaneManager.world_to_tile(pos - w_offset)
	
	_remove_at_tile(tile_b, "building")
	_remove_at_tile(tile_w, "wire")

func _remove_at_tile(coord: Vector2i, layer_filter: String = ""):
	# If filter is empty, try both (legacy behavior, though risky with offsets)
	# If filter provided, remove only that layer at that coord
	
	if layer_filter == "" or layer_filter == "building":
		var building = lane_manager.get_entity_at(coord, "building")
		if building and is_instance_valid(building):
			building.queue_free()
	
	if layer_filter == "" or layer_filter == "wire":
		var wire = lane_manager.get_entity_at(coord, "wire")
		if wire and is_instance_valid(wire):
			wire.queue_free()

func _place_mech(coord: Vector2i):
	# Snap to the exact tile center defined by LaneManager + Building Offset
	var snapped_pos = LaneManager.tile_to_world(coord) + LaneManager.get_layer_offset("building")
	var instance = selected_buildable.scene.instantiate()
	
	# PLACE ROOT AT CENTER.
	instance.global_position = snapped_pos
	
	# Pass the display offset to the instance if it has a setter
	if "visual_offset" in instance:
		instance.visual_offset = selected_buildable.display_offset
	
	get_tree().current_scene.get_node("Buildings").add_child(instance)
	
	if instance.has_method("set_build_rotation"):
		instance.set_build_rotation(ROTATION_ANIMS[_current_rotation_index])
	
	# Register extra tiles manually. Primary tile is registered by GridComponent.
	var dynamic_layout = _get_dynamic_layout(coord)
	for tile_offset in dynamic_layout:
		var t = coord + tile_offset
		if t != coord: 
			LaneManager.register_entity(instance, t, "building")

func _place_wiring(coord: Vector2i):
	# Snap to the exact tile center + Wire Offset
	var snapped_pos = LaneManager.tile_to_world(coord) + LaneManager.get_layer_offset("wire")
	var instance = selected_buildable.scene.instantiate()
	
	# Place root at center
	instance.global_position = snapped_pos
	
	# Pass offset for visual correction
	if "visual_offset" in instance:
		instance.visual_offset = selected_buildable.display_offset
	
	get_tree().current_scene.get_node("Wiring").add_child(instance)

	wiring_manager.add_wire(coord, instance)
	instance.tree_exiting.connect(wiring_manager.remove_wire.bind(coord))

func register_preplaced_building(node: Node2D):
	# Used for Core
	# Assume Core follows building offset logic
	var offset = lane_manager.get_layer_offset("building")
	var tile = LaneManager.world_to_tile(node.global_position - offset)
	LaneManager.register_entity(node, tile, "building")

func get_mech_at(coord: Vector2i) -> Node2D:
	return lane_manager.get_entity_at(coord, "building")

func _get_dynamic_layout(origin: Vector2i) -> Array[Vector2i]:
	var log_origin = lane_manager.get_logical_from_tile(origin)
	if log_origin == Vector2i(-1, -1):
		return _current_build_layout 
	
	var result: Array[Vector2i] = []
	for rigid_offset in _current_build_layout:
		if rigid_offset == Vector2i.ZERO:
			result.append(Vector2i.ZERO)
			continue
			
		var target_log = log_origin
		var valid = false
		if rigid_offset == Vector2i(0, -1):
			target_log.y += 1; valid = true
		elif rigid_offset == Vector2i(0, 1):
			target_log.y -= 1; valid = true
		elif rigid_offset == Vector2i(1, 0):
			target_log.x -= 1; valid = true
		elif rigid_offset == Vector2i(-1, 0):
			target_log.x += 1; valid = true
			
		if valid:
			var target_phys = lane_manager.get_tile_from_logical(target_log.x, target_log.y)
			if target_phys != Vector2i(-1, -1):
				result.append(target_phys - origin)
				continue
		result.append(rigid_offset)
	return result
