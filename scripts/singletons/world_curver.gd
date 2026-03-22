extends Node

## Singleton that applies a "Sega/Animal Crossing" style world curvature 
## by injecting a vertex warp into all active materials.

var base_curve_intensity: float = 0.025
var is_active: bool = true
var processed_materials: Dictionary = {}

func _ready() -> void:
	# Run a periodic scan to curve newly added meshes and overlays
	var timer = Timer.new()
	timer.wait_time = 0.5
	timer.autostart = true
	timer.timeout.connect(_scan_tree)
	add_child(timer)
	
	call_deferred("_scan_tree")

func set_active(active: bool) -> void:
	is_active = active
	var val = base_curve_intensity if is_active else 0.0
	for mat in processed_materials.values():
		if mat is ShaderMaterial:
			mat.set_shader_parameter("world_curve_intensity", val)

func _scan_tree() -> void:
	var root = get_tree().current_scene
	if root:
		_process_node(root)
		
	# Also process MeshLibraries (GridMap)
	var gridmaps = get_tree().get_nodes_in_group("gridmap")
	if gridmaps.is_empty():
		var main_scene = get_tree().current_scene
		if main_scene and main_scene.has_node("GridMap"):
			_process_mesh_library(main_scene.get_node("GridMap").mesh_library)

func _process_node(node: Node) -> void:
	if node is MeshInstance3D:
		_process_mesh_instance(node)
	elif node is Sprite3D or node is AnimatedSprite3D:
		_process_sprite(node)
		
	for child in node.get_children():
		_process_node(child)

func _process_mesh_instance(mesh_inst: MeshInstance3D) -> void:
	# Crucial: Process overrides and overlays so outlines don't detach from the base mesh!
	if mesh_inst.material_override:
		var new_mat = _get_curved_material(mesh_inst.material_override)
		if new_mat != mesh_inst.material_override:
			mesh_inst.material_override = new_mat
			
	if mesh_inst.material_overlay:
		var new_mat = _get_curved_material(mesh_inst.material_overlay)
		if new_mat != mesh_inst.material_overlay:
			mesh_inst.material_overlay = new_mat
			
	if not mesh_inst.mesh: return
	
	for i in range(mesh_inst.mesh.get_surface_count()):
		var mat = mesh_inst.get_active_material(i)
		if not mat: mat = mesh_inst.mesh.surface_get_material(i)
		
		if mat:
			var new_mat = _get_curved_material(mat)
			if new_mat != mat:
				mesh_inst.set_surface_override_material(i, new_mat)

func _process_sprite(sprite: GeometryInstance3D) -> void:
	if sprite.material_override:
		var new_mat = _get_curved_material(sprite.material_override)
		if new_mat != sprite.material_override:
			sprite.material_override = new_mat
			
	if sprite.material_overlay:
		var new_mat = _get_curved_material(sprite.material_overlay)
		if new_mat != sprite.material_overlay:
			sprite.material_overlay = new_mat

func _process_mesh_library(lib: MeshLibrary) -> void:
	if not lib: return
	for id in lib.get_item_list():
		var mesh = lib.get_item_mesh(id)
		if mesh:
			for i in range(mesh.get_surface_count()):
				var mat = mesh.surface_get_material(i)
				if mat:
					var new_mat = _get_curved_material(mat)
					if new_mat != mat:
						mesh.surface_set_material(i, new_mat)

func _get_curved_material(mat: Material) -> Material:
	if processed_materials.has(mat):
		return processed_materials[mat]
		
	var new_mat = mat
	
	if mat is StandardMaterial3D:
		# Convert StandardMaterial3D to ShaderMaterial
		new_mat = ShaderMaterial.new()
		new_mat.shader = _generate_standard_curve_shader(mat)
		new_mat.set_shader_parameter("albedo_color", mat.albedo_color)
		if mat.albedo_texture:
			new_mat.set_shader_parameter("texture_albedo", mat.albedo_texture)
			
		new_mat.set_shader_parameter("world_curve_intensity", base_curve_intensity if is_active else 0.0)
		processed_materials[mat] = new_mat
		
	elif mat is ShaderMaterial:
		# Inject vertex curvature into existing custom shaders natively
		if mat.shader and "world_curved" not in mat.shader.code:
			var code = mat.shader.code
			
			if "void vertex()" not in code:
				code += "\nvoid vertex() {\n}\n"
				
			code = code.replace("shader_type spatial;", "shader_type spatial;\nuniform float world_curve_intensity = 0.005;\n")
			
			var inject_code = "\n\t// world_curved\n\tvec3 w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;\n\tfloat d = length(w_pos.xz - CAMERA_POSITION_WORLD.xz);\n\tw_pos.y -= world_curve_intensity * d * d;\n\tVERTEX = (inverse(MODEL_MATRIX) * vec4(w_pos, 1.0)).xyz;\n"
			
			var new_code = code.replace("void vertex() {", "void vertex() {" + inject_code)
			var new_shader = Shader.new()
			new_shader.code = new_code
			
			new_mat = mat.duplicate()
			new_mat.shader = new_shader
			new_mat.set_shader_parameter("world_curve_intensity", base_curve_intensity if is_active else 0.0)
			processed_materials[mat] = new_mat

	return new_mat

func _generate_standard_curve_shader(base_mat: StandardMaterial3D) -> Shader:
	var alpha_code = ""
	var depth_draw = "depth_draw_opaque"
	if base_mat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		alpha_code = "ALPHA = albedo_color.a * tex.a;"
		depth_draw = "depth_draw_always"
		
	var s = Shader.new()
	s.code = """
	shader_type spatial;
	uniform float world_curve_intensity = 0.005;
	// world_curved
	render_mode blend_mix, """ + depth_draw + """, cull_back, diffuse_burley, specular_schlick_ggx;
	
	uniform vec4 albedo_color : source_color = vec4(1.0);
	uniform sampler2D texture_albedo : source_color, filter_nearest;
	
	void vertex() {
		vec3 w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		float d = length(w_pos.xz - CAMERA_POSITION_WORLD.xz);
		w_pos.y -= world_curve_intensity * d * d;
		VERTEX = (inverse(MODEL_MATRIX) * vec4(w_pos, 1.0)).xyz;
	}
	
	void fragment() {
		vec4 tex = texture(texture_albedo, UV);
		ALBEDO = albedo_color.rgb * tex.rgb;
		""" + alpha_code + """
	}
	"""
	return s
