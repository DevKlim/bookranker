@tool
class_name Conveyor
extends BaseBuilding

const LANE_COUNT = 2
const CAPACITY_PER_LANE = 4
const ITEM_SPACING = 1.0 / float(CAPACITY_PER_LANE)
const TRANSPORT_SPEED = 1.0 

@export var item_scale: Vector3 = Vector3(0.5, 1, 0.5)
@export var item_visual_offset: Vector3 = Vector3(0.0, 0.625, 0.0) 

# Lanes: Array of Arrays. Index 0 = Left, Index 1 = Right
# Entry: { "item": Resource, "progress": float, "visual": Node3D }
var lanes: Array = [[], []]

# Dynamic Input Direction derived from neighbors
var active_input_direction: Direction = Direction.UP 

const OUTLINE_SHADER_CODE = """
shader_type spatial;
render_mode unshaded, depth_draw_opaque, cull_disabled, blend_mix;
uniform sampler2D texture_albedo : source_color, filter_nearest;
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float width : hint_range(0.0, 10.0) = 1.0;

void fragment() {
	vec4 col = texture(texture_albedo, UV);
	vec2 size = vec2(textureSize(texture_albedo, 0));
	float px_x = width / size.x;
	float px_y = width / size.y;
	float a = texture(texture_albedo, UV + vec2(px_x, 0.0)).a;
	a += texture(texture_albedo, UV + vec2(-px_x, 0.0)).a;
	a += texture(texture_albedo, UV + vec2(0.0, px_y)).a;
	a += texture(texture_albedo, UV + vec2(0.0, -px_y)).a;
	
	if (col.a < 0.1 && a > 0.1) {
		ALBEDO = outline_color.rgb;
		ALPHA = 1.0;
	} else {
		ALBEDO = col.rgb;
		ALPHA = col.a;
		if (col.a < 0.1) discard;
	}
}
"""

func _ready() -> void:
	if not Engine.is_editor_hint():
		super._ready()
		if has_meta("is_preview"): return
		
		if power_consumer:
			power_consumer.power_consumption = 0.0
			power_consumer.requires_wire_connection = false
		is_active = true
		
		active_input_direction = input_direction
		
		# Wait for grid registration to complete
		await get_tree().process_frame
		_update_adjacency()
		_notify_neighbors()
	
	call_deferred("_setup_scrolling_shader")
	call_deferred("_update_visuals_active")

func update_preview_visuals() -> void:
	if not has_meta("is_preview"): return
	var tile = LaneManager.world_to_tile(global_position)
	_update_adjacency(tile)

func _notify_neighbors() -> void:
	for dir in [Direction.UP, Direction.DOWN, Direction.LEFT, Direction.RIGHT]:
		var n = get_neighbor(dir)
		if n and n is Conveyor:
			n._update_adjacency()

func _update_adjacency(force_tile: Vector2i = Vector2i(-1, -1)) -> void:
	var candidates = []
	var is_preview_check = (force_tile != Vector2i(-1, -1))
	var my_tile = force_tile if is_preview_check else LaneManager.world_to_tile(global_position)
	
	for d in [Direction.UP, Direction.DOWN, Direction.LEFT, Direction.RIGHT]:
		var n = null
		if is_preview_check:
			var offset = Vector2i.ZERO
			match d:
				Direction.DOWN: offset = Vector2i(0, 1)
				Direction.UP:   offset = Vector2i(0, -1)
				Direction.LEFT: offset = Vector2i(-1, 0)
				Direction.RIGHT:offset = Vector2i(1, 0)
			n = LaneManager.get_buildable_at(my_tile + offset)
		else:
			n = get_neighbor(d)
			
		if n and n.has_method("get_neighbor"):
			if "output_direction" in n:
				# Reverse check: where does the neighbor point?
				var n_dir = n.output_direction
				var n_target_offset = Vector2i.ZERO
				match n_dir:
					Direction.DOWN: n_target_offset = Vector2i(0, 1)
					Direction.UP:   n_target_offset = Vector2i(0, -1)
					Direction.LEFT: n_target_offset = Vector2i(-1, 0)
					Direction.RIGHT:n_target_offset = Vector2i(1, 0)
				
				var n_tile = LaneManager.world_to_tile(n.global_position)
				var n_target_tile = n_tile + n_target_offset
				
				if n_target_tile == my_tile:
					candidates.append(d)

	if candidates.is_empty():
		active_input_direction = input_direction
	else:
		if input_direction in candidates:
			active_input_direction = input_direction
		else:
			active_input_direction = candidates[0]
			
	_setup_scrolling_shader()

