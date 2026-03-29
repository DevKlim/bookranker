extends Node

signal build_mode_changed(is_building)
signal selected_buildable_changed(buildable_resource)
signal build_rotation_changed(new_rotation_val)
signal remove_mode_changed(mode)

enum RemoveMode { ALL, BUILDING_ONLY, WIRE_ONLY }
var current_remove_mode: RemoveMode = RemoveMode.ALL

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

var current_rotation_index: int = 0
var _current_build_layout: Array[Vector2i] =[Vector2i.ZERO]

@onready var wiring_manager = get_node("/root/WiringManager")
@onready var lane_manager = get_node("/root/LaneManager")

var grid_map: GridMap = null

func initialize_grid(map: GridMap):
	grid_map = map

func enter_build_mode(buildable: BuildableResource):
	self.selected_buildable = buildable
	self.is_building = true
	current_rotation_index = 0
	_update_current_layout_cache()
	emit_signal("build_rotation_changed", current_rotation_index)

func exit_build_mode():
	self.is_building = false
	self.selected_buildable = null

func rotate_buildable():
	if not is_building: return
	if selected_buildable and selected_buildable.layer == BuildableResource.BuildLayer.TOOL:
		current_remove_mode = (current_remove_mode + 1) % 3 as RemoveMode
		emit_signal("remove_mode_changed", current_remove_mode)
		return
		
	if selected_buildable and selected_buildable.layer != BuildableResource.BuildLayer.MECH:
		return 
	current_rotation_index = (current_rotation_index + 1) % 4
	_update_current_layout_cache()
	emit_signal("build_rotation_changed", current_rotation_index)

func _update_current_layout_cache() -> void:
	_current_build_layout =[Vector2i.ZERO]
	if not selected_buildable or not selected_buildable.scene: return
	
	var temp = selected_buildable.scene.instantiate()
	if temp.has_method("get_occupied_cells"):
		_current_build_layout = temp.get_occupied_cells(current_rotation_index)
	else:
		var w = selected_buildable.width
		var h = selected_buildable.height
		if current_rotation_index == 1 or current_rotation_index == 3:
			var swap = w; w = h; h = swap
		_current_build_layout.clear()
		for x in range(w):
			for y in range(h):
				_current_build_layout.append(Vector2i(x, y))
	temp.queue_free()

func get_current_layout() -> Array[Vector2i]:
	return _current_build_layout

func get_grid_cell(world_pos: Vector3) -> Vector3i:
	if not grid_map: return Vector3i.ZERO
	return grid_map.local_to_map(grid_map.to_local(world_pos))

func get_snapped_position(world_pos: Vector3) -> Vector3:
	if not grid_map: return world_pos
	var cell = get_grid_cell(world_pos)
	return grid_map.to_global(grid_map.map_to_local(cell))

func _get_logic_coord(world_pos: Vector3) -> Vector2i:
	var cell = get_grid_cell(world_pos)
	return Vector2i(cell.x, cell.z)

func can_build_at(world_pos: Vector3) -> bool:
	if not selected_buildable: return false
	
	var origin_logic = _get_logic_coord(world_pos)
	if lane_manager.fog_manager and origin_logic.x >= lane_manager.fog_manager.current_fog_depth:
		return false
	
	# 1. Check Resources
	if selected_buildable.layer != BuildableResource.BuildLayer.TOOL:
		if not PlayerManager.has_resources_to_build(selected_buildable):
			return false

	if not grid_map: return false
	
	if not lane_manager.is_valid_tile(origin_logic): return false
	
	if selected_buildable.layer == BuildableResource.BuildLayer.MECH:
		var dynamic_layout = _get_dynamic_layout(origin_logic)
		for tile_offset in dynamic_layout:
			var t = origin_logic + tile_offset
			if not lane_manager.is_valid_tile(t): return false
			if lane_manager.get_entity_at(t, "building") != null: return false
		return true

	if selected_buildable.layer == BuildableResource.BuildLayer.WIRING:
		if not lane_manager.is_valid_tile(origin_logic): return false
		return lane_manager.get_entity_at(origin_logic, "wire") == null

	if selected_buildable.layer == BuildableResource.BuildLayer.TOOL:
		return has_removable_at(world_pos)
		
	return false

func has_removable_at(world_pos: Vector3) -> bool:
	var logic_coord = _get_logic_coord(world_pos)
	if current_remove_mode == RemoveMode.ALL or current_remove_mode == RemoveMode.BUILDING_ONLY:
		if lane_manager.get_entity_at(logic_coord, "building") != null: return true
	if current_remove_mode == RemoveMode.ALL or current_remove_mode == RemoveMode.WIRE_ONLY:
		if lane_manager.get_entity_at(logic_coord, "wire") != null: return true
	return false

