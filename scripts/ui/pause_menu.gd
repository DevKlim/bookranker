class_name PauseMenu
extends Control

signal resume_requested
signal quit_requested

@onready var resume_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/ResumeButton
@onready var quit_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/QuitButton
@onready var panel: PanelContainer = $PanelContainer

func _apply_liquid_glass(win: Control, corner_radius: float = 12.0) -> void:
	win.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	
	var bbc = BackBufferCopy.new()
	bbc.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	win.add_child(bbc)
	win.move_child(bbc, 0)
	
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat = ShaderMaterial.new()
	var shader = load("res://shaders/liquid_glass.gdshader")
	if shader:
		mat.shader = shader
		mat.set_shader_parameter("tint", Color(0.9, 0.9, 0.9, 0.45))
		mat.set_shader_parameter("corner_radius", corner_radius)
		mat.set_shader_parameter("bezel_width", 8.0)
	bg.material = mat
	win.add_child(bg)
	win.move_child(bg, 1)
	
	win.resized.connect(func(): if mat.shader: mat.set_shader_parameter("rect_size", win.size))
	win.call_deferred("emit_signal", "resized")

func _ready() -> void:
	if panel:
		_apply_liquid_glass(panel, 12.0)
		
		var margin = panel.get_node_or_null("MarginContainer")
		if margin:
			margin.add_theme_constant_override("margin_left", 24)
			margin.add_theme_constant_override("margin_right", 24)
			margin.add_theme_constant_override("margin_top", 24)
			margin.add_theme_constant_override("margin_bottom", 24)

		var fake_title = Label.new()
		fake_title.text = "Game Paused"
		fake_title.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
		fake_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fake_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
		fake_title.position = Vector2(0, 16)
		panel.add_child(fake_title)
	
	if resume_btn:
		resume_btn.add_theme_color_override("font_color", Color.BLACK)
	if quit_btn:
		quit_btn.add_theme_color_override("font_color", Color.BLACK)
	
	resume_btn.pressed.connect(_on_resume_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)

func _on_resume_pressed() -> void:
	emit_signal("resume_requested")

func _on_quit_pressed() -> void:
	emit_signal("quit_requested")

func focus_resume() -> void:
	if resume_btn: resume_btn.grab_focus()
