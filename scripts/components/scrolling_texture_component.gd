class_name ScrollingTextureComponent
extends Node

## Reusable component for creating animated scrolling textures on meshes.
## Supports masking by color (e.g. replacing black pixels with a scrolling sprite) or by alpha.

enum MaskMode { COLOR_MATCH, ALPHA_MATCH }

@export var target_mesh_path: NodePath
@export var scroll_texture: Texture2D
@export var scroll_speed: float = 1.0
@export var scroll_direction: Vector2 = Vector2(0.0, -1.0)
@export var scroll_scale: Vector2 = Vector2(1.0, 1.0)
@export var scroll_rotation: float = 0.0 # In degrees
@export var scroll_pivot: Vector2 = Vector2(0.5, 0.5) # Center point for scale/rotate/flip

@export_group("Masking Settings")
@export var mask_mode: MaskMode = MaskMode.COLOR_MATCH
@export var mask_color: Color = Color.BLACK
@export var mask_tolerance: float = 0.05
@export var alpha_tolerance: float = 0.1

@export_group("Surface Application")
@export var apply_to_all_surfaces: bool = true
@export var specific_surfaces: Array[int] = []
@export var wrap_half_y: bool = false # Used for legacy conveyor UV wrapping

var active_speed_multiplier: float = 1.0
var _materials: Dictionary = {} 
var _target_mesh: MeshInstance3D

func _ready() -> void:
	if not Engine.is_editor_hint():
		call_deferred("setup_materials")

func _find_target_mesh() -> void:
	if not target_mesh_path.is_empty():
		_target_mesh = get_node_or_null(target_mesh_path) as MeshInstance3D
		if _target_mesh: return

	var parent = get_parent()
	if not parent: return
	
	# Fallback 1: Direct child named BlockVisual (Conveyor standard)
	var visual = parent.get_node_or_null("BlockVisual")
	if visual is MeshInstance3D:
		_target_mesh = visual
		return
		
	# Fallback 2: Recursive search for GLTF imports
	_target_mesh = _find_first_mesh(parent)

func _find_first_mesh(node: Node) -> MeshInstance3D:
	for child in node.get_children():
		if child is MeshInstance3D:
			return child
		var found = _find_first_mesh(child)
		if found:
			return found
	return null

func setup_materials() -> void:
	if not is_instance_valid(_target_mesh):
		_find_target_mesh()
		
	if not is_instance_valid(_target_mesh) or not _target_mesh.mesh: 
		return
	
	var surface_count = _target_mesh.mesh.get_surface_count()
	for i in range(surface_count):
		if not apply_to_all_surfaces and not i in specific_surfaces:
			continue
			
		var active_mat = _target_mesh.get_surface_override_material(i)
		if not active_mat: active_mat = _target_mesh.mesh.surface_get_material(i)
		if not active_mat: continue

		var base_tex = null
		var base_color = Color(1.0, 1.0, 1.0, 1.0)
		
		if active_mat is StandardMaterial3D:
			base_tex = active_mat.albedo_texture
			base_color = active_mat.albedo_color
		elif active_mat is ShaderMaterial:
			base_tex = active_mat.get_shader_parameter("base_texture")
			if active_mat.get_shader_parameter("base_color") != null:
				base_color = active_mat.get_shader_parameter("base_color")

		var final_mat = ShaderMaterial.new()
		final_mat.shader = get_scrolling_shader()
		
		if active_mat.has_meta("is_ghost"):
			final_mat.set_meta("is_ghost", true)
			var tint = active_mat.get("albedo_color") if "albedo_color" in active_mat else Color(1, 1, 1, 0.5)
			if active_mat is ShaderMaterial:
				tint = active_mat.get_shader_parameter("tint_color")
			if tint:
				final_mat.set_shader_parameter("tint_color", tint)

		final_mat.set_shader_parameter("base_texture", base_tex)
		final_mat.set_shader_parameter("base_color", base_color)
		final_mat.set_shader_parameter("scroll_texture", scroll_texture)
		final_mat.set_shader_parameter("speed", scroll_speed * active_speed_multiplier)
		final_mat.set_shader_parameter("scroll_direction", scroll_direction)
		final_mat.set_shader_parameter("uv_scale", scroll_scale)
		final_mat.set_shader_parameter("uv_rotation", deg_to_rad(scroll_rotation))
		final_mat.set_shader_parameter("uv_pivot", scroll_pivot)
		final_mat.set_shader_parameter("use_color_mask", mask_mode == MaskMode.COLOR_MATCH)
		final_mat.set_shader_parameter("mask_color", Vector3(mask_color.r, mask_color.g, mask_color.b))
		final_mat.set_shader_parameter("mask_tolerance", mask_tolerance)
		final_mat.set_shader_parameter("use_alpha_mask", mask_mode == MaskMode.ALPHA_MATCH)
		final_mat.set_shader_parameter("alpha_tolerance", alpha_tolerance)
		final_mat.set_shader_parameter("wrap_half_y", wrap_half_y)
		
		_target_mesh.set_surface_override_material(i, final_mat)
		_materials[i] = final_mat

