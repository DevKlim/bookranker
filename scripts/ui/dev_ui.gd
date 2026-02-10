extends Panel

## Handles the developer UI for controlling waves and spawning enemies.
## Self-contained UI component that styles itself and connects to WaveManager.

var wave_select: OptionButton

func _ready() -> void:
	_setup_visuals()
	_build_ui()
	_populate_waves()

func _setup_visuals() -> void:
	# Ensure the panel has a background
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.3, 0.35)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	add_theme_stylebox_override("panel", style)

func _build_ui() -> void:
	# 1. Clear old children
	for child in get_children():
		child.queue_free()
	
	# 2. Container
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)
	
	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)
	
	# 3. Header
	var lbl = Label.new()
	lbl.text = "Wave Control"
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(lbl)
	
	layout.add_child(HSeparator.new())
	
	# 4. Wave Selector
	wave_select = OptionButton.new()
	wave_select.tooltip_text = "Select a wave configuration"
	layout.add_child(wave_select)
	
	# 5. Controls
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	layout.add_child(hbox)
	
	var btn_start = Button.new()
	btn_start.text = "Start Wave"
	btn_start.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_start.pressed.connect(_on_spawn_wave_button_pressed)
	hbox.add_child(btn_start)
	
	var btn_stop = Button.new()
	btn_stop.text = "Stop"
	btn_stop.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_stop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_stop.pressed.connect(_on_stop_wave_button_pressed)
	hbox.add_child(btn_stop)
	
	# 6. Utilities
	var btn_reload = Button.new()
	btn_reload.text = "Reload Config"
	btn_reload.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_reload.pressed.connect(_on_reload_pressed)
	layout.add_child(btn_reload)

func _populate_waves() -> void:
	wave_select.clear()
	var count = WaveManager.get_total_waves()
	if count == 0:
		wave_select.add_item("No Waves Loaded")
		wave_select.disabled = true
	else:
		wave_select.disabled = false
		for i in range(count):
			wave_select.add_item("Wave %d" % (i + 1), i)
		wave_select.selected = 0

func _on_spawn_wave_button_pressed() -> void:
	if wave_select.item_count > 0:
		var idx = wave_select.selected
		if idx == -1: idx = 0
		WaveManager.start_wave(idx)

func _on_stop_wave_button_pressed() -> void:
	WaveManager.stop_wave()

func _on_reload_pressed() -> void:
	WaveManager._load_waves_config()
	_populate_waves()
