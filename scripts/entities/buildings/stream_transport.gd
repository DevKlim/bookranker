class_name StreamTransport
extends BaseBuilding

@export var scroll_direction: Vector2 = Vector2(-1.0, 0.0)
@export var scroll_scale: Vector2 = Vector2(2.0, 5.0)
@export var scroll_rotation: float = 90.0
@export var scroll_pivot: Vector2 = Vector2(0.0, 0.0)

const CAPACITY = 3
const ITEM_SPACING = 0.334

var items: Array =[] 
var stream_type: String = "water"
var scroll_component: ScrollingTextureComponent

func _ready() -> void:
	if Engine.is_editor_hint(): return
	
	if "tarstream" in scene_file_path.to_lower() or name.to_lower().begins_with("tarstream"):
		stream_type = "ink"
		display_name = "Tarstream"
		speed = 1.0
	else:
		stream_type = "water"
		display_name = "Slipstream"
		speed = 3.0
		
	super._ready()
	
	# Mark as stream to avoid enemy targeting/collision
	add_to_group("stream")
	
	# Move to a non-blocking physical layer so enemies walk through 
	# (Layer 5: value 16) - Player selection raycast includes this, but enemies only mask layer 1
	collision_layer = 16
	collision_mask = 0
	
	# Add Element Application Hitbox
	var area = Area3D.new()
	area.name = "ElementTrigger"
	area.collision_layer = 0
	area.collision_mask = 2 # Enemy layer
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(1, 1, 1)
	col.shape = box
	col.position = Vector3(0, 0.5, 0)
	area.add_child(col)
	add_child(area)
	area.body_entered.connect(_on_enemy_entered)
	
	if not inventory_component:
		inventory_component = InventoryComponent.new()
		inventory_component.name = "InventoryComponent"
		inventory_component.max_slots = 1
		inventory_component.slot_capacity = CAPACITY
		add_child(inventory_component)
		
	if power_consumer:
		power_consumer.power_consumption = 0.0
		power_consumer.requires_wire_connection = false
	is_active = true
	
	# Hook into dynamic stat changes to immediately update visual speed
	var stat_comp = get_node_or_null("StatComponent")
	if stat_comp and not stat_comp.stats_changed.is_connected(_update_visuals_active):
		stat_comp.stats_changed.connect(_update_visuals_active)
	
	call_deferred("_setup_scrolling_component")

func _on_enemy_entered(body: Node3D) -> void:
	if body.is_in_group("enemies") or body is Enemy:
		var elem_id = "aqua" if stream_type == "water" else "dark"
		if is_instance_valid(ElementManager):
			var elem = ElementManager.get_element(elem_id)
			if elem:
				ElementManager.apply_element(body, elem, self, 0.0, 1)

func _setup_scrolling_component() -> void:
	scroll_component = ScrollingTextureComponent.new()
	scroll_component.name = "ScrollingTextureComponent"
	
	var scroll_tex_path = "res://assets/buildables/slipstream/slipstream.png"
	if stream_type == "ink":
		scroll_tex_path = "res://assets/buildables/slipstream/tarstream.png"
	
	scroll_component.scroll_texture = load(scroll_tex_path)
	scroll_component.mask_mode = ScrollingTextureComponent.MaskMode.ALPHA_MATCH
	scroll_component.alpha_tolerance = 0.1
	scroll_component.scroll_speed = speed * 0.2
	scroll_component.scroll_direction = scroll_direction
	scroll_component.scroll_scale = scroll_scale
	scroll_component.scroll_rotation = scroll_rotation
	scroll_component.scroll_pivot = scroll_pivot
	scroll_component.apply_to_all_surfaces = true
	
	add_child(scroll_component)
	_update_visuals_active()

func _on_power_status_changed(_has_power: bool) -> void:
	is_active = true
	_update_visuals_active()

func _update_visuals_active() -> void:
	if scroll_component:
		scroll_component.set_active(is_active)
		var active_speed = get_stat("speed", speed)
		# Update the shader speed dynamically based on current modified stats
		scroll_component.set_speed_multiplier(active_speed / max(0.001, speed))

func _setup_health_component() -> void: pass 

