class_name ContextMenu
extends CanvasLayer

var bg_click: ColorRect
var panel: PanelContainer
var vbox: VBoxContainer

func _ready() -> void:
	layer = 150
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

	bg_click = ColorRect.new()
	bg_click.color = Color(0, 0, 0, 0)
	bg_click.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_click.gui_input.connect(_on_bg_gui_input)
	add_child(bg_click)

	panel = PanelContainer.new()
	
	# Clean white background with subtle border and shadow instead of liquid glass
	var style = StyleBoxFlat.new()
	style.bg_color = Color.WHITE
	style.border_width_left = 1; style.border_width_right = 1
	style.border_width_top = 1; style.border_width_bottom = 1
	style.border_color = Color(0.8, 0.8, 0.8, 0.6)
	style.corner_radius_top_left = 6; style.corner_radius_top_right = 6
	style.corner_radius_bottom_right = 6; style.corner_radius_bottom_left = 6
	style.shadow_color = Color(0, 0, 0, 0.15)
	style.shadow_size = 8
	panel.add_theme_stylebox_override("panel", style)
	
	add_child(panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

func _on_bg_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		hide_menu()

func show_menu(screen_pos: Vector2, options: Array) -> void:
	if options.is_empty(): return

	for child in vbox.get_children():
		child.queue_free()

	var font = load("res://assets/fonts/v2-fs-tahoma-8px.otf")

	for opt in options:
		var btn = Button.new()
		btn.text = opt.label
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if font: btn.add_theme_font_override("font", font)
		btn.add_theme_font_size_override("font_size", 14)
		btn.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

		var sb_normal = StyleBoxFlat.new()
		sb_normal.bg_color = Color(0, 0, 0, 0)
		var sb_hover = StyleBoxFlat.new()
		sb_hover.bg_color = Color(0, 0, 0, 0.05)
		sb_hover.corner_radius_top_left = 4; sb_hover.corner_radius_top_right = 4
		sb_hover.corner_radius_bottom_left = 4; sb_hover.corner_radius_bottom_right = 4

		btn.add_theme_stylebox_override("normal", sb_normal)
		btn.add_theme_stylebox_override("hover", sb_hover)
		btn.add_theme_stylebox_override("pressed", sb_hover)
		btn.add_theme_stylebox_override("focus", sb_normal)

		btn.pressed.connect(func():
			opt.callback.call()
			hide_menu()
		)
		vbox.add_child(btn)

	var cancel = Button.new()
	cancel.text = "Cancel"
	cancel.alignment = HORIZONTAL_ALIGNMENT_LEFT
	if font: cancel.add_theme_font_override("font", font)
	cancel.add_theme_font_size_override("font_size", 14)
	cancel.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))
	cancel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	var sb_normal_c = StyleBoxFlat.new()
	sb_normal_c.bg_color = Color(0, 0, 0, 0)
	var sb_hover_c = StyleBoxFlat.new()
	sb_hover_c.bg_color = Color(0.8, 0.2, 0.2, 0.1)
	sb_hover_c.corner_radius_top_left = 4; sb_hover_c.corner_radius_top_right = 4
	sb_hover_c.corner_radius_bottom_left = 4; sb_hover_c.corner_radius_bottom_right = 4
	
	cancel.add_theme_stylebox_override("normal", sb_normal_c)
	cancel.add_theme_stylebox_override("hover", sb_hover_c)
	cancel.add_theme_stylebox_override("pressed", sb_hover_c)
	cancel.add_theme_stylebox_override("focus", sb_normal_c)
	
	cancel.pressed.connect(hide_menu)

	var sep = ColorRect.new()
	sep.custom_minimum_size = Vector2(0, 2)
	sep.color = Color(0, 0, 0, 0.1)
	vbox.add_child(sep)
	vbox.add_child(cancel)

	panel.position = screen_pos
	visible = true

	# Clamp position so it stays on screen
	get_tree().process_frame.connect(func():
		if not is_instance_valid(panel): return
		var screen_size = get_viewport().get_visible_rect().size
		if panel.position.x + panel.size.x > screen_size.x:
			panel.position.x = screen_size.x - panel.size.x
		if panel.position.y + panel.size.y > screen_size.y:
			panel.position.y = screen_size.y - panel.size.y
	, CONNECT_ONE_SHOT)

func hide_menu() -> void:
	visible = false