func _get_dir_angle(dir: int) -> float:
	match dir:
		Direction.DOWN: return PI
		Direction.LEFT: return PI * 0.5
		Direction.UP: return 0.0
		Direction.RIGHT: return -PI * 0.5
	return 0.0

func _setup_scrolling_shader() -> void:
	var mesh_inst = get_node_or_null("BlockVisual")
	if not is_instance_valid(mesh_inst) or not (mesh_inst is MeshInstance3D): return
	if not mesh_inst.mesh: return

	var scroll_tex = load("res://assets/buildables/conveyor_scroll.png")
	var diag_tex = load("res://assets/buildables/conveyor_diag_top.png")
	var straight_tex = load("res://assets/buildables/conveyor_top.png")
	var side_tex = load("res://assets/buildables/conveyor_side.png")
	var front_tex = load("res://assets/buildables/conveyor_front.png")
	var back_tex = load("res://assets/buildables/conveyor_back.png")
	
	if not scroll_tex: return
	
	var is_turn = false
	var turn_rotation = 0.0
	var texture_to_use = straight_tex
	
	# Default flip is none (1, 1)
	var uv_flip = Vector2(1.0, 1.0)
	
	# Fix 1: Apply -90 degree base offset to correct "Left" vs "Up" visual
	var base_rotation = deg_to_rad(0)

	if active_input_direction != output_direction:
		# Check if it's strictly opposite (Straight) or angled (Turn)
		# Godot Dirs: 0=Down, 1=Left, 2=Up, 3=Right
		# Straight combinations (Out/In): 0/2, 2/0, 1/3, 3/1
		var is_straight = false
		if (output_direction == Direction.DOWN and active_input_direction == Direction.UP) or \
		   (output_direction == Direction.UP and active_input_direction == Direction.DOWN) or \
		   (output_direction == Direction.LEFT and active_input_direction == Direction.RIGHT) or \
		   (output_direction == Direction.RIGHT and active_input_direction == Direction.LEFT):
			is_straight = true
			
		if not is_straight:
			is_turn = true
			var in_angle = _get_dir_angle(active_input_direction)
			var out_angle = _get_dir_angle(output_direction)
			var diff = angle_difference(out_angle, in_angle)
			
			if diag_tex:
				texture_to_use = diag_tex
				if diff > 0.1: # Left Turn
					uv_flip = Vector2(1.0, 1.0)
					turn_rotation = deg_to_rad(0)
				else: # Right Turn
					uv_flip = Vector2(-1.0, 1.0)
					turn_rotation = deg_to_rad(0)
	
	var surface_count = mesh_inst.mesh.get_surface_count()
	
	# Logic to Open Sides based on Local Space
	# Surface Indices from DataImporter: 2=Front, 3=Back, 4=Left, 5=Right
	# BaseBuilding rotates the node so Output is always Local Front (Surface 2)
	
	var local_output_face = 2 # Front (-Z)
	var local_input_face = -1
	
	# Determine Local Input Face relative to Output
	# We compare logical directions to find the relative offset
	# Dirs: 3=Down, 0=Left, 1=Up, 2=Right
	
	# Calculate relative 'slots' clockwise. 
	# 0 (Left) -> 1 (Up) -> 2 (Right) -> 3 (Down)
	var out_a = _get_dir_angle(output_direction)
	var in_a = _get_dir_angle(active_input_direction)
	var angle_diff = angle_difference(out_a, in_a) # Range -PI to PI
	
	# Map angle difference to Local Face
	# 0 (Same) -> Impossible for valid flow
	# PI (Opposite) -> Back (Surface 3)
	# +PI/2 (Left relative to Out)
	# -PI/2 (Right relative to Out)
	
	if abs(angle_diff) > 3.0: # Approx PI
		local_input_face = 3 # Back
	elif angle_diff > 0.1: # Positive diff ~ Left
		local_input_face = 4 # Left
	elif angle_diff < -0.1: # Negative diff ~ Right
		local_input_face = 5 # Right

	# Iterate relevant surfaces
	for i in [0, 2, 3, 4, 5]: 
		if i >= surface_count: continue
		
		var active_mat = mesh_inst.get_surface_override_material(i)
		if not active_mat: active_mat = mesh_inst.mesh.surface_get_material(i)
		if not active_mat: continue

		var face_texture = null
		var use_shader = false
		var specific_flip = Vector2(1,1)
		var specific_rot = 0.0
		var specific_speed = 1.0

		if i == 0: # Top Face
			face_texture = texture_to_use
			use_shader = true
			specific_flip = uv_flip
			# Combine base rotation (fix orientation) + turn rotation
			specific_rot = base_rotation + turn_rotation
			specific_speed = 1.0
		else:
			# Side Faces Logic
			var is_open = (i == local_output_face or i == local_input_face)
			
			if is_open:
				face_texture = straight_tex
				use_shader = true
				if i == local_output_face:
					specific_speed = 1.0 
				else:
					specific_speed = -1.0
			else:
				# Closed Wall
				use_shader = false
				match i:
					2: face_texture = front_tex
					3: face_texture = back_tex
					_: face_texture = side_tex

		var final_mat = null
		
		if use_shader:
			if active_mat is ShaderMaterial:
				final_mat = active_mat
			else:
				final_mat = ShaderMaterial.new()
				final_mat.shader = _get_conveyor_shader()
				if active_mat.has_meta("is_ghost") and active_mat is StandardMaterial3D:
					final_mat.set_meta("is_ghost", true)
					final_mat.set_shader_parameter("tint_color", active_mat.albedo_color)
			
			final_mat.set_shader_parameter("base_texture", face_texture)
			final_mat.set_shader_parameter("scroll_texture", scroll_tex)
			final_mat.set_shader_parameter("speed", specific_speed)
			final_mat.set_shader_parameter("uv_scale_y", 1.0)
			final_mat.set_shader_parameter("uv_rotation", specific_rot)
			final_mat.set_shader_parameter("uv_flip", specific_flip)
		else:
			# Revert to standard material
			if active_mat is ShaderMaterial:
				final_mat = StandardMaterial3D.new()
				final_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				if active_mat.has_meta("is_ghost"):
					final_mat.set_meta("is_ghost", true)
					final_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					final_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
					var tint = active_mat.get_shader_parameter("tint_color")
					if tint: final_mat.albedo_color = tint
			else:
				final_mat = active_mat
				
			final_mat.albedo_texture = face_texture

		mesh_inst.set_surface_override_material(i, final_mat)

