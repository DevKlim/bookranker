class_name PauseMenu
extends Control

signal resume_requested
signal quit_requested

@onready var resume_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/ResumeButton
@onready var quit_btn: Button = $PanelContainer/MarginContainer/VBoxContainer/QuitButton
@onready var panel: PanelContainer = $PanelContainer
@onready var vbox: VBoxContainer = $PanelContainer/MarginContainer/VBoxContainer

var res_option: OptionButton
var fs_check: CheckButton
var int_check: CheckButton

const RESOLUTIONS =[
	Vector2i(640, 360),
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160)
]

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

	_enforce_anti_warp_scaling()
	_build_settings_ui()

func _build_settings_ui() -> void:
	if not vbox: return
	
	var settings_panel = PanelContainer.new()
	var sp_style = StyleBoxFlat.new()
	sp_style.bg_color = Color(0, 0, 0, 0.2)
	sp_style.corner_radius_top_left = 6; sp_style.corner_radius_top_right = 6
	sp_style.corner_radius_bottom_left = 6; sp_style.corner_radius_bottom_right = 6
	settings_panel.add_theme_stylebox_override("panel", sp_style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	settings_panel.add_child(margin)
	
	var set_vbox = VBoxContainer.new()
	set_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(set_vbox)
	
	# Resolution Settings
	var res_hbox = HBoxContainer.new()
	
	var res_label = Label.new()
	res_label.text = "Resolution:"
	res_label.add_theme_color_override("font_color", Color.WHITE)
	res_hbox.add_child(res_label)
	
	var spacer1 = Control.new()
	spacer1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	res_hbox.add_child(spacer1)
	
	res_option = OptionButton.new()
	res_option.custom_minimum_size = Vector2(150, 0)
	for res in RESOLUTIONS:
		res_option.add_item(str(res.x) + " x " + str(res.y))
	
	# Try to select the closest match
	var current_size = DisplayServer.window_get_size()
	for i in range(RESOLUTIONS.size()):
		if RESOLUTIONS[i] == current_size:
			res_option.selected = i
			break
			
	res_option.item_selected.connect(_on_resolution_selected)
	res_hbox.add_child(res_option)
	set_vbox.add_child(res_hbox)
	
	# Fullscreen Toggle
	var fs_hbox = HBoxContainer.new()
	
	var fs_label = Label.new()
	fs_label.text = "Fullscreen:"
	fs_label.add_theme_color_override("font_color", Color.WHITE)
	fs_hbox.add_child(fs_label)
	
	var spacer2 = Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fs_hbox.add_child(spacer2)
	
	fs_check = CheckButton.new()
	fs_check.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	fs_check.toggled.connect(_on_fullscreen_toggled)
	fs_hbox.add_child(fs_check)
	set_vbox.add_child(fs_hbox)
	
	# Integer Scaling Toggle
	var int_hbox = HBoxContainer.new()
	
	var int_label = Label.new()
	int_label.text = "Integer Scaling:"
	int_label.add_theme_color_override("font_color", Color.WHITE)
	int_hbox.add_child(int_label)
	
	var spacer3 = Control.new()
	spacer3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	int_hbox.add_child(spacer3)
	
	int_check = CheckButton.new()
	var root = get_tree().root
	if "content_scale_stretch" in root:
		int_check.button_pressed = root.get("content_scale_stretch") == 1
	int_check.toggled.connect(_on_integer_scaling_toggled)
	int_hbox.add_child(int_check)
	set_vbox.add_child(int_hbox)
	
	vbox.add_child(settings_panel)
	vbox.move_child(settings_panel, quit_btn.get_index())

func _enforce_anti_warp_scaling() -> void:
	# Enforce canvas items expansion mode which natively maps physical display pixels to Control rects
	# thus completely avoiding the non-integer fractional rendering that warps pixel art
	var root = get_tree().root
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	
	if "content_scale_stretch" in root:
		root.set("content_scale_stretch", 1) # Window.CONTENT_SCALE_STRETCH_INTEGER

func _on_resolution_selected(idx: int) -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		if fs_check: fs_check.button_pressed = false
		
	var size = RESOLUTIONS[idx]
	DisplayServer.window_set_size(size)
	
	# Center the window safely
	var screen_size = DisplayServer.screen_get_size()
	var target_pos = screen_size / 2 - size / 2
	if target_pos.y < 30: target_pos.y = 30 # Avoid hiding title bar under OS top bar
	DisplayServer.window_set_position(target_pos)

func _on_fullscreen_toggled(pressed: bool) -> void:
	if pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		_on_resolution_selected(res_option.selected)

func _on_integer_scaling_toggled(pressed: bool) -> void:
	var root = get_tree().root
	if "content_scale_stretch" in root:
		root.set("content_scale_stretch", 1 if pressed else 0)

func _on_resume_pressed() -> void:
	emit_signal("resume_requested")

func _on_quit_pressed() -> void:
	emit_signal("quit_requested")

func focus_resume() -> void:
	if resume_btn: resume_btn.grab_focus()
