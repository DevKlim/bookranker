@tool
extends BaseBuilding

const CAPACITY = 4
const ITEM_SPACING = 1.0 / float(CAPACITY)
const TRANSPORT_SPEED = 2.0 # Tiles per second

## Visual settings for items on the belt
@export var item_scale: Vector2 = Vector2(0.5, 0.5)
@export var item_visual_offset: Vector2 = Vector2.ZERO

# Array of Dictionary: { "item": ItemResource, "progress": float, "sprite": Sprite2D, "input_offset": Vector2 }
# Index 0 is the item closest to the output (Head).
var items: Array = []

func _ready() -> void:
	if Engine.is_editor_hint(): return
	
	super._ready()
	# Conveyors are always active and free
	power_consumer.power_consumption = 0.0
	power_consumer.requires_wire_connection = false
	is_active = true
	_update_visuals_active()

func _on_power_status_changed(_has_power: bool) -> void:
	# Override base behavior: Conveyors are always active
	is_active = true
	_update_visuals_active()

func _update_visuals_active() -> void:
	var animated_sprite = _get_main_sprite()
	if is_instance_valid(animated_sprite):
		animated_sprite.modulate = powered_color

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not is_active: return
	
	# The effective visual center of the conveyor (Building center + visual shift + manual adjustment)
	var visual_center = visual_offset + item_visual_offset
	
	# Calculate Output Vector relative to center (Center -> Output Edge)
	# This ensures the item travels towards the center of the target tile
	var out_vec = _get_offset_for_dir(output_direction) + visual_center
	
	# Iterate through items to move them
	for i in range(items.size()):
		var entry = items[i]
		
		# Determine movement limit for this item
		var limit = 1.0
		if i > 0:
			limit = items[i-1].progress - ITEM_SPACING
			
		# Move towards limit
		if entry.progress < limit:
			entry.progress += TRANSPORT_SPEED * delta
			if entry.progress > limit:
				entry.progress = limit
		
		# Update sprite visual position
		if is_instance_valid(entry.sprite):
			var current_pos = Vector2.ZERO
			
			# Input start point is relative to self
			var in_pos = entry.input_offset
			
			if entry.progress <= 0.5:
				# First half: Interpolate from Input Edge -> Visual Center
				# Map progress 0.0-0.5 to t 0.0-1.0
				var t = entry.progress * 2.0
				current_pos = in_pos.lerp(visual_center, t)
			else:
				# Second half: Interpolate from Visual Center -> Output Edge
				# Map progress 0.5-1.0 to t 0.0-1.0
				var t = (entry.progress - 0.5) * 2.0
				current_pos = visual_center.lerp(out_vec, t)
				
			entry.sprite.position = current_pos
	
	# Try to pass the head item to the next building
	if not items.is_empty():
		var head = items[0]
		if head.progress >= 1.0:
			_try_pass_item(head)

func _try_pass_item(entry):
	var neighbor = get_neighbor(output_direction)
	if neighbor and neighbor.has_method("receive_item"):
		# Pass 'self' as source so the neighbor knows where it's coming from
		if neighbor.receive_item(entry.item, self):
			if is_instance_valid(entry.sprite):
				entry.sprite.queue_free()
			items.remove_at(0)

func receive_item(item: ItemResource, from_node: Node2D = null) -> bool:
	if not is_active: return false
	
	if items.size() >= CAPACITY:
		return false
	
	if not items.is_empty():
		var last = items.back()
		if last.progress < ITEM_SPACING:
			return false
			
	var sprite = Sprite2D.new()
	sprite.texture = item.icon
	sprite.modulate = item.color
	sprite.scale = item_scale
	sprite.z_index = 1 # Ensure item renders above conveyor
	
	# Determine Input Offset (Where on the edge the item appears)
	# The visual center of THIS conveyor
	var my_visual_center = visual_offset + item_visual_offset
	
	var input_offset = Vector2.ZERO
	
	if from_node:
		# If neighbor has a visual offset, we should probably account for it to make the transition smooth.
		# Ideally, we calculate the vector from Neighbor Visual Center -> My Visual Center.
		# Cut that in half to find the "handoff" point in local space.
		
		var neighbor_visual_pos = from_node.global_position
		if "visual_offset" in from_node:
			neighbor_visual_pos += from_node.visual_offset
		if "item_visual_offset" in from_node:
			neighbor_visual_pos += from_node.item_visual_offset
			
		var my_visual_pos = global_position + my_visual_center
		
		# The vector from ME to NEIGHBOR
		var vec_to_neighbor = neighbor_visual_pos - my_visual_pos
		
		# The edge is roughly halfway
		input_offset = my_visual_center + (vec_to_neighbor * 0.5)
	else:
		# Fallback: Opposite of output direction + visual center
		input_offset = my_visual_center - _get_offset_for_dir(output_direction)

	# Initial position is at the input edge
	sprite.position = input_offset
	
	add_child(sprite)
	
	items.append({
		"item": item,
		"progress": 0.0,
		"sprite": sprite,
		"input_offset": input_offset
	})
	
	return true

func _get_offset_for_dir(dir: Direction) -> Vector2:
	# Calculates the vector from Center to the Edge in the given direction.
	# Tries logical grid first, then physical fallback.
	
	var current_pos = global_position + center_offset
	var current_tile = LaneManager.tile_map.local_to_map(current_pos)
	var log_current = LaneManager.get_logical_from_tile(current_tile)
	
	var target_tile = Vector2i(-1, -1)
	
	# 1. Try Logical
	if log_current != Vector2i(-1, -1):
		var log_target = log_current
		match dir:
			Direction.DOWN: log_target += Vector2i(0, -1)
			Direction.UP:   log_target += Vector2i(0, 1)
			Direction.LEFT: log_target += Vector2i(1, 0)
			Direction.RIGHT:log_target += Vector2i(-1, 0)
		target_tile = LaneManager.get_tile_from_logical(log_target.x, log_target.y)
	
	# 2. Fallback to Physical if logical failed
	if target_tile == Vector2i(-1, -1):
		var offset = Vector2i.ZERO
		match dir:
			Direction.DOWN: offset = Vector2i(0, 1)
			Direction.UP: offset = Vector2i(0, -1)
			Direction.LEFT: offset = Vector2i(-1, 0)
			Direction.RIGHT: offset = Vector2i(1, 0)
		target_tile = current_tile + offset
		
	# 3. Calculate Vector using map_to_local (guarantees correct visual geometry)
	var target_pos = LaneManager.tile_map.map_to_local(target_tile)
	
	# The full vector is Center -> Neighbor Center. 
	# The edge is halfway there.
	var full_vec = target_pos - current_pos
	return full_vec * 0.5

func _exit_tree() -> void:
	for entry in items:
		if is_instance_valid(entry.sprite):
			entry.sprite.queue_free()
	items.clear()