func _get_conveyor_shader() -> Shader:
	var s = Shader.new()
	s.code = """
	shader_type spatial;
	render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
	
	uniform sampler2D base_texture : source_color, filter_nearest, repeat_disable;
	uniform sampler2D scroll_texture : source_color, filter_nearest, repeat_enable;
	uniform float speed = 1.0;
	uniform float uv_scale_y = 1.0;
	uniform float uv_rotation = 0.0;
	uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
	uniform vec2 uv_flip = vec2(1.0, 1.0);
	
	vec2 rotateUV(vec2 uv, float rotation) {
		float mid = 0.5;
		return vec2(
			cos(rotation) * (uv.x - mid) + sin(rotation) * (uv.y - mid) + mid,
			cos(rotation) * (uv.y - mid) - sin(rotation) * (uv.x - mid) + mid
		);
	}
	
	void fragment() {
		// Apply flip first, then rotation
		vec2 flipped_uv = (UV - 0.5) * uv_flip + 0.5;
		vec2 base_uv = rotateUV(flipped_uv, uv_rotation);
		vec4 base = texture(base_texture, base_uv);
		
		// Scroll logic (apply flip to geometry so mask aligns)
		vec2 scroll_uv_raw = vec2(flipped_uv.x, mod((flipped_uv.y * uv_scale_y * 0.5) + (TIME * speed), 0.5));
		vec2 scroll_uv = rotateUV(scroll_uv_raw, uv_rotation);
		vec4 scroll = texture(scroll_texture, scroll_uv);
		
		vec3 final_col = base.rgb;
		// Simple Mask Check
		if (base.r < 0.05 && base.g < 0.05 && base.b < 0.05 && base.a > 0.9) { 
			final_col = scroll.rgb; 
		}
		
		ALBEDO = final_col * tint_color.rgb;
		ALPHA = base.a * tint_color.a;
	}
	"""
	return s

func _on_power_status_changed(_has_power: bool) -> void:
	is_active = true
	_update_visuals_active()

