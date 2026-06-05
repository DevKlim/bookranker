class_name InteractionComponent
extends Node

var interaction_target: Node = null
var interaction_type: String = ""
var interaction_data: Dictionary = {}
var is_interacting: bool = false
var interaction_progress: float = 0.0
var interaction_duration: float = 2.0 
var centering_target: Vector3 = Vector3.ZERO
var is_centering: bool = false

var body: CharacterBody3D
var move_component: MoveComponent
var inventory_component: InventoryComponent

func _ready() -> void:
	body = get_parent()
	call_deferred("_cache_components")

func _cache_components() -> void:
	move_component = body.get_node_or_null("MoveComponent")
	inventory_component = body.get_node_or_null("InventoryComponent")

func set_interaction(target: Node, type: String, data: Dictionary = {}) -> void:
	interaction_target = target
	interaction_type = type
	interaction_data = data
	is_interacting = false
	if target is Node3D:
		var best_pos = _find_adjacent_center(target.global_position)
		centering_target = best_pos
		is_centering = true
		var dist = body.global_position.distance_to(best_pos)
		if dist > 0.1 and move_component:
			move_component.move_to(best_pos)
		else:
			body.global_position = best_pos
			_start_interaction()

func _find_adjacent_center(target_pos: Vector3) -> Vector3:
	var t_tile = LaneManager.world_to_tile(target_pos)
	var my_tile = LaneManager.world_to_tile(body.global_position)
	var candidates = []
	for n in[Vector2i(0,1), Vector2i(0,-1), Vector2i(1,0), Vector2i(-1,0)]:
		var check = t_tile + n
		if LaneManager.is_valid_tile(check):
			candidates.append(check)
	if candidates.is_empty(): return LaneManager.tile_to_world(t_tile)
	candidates.sort_custom(func(a, b):
		var pos_a = LaneManager.tile_to_world(a)
		var pos_b = LaneManager.tile_to_world(b)
		return body.global_position.distance_squared_to(pos_a) < body.global_position.distance_squared_to(pos_b)
	)
	return LaneManager.tile_to_world(candidates[0])

func process_centering() -> void:
	if not is_centering: return
	var dist = Vector3(body.global_position.x, 0, body.global_position.z).distance_to(Vector3(centering_target.x, 0, centering_target.z))
	if dist < 0.1:
		if move_component: move_component.stop_moving()
		body.global_position.x = centering_target.x
		body.global_position.z = centering_target.z
		is_centering = false
		_start_interaction()

func _start_interaction() -> void:
	if interaction_type == "pickup_clutter":
		is_interacting = true
		interaction_progress = 0.0
		interaction_duration = 2.0

func process_interaction(delta: float) -> void:
	if not is_interacting: return
	if not is_instance_valid(interaction_target):
		is_interacting = false
		return
	interaction_progress += delta
	if interaction_progress >= interaction_duration:
		_complete_interaction()

func _complete_interaction() -> void:
	is_interacting = false
	if interaction_type == "pickup_clutter":
		if not is_instance_valid(interaction_target): return
		if not interaction_target is ClutterObject: return
		var drop_item = null
		var count = 1
		if interaction_target.clutter_resource:
			drop_item = interaction_target.clutter_resource.drop_item
			count = interaction_target.clutter_resource.drop_count
		if drop_item and inventory_component:
			_equip_or_add_item(drop_item, count)
		interaction_target.queue_free()
		interaction_target = null

func _equip_or_add_item(item: Resource, count: int) -> void:
	if not item is ItemResource:
		inventory_component.add_item(item, count)
		return
	var target_slot = -1
	match item.equipment_type:
		ItemResource.EquipmentType.TOOL: target_slot = 0
		ItemResource.EquipmentType.WEAPON: target_slot = 1
		ItemResource.EquipmentType.ARMOR: target_slot = 2
		ItemResource.EquipmentType.ACCESSORY: target_slot = 3
	if target_slot != -1:
		var current = inventory_component.slots[target_slot]
		if current == null:
			inventory_component.slots[target_slot] = { "item": item, "count": 1 }
			count -= 1
			inventory_component.inventory_changed.emit()
	if count > 0:
		inventory_component.add_item(item, count)
