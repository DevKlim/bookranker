class_name HighlightSystem
extends Node

## Rebuilt using a CanvasLayer for robust 2D screen-space outlines.
## Eliminates the white plane / depth sorting bug from the old QuadMesh approach.

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
	
	# 3. Outline Overlay on Canvas
	var canvas = CanvasLayer.new()
	canvas.layer = 90 # Above game UI but below CRT Filter
	canvas.name = "HighlightCanvas"
	add_child(canvas)
	
	var outline_rect = ColorRect.new()
	outline_rect.name = "HighlightEffect"
	outline_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	outline_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var outline_mat = ShaderMaterial.new()
	outline_mat.shader = load("res://shaders/highlight_outline.gdshader")
	outline_mat.set_shader_parameter("width_outline", 3.0)
	outline_mat.set_shader_parameter("color_inner", Color(1.0, 1.0, 1.0, 0.0))
	outline_mat.set_shader_parameter("color_outline", Color(0.05, 0.05, 0.15, 1.0))
	
	var vp_tex = viewport.get_texture()
	outline_mat.set_shader_parameter("highlighted_viewport_tex", vp_tex)
	
	outline_rect.material = outline_mat
	canvas.add_child(outline_rect)
	
	set_process(true)

func _process(_delta: float) -> void:
	if is_instance_valid(highlight_cam) and is_instance_valid(target_cam):
		highlight_cam.global_transform = target_cam.global_transform
		highlight_cam.projection = target_cam.projection
		highlight_cam.size = target_cam.size
		highlight_cam.fov = target_cam.fov
		highlight_cam.near = target_cam.near
		highlight_cam.far = target_cam.far