func _update_visuals_active() -> void:
	var mesh_inst = get_node_or_null("BlockVisual")
	if is_instance_valid(mesh_inst) and mesh_inst is MeshInstance3D:
		var spd = 1.0 if is_active else 0.0
		for i in range(mesh_inst.get_surface_override_material_count()):
			var mat = mesh_inst.get_surface_override_material(i)
			if mat and mat is ShaderMaterial:
				# Use parameter stored speed sign if possible, but shader param is just 'speed'.
				# We need to preserve direction.
				# A cheat: read current speed, normalize it, apply boolean state
				var current = mat.get_shader_parameter("speed")
				var sign_val = 1.0
				if current < 0: sign_val = -1.0
				mat.set_shader_parameter("speed", spd * sign_val)

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or not is_active: return
	
	var visual_center = visual_offset + item_visual_offset
	
	# Process both lanes independently
	for lane_idx in range(LANE_COUNT):
		var lane_items = lanes[lane_idx]
		var lane_offset_x = -0.2 if lane_idx == 0 else 0.2
		
		var lane_start_local = Vector3(lane_offset_x, 0, 0.5) + visual_center
		var lane_end_local = Vector3(lane_offset_x, 0, -0.5) + visual_center
		
		for i in range(lane_items.size()):
			var entry = lane_items[i]
			var limit = 1.0
			if i > 0:
				limit = lane_items[i-1].progress - ITEM_SPACING
			
			if entry.progress < limit:
				entry.progress += TRANSPORT_SPEED * delta
				if entry.progress > limit: entry.progress = limit
			
			if is_instance_valid(entry.visual):
				entry.visual.position = lane_start_local.lerp(lane_end_local, entry.progress)
		
		if not lane_items.is_empty():
			var head = lane_items[0]
			if head.progress >= 1.0:
				_try_pass_item(head, lane_idx)

func _try_pass_item(entry, lane_idx: int):
	var neighbor = get_neighbor(output_direction)
	if is_instance_valid(neighbor) and neighbor.has_method("receive_item"):
		if neighbor.receive_item(entry.item, self, { "lane": lane_idx }):
			if is_instance_valid(entry.visual): entry.visual.queue_free()
			lanes[lane_idx].remove_at(0)

func receive_item(item: Resource, from_node: Node3D = null, extra_data: Dictionary = {}) -> bool:
	if not item is ItemResource: return false
	if not is_active: return false
	
	var target_lane = 0
	var initial_progress = 0.0
	
	if from_node:
		var input_world_pos = Vector3.ZERO
		if extra_data.has("lane") and from_node is Node3D:
			var src_lane = extra_data["lane"]
			var src_x = -0.2 if src_lane == 0 else 0.2
			var src_local = Vector3(src_x, 0, -0.5)
			input_world_pos = from_node.to_global(src_local)
		else:
			var dir = (global_position - from_node.global_position).normalized()
			input_world_pos = from_node.global_position + (dir * 0.5)
			
		var local_pos = to_local(input_world_pos)
		target_lane = 0 if local_pos.x <= 0.0 else 1
		initial_progress = clamp(0.5 - local_pos.z, 0.0, 1.0)
	
	if not _can_fit_item(target_lane, initial_progress):
		return false

	var target_array = lanes[target_lane]
	var insert_idx = target_array.size()
	for i in range(target_array.size()):
		if target_array[i].progress < initial_progress:
			insert_idx = i
			break
			
	var container = Node3D.new()
	var sprite = Sprite3D.new()
	sprite.texture = item.icon
	sprite.modulate = item.color
	sprite.scale = item_scale
	sprite.axis = Vector3.AXIS_Y
	sprite.pixel_size = 0.03
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	
	var shader = Shader.new()
	shader.code = OUTLINE_SHADER_CODE
	var mat = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("texture_albedo", item.icon)
	mat.render_priority = 2
	sprite.material_override = mat
	
	container.add_child(sprite)
	add_child(container)
	
	var lane_offset_x = -0.2 if target_lane == 0 else 0.2
	var visual_center = visual_offset + item_visual_offset
	var lane_start_local = Vector3(lane_offset_x, 0, 0.5) + visual_center
	var lane_end_local = Vector3(lane_offset_x, 0, -0.5) + visual_center
	container.position = lane_start_local.lerp(lane_end_local, initial_progress)
	
	target_array.insert(insert_idx, { 
		"item": item, 
		"progress": initial_progress, 
		"visual": container 
	})
	
	return true

func _can_fit_item(lane_idx: int, p_progress: float) -> bool:
	if lane_idx < 0 or lane_idx >= LANE_COUNT: return false
	var arr = lanes[lane_idx]
	if arr.size() >= CAPACITY_PER_LANE: return false
	
	var idx = arr.size()
	for i in range(arr.size()):
		if arr[i].progress < p_progress:
			idx = i
			break
			
	if idx > 0:
		if (arr[idx - 1].progress - p_progress) < ITEM_SPACING: return false
	if idx < arr.size():
		if (p_progress - arr[idx].progress) < ITEM_SPACING: return false
		
	return true

func _exit_tree() -> void:
	for l in lanes:
		for entry in l:
			if is_instance_valid(entry.visual): entry.visual.queue_free()
	lanes = [[], []]
