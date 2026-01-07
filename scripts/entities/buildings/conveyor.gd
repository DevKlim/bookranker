@tool
class_name Conveyor
extends BaseBuilding

const LANE_COUNT = 2
const CAPACITY_PER_LANE = 4
const ITEM_SPACING = 1.0 / float(CAPACITY_PER_LANE)
const TRANSPORT_SPEED = 1.0 

@export var item_scale: Vector3 = Vector3(1, 1, 1)
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

func _notify_neighbors() -> void:
	# Tell surrounding conveyors to re-check their inputs
	for dir in [Direction.UP, Direction.DOWN, Direction.LEFT, Direction.RIGHT]:
		var n = get_neighbor(dir)
		if n and n is Conveyor:
			n._update_adjacency()

func _update_adjacency() -> void:
	var candidates = []
	
	# Check all 4 neighbors to see if they output into this conveyor
	for d in [Direction.UP, Direction.DOWN, Direction.LEFT, Direction.RIGHT]:
		var n = get_neighbor(d)
		if n and n.has_method("get_neighbor"):
			if "output_direction" in n:
				var n_target = n.get_neighbor(n.output_direction)
				if n_target == self:
					candidates.append(d)

	if candidates.is_empty():
		active_input_direction = input_direction
	else:
		# Priority: Straight > Left > Right (Relative to output)
		# For now, if the static input dir is in candidates, use it (Straight)
		if input_direction in candidates:
			active_input_direction = input_direction
		else:
			# Otherwise pick the first available input
			active_input_direction = candidates[0]
			
	_setup_scrolling_shader()

func _setup_scrolling_shader() -> void:
	var mesh_inst = get_node_or_null("BlockVisual")
	if not is_instance_valid(mesh_inst) or not (mesh_inst is MeshInstance3D): return
	if not mesh_inst.mesh: return

	var scroll_tex = load("res://assets/buildables/conveyor_scroll.png")
	var diag_tex = load("res://assets/buildables/conveyor_diag_top.png")
	var straight_tex = load("res://assets/buildables/conveyor_top.png")
	
	if not scroll_tex: return
	
	var is_turn = false
	var turn_rotation = 0.0
	
	var in_dir = active_input_direction
	var out_dir = output_direction
	
	# Direction Values (from BaseBuilding enum):
	# DOWN=0, LEFT=1, UP=2, RIGHT=3
	
	if in_dir != out_dir and abs(int(out_dir) - int(in_dir)) != 2:
		is_turn = true
		
		# Texture `conveyor_diag_top.png` connects UP (Top) and RIGHT.
		# Mapping pairs to texture rotation:
		
		# 1. UP & RIGHT (2 & 3) -> 0 deg
		if (in_dir == Direction.UP and out_dir == Direction.RIGHT) or (in_dir == Direction.RIGHT and out_dir == Direction.UP):
			turn_rotation = 0.0
		
		# 2. RIGHT & DOWN (3 & 0) -> -90 deg
		elif (in_dir == Direction.RIGHT and out_dir == Direction.DOWN) or (in_dir == Direction.DOWN and out_dir == Direction.RIGHT):
			turn_rotation = deg_to_rad(-90)
			
		# 3. DOWN & LEFT (0 & 1) -> 180 deg
		elif (in_dir == Direction.DOWN and out_dir == Direction.LEFT) or (in_dir == Direction.LEFT and out_dir == Direction.DOWN):
			turn_rotation = deg_to_rad(180)
			
		# 4. LEFT & UP (1 & 2) -> 90 deg
		elif (in_dir == Direction.LEFT and out_dir == Direction.UP) or (in_dir == Direction.UP and out_dir == Direction.LEFT):
			turn_rotation = deg_to_rad(90)
	
	# Apply to mesh surfaces
	# Top Face is typically Surface 0 in standard cube maps
	var surface_count = mesh_inst.mesh.get_surface_count()
	
	for i in [0, 2, 3]: # Top(0), Front(2), Back(3) typically used for scrolling
		if i >= surface_count: continue
		var active_mat = mesh_inst.get_surface_override_material(i)
		# Fallback to mesh material if no override
		if not active_mat: active_mat = mesh_inst.mesh.surface_get_material(i)
		if not active_mat: continue

		var texture_to_use = null
		
		if active_mat is StandardMaterial3D:
			texture_to_use = active_mat.albedo_texture
		elif active_mat is ShaderMaterial:
			texture_to_use = active_mat.get_shader_parameter("base_texture")
		
		var uv_rot = 0.0
		
		# Top Face Logic
		if i == 0:
			if is_turn and diag_tex:
				texture_to_use = diag_tex
				uv_rot = turn_rotation
			elif straight_tex:
				texture_to_use = straight_tex

		var shader_mat = ShaderMaterial.new()
		shader_mat.shader = _get_conveyor_shader()
		shader_mat.set_shader_parameter("base_texture", texture_to_use)
		shader_mat.set_shader_parameter("scroll_texture", scroll_tex)
		shader_mat.set_shader_parameter("speed", 1.0)
		
		var uv_scale = 1.0
		if i == 2 or i == 3: uv_scale = 18.0 / 32.0
		shader_mat.set_shader_parameter("uv_scale_y", uv_scale)
		shader_mat.set_shader_parameter("uv_rotation", uv_rot)
			
		mesh_inst.set_surface_override_material(i, shader_mat)

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
	
	vec2 rotateUV(vec2 uv, float rotation) {
		float mid = 0.5;
		return vec2(
			cos(rotation) * (uv.x - mid) + sin(rotation) * (uv.y - mid) + mid,
			cos(rotation) * (uv.y - mid) - sin(rotation) * (uv.x - mid) + mid
		);
	}
	
	void fragment() {
		vec2 base_uv = rotateUV(UV, uv_rotation);
		vec4 base = texture(base_texture, base_uv);
		
		// Scroll logic
		// We scroll Y. For rotation to work, we must rotate the scroll UVs too.
		// Base scroll UV before rotation
		vec2 scroll_uv_raw = vec2(UV.x, mod((UV.y * uv_scale_y * 0.5) + (TIME * speed), 0.5));
		
		// Rotate scroll UVs to match curve
		vec2 scroll_uv = rotateUV(scroll_uv_raw, uv_rotation);
		
		vec4 scroll = texture(scroll_texture, scroll_uv);
		
		// Mask logic (Green/Blue/Red ch < 0.05 and Alpha > 0.9 = Mask Area)
		if (base.r < 0.05 && base.g < 0.05 && base.b < 0.05 && base.a > 0.9) { 
			ALBEDO = scroll.rgb; 
		} else { 
			ALBEDO = base.rgb; 
		}
		ALPHA = 1.0;
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
				# Reverse speed for back face (3) to look correct
				var final_spd = -spd if i == 3 else spd
				mat.set_shader_parameter("speed", final_spd)

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