func place_buildable(world_pos: Vector3):
	if not is_building or not selected_buildable or not can_build_at(world_pos): return
	
	var snapped_pos = get_snapped_position(world_pos)
	var logic_coord = _get_logic_coord(world_pos)

	match selected_buildable.layer:
		BuildableResource.BuildLayer.MECH:
			_place_mech(snapped_pos, logic_coord)
			PlayerManager.consume_build_resource(selected_buildable)
				
		BuildableResource.BuildLayer.WIRING:
			_place_wiring(snapped_pos, logic_coord)
			PlayerManager.consume_build_resource(selected_buildable)
			
		BuildableResource.BuildLayer.TOOL:
			remove_buildable_at(world_pos)
			
	# If we ran out of items after placement, exit build mode
	if selected_buildable and selected_buildable.layer != BuildableResource.BuildLayer.TOOL:
		if not PlayerManager.has_resources_to_build(selected_buildable):
			exit_build_mode()

func remove_buildable_at(world_pos: Vector3):
	var logic_coord = _get_logic_coord(world_pos)
	if current_remove_mode == RemoveMode.ALL or current_remove_mode == RemoveMode.BUILDING_ONLY:
		_remove_at_tile(logic_coord, "building")
	if current_remove_mode == RemoveMode.ALL or current_remove_mode == RemoveMode.WIRE_ONLY:
		_remove_at_tile(logic_coord, "wire")

func _remove_at_tile(coord: Vector2i, layer_filter: String = ""):
	if layer_filter == "" or layer_filter == "building":
		var building = lane_manager.get_entity_at(coord, "building")
		if building and is_instance_valid(building):
			# Recover resource? (Optional: Add back to inventory)
			building.queue_free()
	
	if layer_filter == "" or layer_filter == "wire":
		var wire = lane_manager.get_entity_at(coord, "wire")
		if wire and is_instance_valid(wire):
			wire.queue_free()

func _place_mech(_visual_pos: Vector3, logic_coord: Vector2i):
	var instance = selected_buildable.scene.instantiate()
	
	if selected_buildable.buildable_name != "":
		instance.name = selected_buildable.buildable_name
		if "display_name" in instance:
			instance.display_name = selected_buildable.buildable_name
	
	if "visual_offset" in instance:
		var vo = selected_buildable.display_offset
		instance.visual_offset = Vector3(vo.x, vo.y, 0)
	
	get_tree().current_scene.get_node("Buildings").add_child(instance, true)
	
	var world_base = LaneManager.tile_to_world(logic_coord)
	instance.global_position = world_base + LaneManager.get_layer_offset("building")
	
	if instance.has_method("set_build_rotation"):
		instance.set_build_rotation(current_rotation_index)
	else:
		var rads = 0.0
		match current_rotation_index:
			0: rads = PI
			1: rads = PI * 0.5
			2: rads = 0.0
			3: rads = -PI * 0.5
		instance.rotation = Vector3(0, rads, 0)
	
	var dynamic_layout = _get_dynamic_layout(logic_coord)
	for tile_offset in dynamic_layout:
		var t = logic_coord + tile_offset
		if t != logic_coord: 
			LaneManager.register_entity(instance, t, "building")
	
	LaneManager.register_entity(instance, logic_coord, "building")

func _place_wiring(_visual_pos: Vector3, logic_coord: Vector2i):
	var instance = selected_buildable.scene.instantiate()
	if "visual_offset" in instance:
		var vo = selected_buildable.display_offset
		instance.visual_offset = Vector3(vo.x, vo.y, 0)
	
	get_tree().current_scene.get_node("Wiring").add_child(instance)
	
	var world_base = LaneManager.tile_to_world(logic_coord)
	instance.global_position = world_base + LaneManager.get_layer_offset("wire")
	
	wiring_manager.add_wire(logic_coord, instance)
	instance.tree_exiting.connect(wiring_manager.remove_wire.bind(logic_coord))

func register_preplaced_building(node: Node3D):
	if not grid_map: return
	var logic_coord = _get_logic_coord(node.global_position)
	LaneManager.register_entity(node, logic_coord, "building")

func get_mech_at(coord: Vector2i) -> Node:
	return lane_manager.get_entity_at(coord, "building")

func _get_dynamic_layout(_origin: Vector2i) -> Array[Vector2i]:
	return _current_build_layout
