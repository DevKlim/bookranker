class_name RetroVisuals extends RefCounted

## Utility class to handle the initialization of Y2K/Dreamcast/DS aesthetic 
## overlays and backgrounds across different scenes (Main Menu, Game, etc.)

static func setup_math_skybox(parent: Node, layer: int = -100) -> CanvasLayer:
	var bg_layer = CanvasLayer.new()
	bg_layer.layer = layer
	bg_layer.name = "MathSkyboxBackground"
	parent.add_child(bg_layer)

	var bg_viewport = SubViewport.new()
	bg_viewport.size = Vector2(2048, 2048)
	bg_viewport.transparent_bg = true
	bg_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	parent.add_child(bg_viewport)
	
	var bg_control = Control.new()
	bg_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_viewport.add_child(bg_control)
	
	# Spawn drifting math symbols
	var symbols = ["∑", "Δ", "π", "Ω", "∞", "∫", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "±", "√", "≈", "θ", "λ", "μ", "Φ", "α", "β", "γ", "∇"]
	var font = load("res://assets/fonts/cmu.serif-roman.ttf")
	
	for i in range(120):
		var lbl = Label.new()
		lbl.text = symbols.pick_random()
		if font: lbl.add_theme_font_override("font", font)
		lbl.add_theme_font_size_override("font_size", randi_range(32, 110))
		lbl.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, randf_range(0.2, 0.6)))
		lbl.position = Vector2(randf_range(0, 2048), randf_range(0, 2048))
		
		# Individual drifting behavior injected directly
		var scroller = GDScript.new()
		scroller.source_code = """
extends Label
var speed = Vector2()
var rot_speed = 0.0
func _ready():
	speed = Vector2(randf_range(-15.0, 15.0), randf_range(-50.0, -10.0))
	rot_speed = randf_range(-1.0, 1.0)
	pivot_offset = size / 2.0
func _process(delta):
	position += speed * delta
	rotation += rot_speed * delta
	if position.y < -150: position.y = 2150
	if position.x < -150: position.x = 2150
	if position.x > 2150: position.x = -150
"""
		scroller.reload()
		lbl.set_script(scroller)
		bg_control.add_child(lbl)

	var bg_rect = ColorRect.new()
	bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var bg_mat = ShaderMaterial.new()
	var bg_shader = load("res://shaders/math_skybox.gdshader")
	if bg_shader:
		bg_mat.shader = bg_shader
		bg_mat.set_shader_parameter("text_viewport", bg_viewport.get_texture())
	bg_rect.material = bg_mat
	bg_layer.add_child(bg_rect)

	return bg_layer

static func setup_crt_filter(parent: Node, layer: int = 120) -> CanvasLayer:
	var crt_layer = CanvasLayer.new()
	crt_layer.layer = layer
	crt_layer.name = "CRTFilter"
	parent.add_child(crt_layer)

	var crt_rect = ColorRect.new()
	crt_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	crt_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var crt_mat = ShaderMaterial.new()
	var crt_shader = load("res://shaders/crt_filter.gdshader")
	if crt_shader:
		crt_mat.shader = crt_shader
	crt_rect.material = crt_mat
	crt_layer.add_child(crt_rect)

	return crt_layer