func take_damage(_amount: float, _element: Resource = null, _source: Node = null) -> void: pass 

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	if not is_active: return
	
	var active_speed = get_stat("speed", speed)
	
	for i in range(items.size()):
		var entry = items[i]
		
		# Organic Backpressure: Ensures items slide up and wait perfectly without overlapping
		var limit = 1.0
		if i > 0: limit = items[i-1].progress - ITEM_SPACING
		
		if entry.progress < limit:
			entry.progress += active_speed * delta
			if entry.progress > limit: entry.progress = limit
			
		if is_instance_valid(entry.visual):
			var start_local = Vector3(0, 0, 0.5) + visual_offset
			var end_local = Vector3(0, 0, -0.5) + visual_offset
			entry.visual.position = start_local.lerp(end_local, entry.progress)
			
	if not items.is_empty():
		var head = items[0]
		if head.progress >= 1.0:
			_try_pass_item(head)

func _try_pass_item(entry):
	var tile = LaneManager.world_to_tile(global_position)
	var offset = Vector2i.ZERO
	match output_direction:
		Direction.DOWN: offset = Vector2i(0, 1)
		Direction.UP:   offset = Vector2i(0, -1)
		Direction.LEFT: offset = Vector2i(-1, 0)
		Direction.RIGHT:offset = Vector2i(1, 0)
	
	var target_tile = tile + offset
	var neighbor = LaneManager.get_entity_at(target_tile, "wire")
	
	if not is_instance_valid(neighbor) or neighbor.get("display_name") not in["Slipstream", "Tarstream"]:
		var b_neighbor = LaneManager.get_entity_at(target_tile, "building")
		if is_instance_valid(b_neighbor): neighbor = b_neighbor
			
	var handled = false
	
	if is_instance_valid(neighbor):
		if neighbor.has_method("receive_item") and neighbor.get("has_input") != false:
			if neighbor.receive_item(entry.item, self): 
				handled = true
	else:
		# Fall off edge
		handled = true 

	if handled:
		if is_instance_valid(entry.visual): entry.visual.queue_free()
		if inventory_component: inventory_component.remove_item(entry.item, 1)
		items.remove_at(0)

func receive_item(item: Resource, from_node: Node3D = null, extra_data: Dictionary = {}) -> bool:
	if not is_active: return false
	
	var is_valid_source = false
	var src_name = ""
	if from_node:
		src_name = from_node.get("display_name") if from_node.get("display_name") else ""
		if src_name in ["Slipstream", "Tarstream", "Slipslide"] or from_node is SlipslideBuilding or "slipslide" in from_node.name.to_lower():
			is_valid_source = true
			
	if from_node and not is_valid_source: return false
	if not (item is ItemResource or item is BuildableResource): return false
	
	var initial_progress = 0.0
	if from_node:
		if is_valid_source:
			initial_progress = 0.0
		else:
			var dir = (global_position - from_node.global_position).normalized()
			var input_world_pos = from_node.global_position + (dir * 0.5)
			var local_pos = to_local(input_world_pos)
			initial_progress = clamp(0.5 - local_pos.z, 0.0, 1.0)
	
	if not _can_fit_item(initial_progress): return false 
	
	var insert_idx = items.size()
	for i in range(items.size()):
		if items[i].progress < initial_progress:
			insert_idx = i
			break

	var container = Node3D.new()
	var sprite = Sprite3D.new()
	sprite.texture = item.icon
	if "color" in item: sprite.modulate = item.color
	if item is BuildableResource: sprite.pixel_size = 0.015
	else: sprite.pixel_size = 0.03
		
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	container.add_child(sprite)
	add_child(container)
	
	var start_local = Vector3(0, 0, 0.5) + visual_offset
	var end_local = Vector3(0, 0, -0.5) + visual_offset
	container.position = start_local.lerp(end_local, initial_progress)
	
	items.insert(insert_idx, { "item": item, "progress": initial_progress, "visual": container })
	if inventory_component: inventory_component.add_item(item, 1)
	return true

func _can_fit_item(p_progress: float) -> bool:
	if items.size() >= CAPACITY: return false
	
	var insert_idx = items.size()
	for i in range(items.size()):
		if items[i].progress < p_progress:
			insert_idx = i
			break
			
	# Tolerance allows the physics engine to resolve node-order framing delays smoothly
	var safe_spacing = ITEM_SPACING - 0.05
	
	if insert_idx > 0: 
		if (items[insert_idx - 1].progress - p_progress) < safe_spacing: return false
	if insert_idx < items.size(): 
		if (p_progress - items[insert_idx].progress) < safe_spacing: return false
		
	return true
