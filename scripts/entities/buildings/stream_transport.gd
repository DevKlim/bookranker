class_name StreamTransport
extends BaseBuilding

const TRANSPORT_SPEED_WATER = 5.0
const TRANSPORT_SPEED_INK = 1.0

var items: Array =[] # { "item": Resource, "progress": float, "visual": Node3D }

func _ready() -> void:
	if Engine.is_editor_hint(): return
	super._ready()
	
	# Guarantee an inventory component exists so the count is exposed and updated 
	# dynamically for other machines or UI reading its contents.
	if not inventory_component:
		inventory_component = InventoryComponent.new()
		inventory_component.name = "InventoryComponent"
		inventory_component.max_slots = 1
		inventory_component.slot_capacity = 3
		add_child(inventory_component)
		
	if power_consumer:
		power_consumer.power_consumption = 0.0
		power_consumer.requires_wire_connection = false
	is_active = true

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	super._physics_process(delta)
	if not is_active: return
	
	var speed = TRANSPORT_SPEED_WATER if display_name == "Slipstream" else TRANSPORT_SPEED_INK
	
	for entry in items:
		entry.progress += speed * delta
		if entry.progress > 1.0:
			entry.progress = 1.0
		
		if is_instance_valid(entry.visual):
			var start_local = Vector3(0, 0, 0.5) + visual_offset
			var end_local = Vector3(0, 0, -0.5) + visual_offset
			entry.visual.position = start_local.lerp(end_local, entry.progress)
			
	if not items.is_empty():
		var head = items[0]
		if head.progress >= 1.0:
			_try_pass_item(head)

func _try_pass_item(entry):
	var neighbor = get_neighbor(output_direction)
	var handled = false
	
	if is_instance_valid(neighbor):
		# If the neighbor is also a stream, check if it turns. "if the stream turns, item disappears"
		if neighbor.display_name == "Slipstream" or neighbor.display_name == "Tarstream":
			if neighbor.output_direction != self.output_direction:
				handled = true
			elif neighbor.has_method("receive_item") and neighbor.get("has_input") != false:
				if neighbor.receive_item(entry.item, self):
					handled = true
				else:
					handled = true # Can't receive -> Disappear
		else:
			if neighbor.has_method("receive_item") and neighbor.get("has_input") != false:
				if neighbor.receive_item(entry.item, self):
					handled = true
				else:
					handled = true # Disappear
			else:
				handled = true # Disappear
	else:
		handled = true # Output into nothing -> disappear

	if handled:
		if is_instance_valid(entry.visual): entry.visual.queue_free()
		# Deduct from internal tracked inventory count
		if inventory_component:
			inventory_component.remove_item(entry.item, 1)
		items.remove_at(0)

func receive_item(item: Resource, from_node: Node3D = null, extra_data: Dictionary = {}) -> bool:
	if not is_active: return false
	if not (item is ItemResource or item is BuildableResource): return false
	
	var initial_progress = 0.0
	if from_node:
		var dir = (global_position - from_node.global_position).normalized()
		var input_world_pos = from_node.global_position + (dir * 0.5)
		var local_pos = to_local(input_world_pos)
		initial_progress = clamp(0.5 - local_pos.z, 0.0, 1.0)
	
	if items.size() >= 3: return false # max capacity
	
	if not items.is_empty():
		var last = items.back()
		if last.progress - initial_progress < 0.3:
			return false # Too close

	var container = Node3D.new()
	var sprite = Sprite3D.new()
	sprite.texture = item.icon
	if "color" in item:
		sprite.modulate = item.color
		
	# Downsize buildings to prevent cropping
	if item is BuildableResource:
		sprite.pixel_size = 0.015
	else:
		sprite.pixel_size = 0.03
		
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	container.add_child(sprite)
	add_child(container)
	
	var start_local = Vector3(0, 0, 0.5) + visual_offset
	var end_local = Vector3(0, 0, -0.5) + visual_offset
	container.position = start_local.lerp(end_local, initial_progress)
	
	items.append({ "item": item, "progress": initial_progress, "visual": container })
	
	# Add to internal tracked inventory count
	if inventory_component:
		inventory_component.add_item(item, 1)
		
	return true
