extends BaseBuilding

var held_item: ItemResource = null
var item_sprite: Sprite2D
var transport_progress: float = 0.0
var transport_speed: float = 2.0 # Tiles per second

func _ready() -> void:
	super._ready()
	item_sprite = Sprite2D.new()
	item_sprite.scale = Vector2(0.5, 0.5)
	item_sprite.z_index = 1
	item_sprite.visible = false
	add_child(item_sprite)

func _process(delta: float) -> void:
	if is_active and held_item:
		transport_progress += delta * transport_speed
		
		# Update visual position
		# Start (0,0) is center. We want to move from center to edge based on output direction.
		# Actually, conveyors usually move from input edge to output edge.
		# For simplicity, let's move from Center to Edge in output direction.
		
		var offset_dir = Vector2.ZERO
		match output_direction:
			Direction.DOWN: offset_dir = Vector2(0, 16) # Approx for iso
			Direction.UP: offset_dir = Vector2(0, -16)
			Direction.LEFT: offset_dir = Vector2(-16, -8)
			Direction.RIGHT: offset_dir = Vector2(16, 8)
			
		# Animate from Center (0) to Edge (1.0)
		var t = clamp(transport_progress, 0.0, 1.0)
		item_sprite.position = offset_dir * t
		
		if transport_progress >= 1.0:
			_try_pass_item()

func _try_pass_item():
	var neighbor = get_neighbor(output_direction)
	if neighbor and neighbor.has_method("receive_item"):
		if neighbor.receive_item(held_item):
			held_item = null
			item_sprite.visible = false
			transport_progress = 0.0

func receive_item(item: ItemResource) -> bool:
	if held_item == null:
		held_item = item
		transport_progress = 0.0
		item_sprite.texture = item.icon
		item_sprite.modulate = item.color
		item_sprite.visible = true
		item_sprite.position = Vector2.ZERO # Reset to center
		return true
	return false