func set_active(active: bool) -> void:
	var spd = scroll_speed * active_speed_multiplier if active else 0.0
	for mat in _materials.values():
		if is_instance_valid(mat):
			mat.set_shader_parameter("speed", spd)

func set_speed_multiplier(mult: float) -> void:
	active_speed_multiplier = mult
	for mat in _materials.values():
		if is_instance_valid(mat):
			mat.set_shader_parameter("speed", scroll_speed * active_speed_multiplier)

func get_material(surface_idx: int) -> ShaderMaterial:
	return _materials.get(surface_idx, null)

func set_shader_parameter(param_name: String, value: Variant, surface_idx: int = -1) -> void:
	if surface_idx == -1:
		for mat in _materials.values():
			if is_instance_valid(mat): mat.set_shader_parameter(param_name, value)
	else:
		var mat = _materials.get(surface_idx)
		if is_instance_valid(mat): mat.set_shader_parameter(param_name, value)

static func get_scrolling_shader() -> Shader:
	var s = Shader.new()
	s.code = """
	shader_type spatial;
	render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;
	
	uniform sampler2D base_texture : source_color, filter_nearest;
	uniform vec4 base_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
	
	uniform sampler2D scroll_texture : source_color, filter_nearest, repeat_enable;
	uniform float speed = 1.0;
	uniform vec2 scroll_direction = vec2(0.0, -1.0);
	uniform vec2 uv_scale = vec2(1.0, 1.0);
	uniform float uv_rotation = 0.0;
	uniform vec2 uv_pivot = vec2(0.5, 0.5);
	uniform vec4 tint_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
	uniform vec2 uv_flip = vec2(1.0, 1.0);

	uniform bool use_color_mask = true;
	uniform vec3 mask_color = vec3(0.0, 0.0, 0.0);
	uniform float mask_tolerance = 0.05;
	uniform bool use_alpha_mask = false;
	uniform float alpha_tolerance = 0.1;
	uniform bool wrap_half_y = false;

	vec2 rotateUV(vec2 uv, float rotation, vec2 pivot) {
		return vec2(
			cos(rotation) * (uv.x - pivot.x) + sin(rotation) * (uv.y - pivot.y) + pivot.x,
			cos(rotation) * (uv.y - pivot.y) - sin(rotation) * (uv.x - pivot.x) + pivot.y
		);
	}

	void fragment() {
		vec2 flipped_uv = (UV - uv_pivot) * uv_flip + uv_pivot;
		vec2 base_uv = rotateUV(flipped_uv, uv_rotation, uv_pivot);
		vec4 base = texture(base_texture, base_uv) * base_color;
		
		vec2 scroll_uv_raw = flipped_uv;
		if (wrap_half_y) {
			scroll_uv_raw = vec2(
				(flipped_uv.x - uv_pivot.x) * uv_scale.x + uv_pivot.x, 
				mod((((flipped_uv.y - uv_pivot.y) * uv_scale.y + uv_pivot.y) * 0.5) + (TIME * speed * scroll_direction.y), 0.5)
			);
		} else {
			scroll_uv_raw = (flipped_uv - uv_pivot) * uv_scale + uv_pivot + (TIME * speed * scroll_direction);
		}
		vec2 scroll_uv = rotateUV(scroll_uv_raw, uv_rotation, uv_pivot);
		vec4 scroll = texture(scroll_texture, scroll_uv);
		
		vec3 final_col = base.rgb;
		float final_alpha = base.a;
		
		bool replace = false;
		if (use_color_mask) {
			if (abs(base.r - mask_color.r) <= mask_tolerance && 
				abs(base.g - mask_color.g) <= mask_tolerance && 
				abs(base.b - mask_color.b) <= mask_tolerance &&
				base.a > 0.9) {
				replace = true;
			}
		}
		if (use_alpha_mask) {
			if (base.a < alpha_tolerance) {
				replace = true;
			}
		}
		
		if (replace) {
			final_col = scroll.rgb;
			if (use_alpha_mask) {
				final_alpha = scroll.a;
			}
		}
		
		ALBEDO = final_col * tint_color.rgb;
		ALPHA = final_alpha * tint_color.a;
		if (ALPHA < 0.1) discard;
	}
	"""
	return s
