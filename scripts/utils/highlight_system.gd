class_name HighlightSystem
extends Node

## Instantiates the dual-viewport screen-space highlight effect
## dynamically to avoid manual scene/UUID corruption risks.

var viewport: SubViewport
var highlight_cam: Camera3D
var target_cam: Camera3D

func setup(main_camera: Camera3D) -> void:
	target_cam = main_camera
	
	# 1. Create Viewport
	viewport = SubViewport.new()
	viewport.name = "HighlightViewport"
	viewport.transparent_bg = true
	viewport.handle_input_locally = false
	viewport.gui_disable_input = true
	add_child(viewport)
	
	viewport.size = get_tree().get_root().size
	get_tree().get_root().size_changed.connect(func(): viewport.size = get_tree().get_root().size)
	
	# 2. Create Highlight Camera
	highlight_cam = Camera3D.new()
	highlight_cam.name = "HighlightCamera3D"
	highlight_cam.cull_mask = 1024 # Layer 11
	viewport.add_child(highlight_cam)
	
	# 3. Outline Mesh on Main Camera
	var outline_mesh = MeshInstance3D.new()
	outline_mesh.name = "HighlightEffect"
	outline_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	outline_mesh.extra_cull_margin = 16384.0
	outline_mesh.ignore_occlusion_culling = true
	
	var q2 = QuadMesh.new()
	q2.flip_faces = true
	q2.size = Vector2(2, 2)
	outline_mesh.mesh = q2
	
	var outline_mat = ShaderMaterial.new()
	outline_mat.shader = load("res://shaders/highlight_outline.gdshader")
	outline_mat.set_shader_parameter("width_outline", 3)
	outline_mat.set_shader_parameter("color_inner", Color(1.0, 1.0, 1.0, 0.0))
	outline_mat.set_shader_parameter("color_outline", Color(0.05, 0.05, 0.15, 1.0))
	
	var vp_tex = viewport.get_texture()
	outline_mat.set_shader_parameter("highlighted_viewport_tex", vp_tex)
	
	outline_mesh.material_override = outline_mat
	main_camera.add_child(outline_mesh)
	outline_mesh.position = Vector3(0, 0, -1.0)
	
	set_process(true)

func _process(_delta: float) -> void:
	if is_instance_valid(highlight_cam) and is_instance_valid(target_cam):
		highlight_cam.global_transform = target_cam.global_transform
		highlight_cam.projection = target_cam.projection
		highlight_cam.size = target_cam.size
		highlight_cam.fov = target_cam.fov
		highlight_cam.near = target_cam.near
		highlight_cam.far = target_cam.far
