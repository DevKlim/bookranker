class_name SlipslideBuilding
extends BaseBuilding

const TRANSPORT_SPEED = 2.0 

var stored_item = null
var progress = 0.0
var visual_node: Node3D = null

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not is_active: return
	
	if stored_item:
		progress += TRANSPORT_SPEED * delta
		if progress >= 1.0:
			progress = 1.0
			_try_pass_item()
		_update_visual()
	else:
		if inventory_component and inventory_component.has_item():
			var it = inventory_component.get_first_item()
			inventory_component.remove_item(it, 1)
			stored_item = it
			progress = 0.0
			_create_visual()

func _update_visual():
	if is_instance_valid(visual_node):
		var start_local = Vector3(0, 0, 0.5) + visual_offset
		var end_local = Vector3(0, 0, -0.5) + visual_offset
		visual_node.position = start_local.lerp(end_local, progress)

func _create_visual():
	if is_instance_valid(visual_node):
		visual_node.queue_free()
	visual_node = Node3D.new()
	var sprite = Sprite3D.new()
	sprite.texture = stored_item.icon
	if "color" in stored_item:
		sprite.modulate = stored_item.color
		
	# Downsize buildings to prevent cropping
	if stored_item is BuildableResource:
		sprite.pixel_size = 0.00375
	else:
		sprite.pixel_size = 0.03
		
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	visual_node.add_child(sprite)
	add_child(visual_node)
	_update_visual()

func _try_pass_item():
	var neighbor = get_neighbor(output_direction)
	var valid_stream = false
	if is_instance_valid(neighbor) and (neighbor.display_name == "Slipstream" or neighbor.display_name == "Tarstream"):
		valid_stream = true
		
	if valid_stream and neighbor.has_method("receive_item"):
		if neighbor.receive_item(stored_item, self):
			if is_instance_valid(visual_node): visual_node.queue_free()
			stored_item = null