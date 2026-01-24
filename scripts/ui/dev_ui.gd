extends Panel

## Handles the developer UI for controlling waves.
## Cleans up existing children to ensure a unified, uncluttered interface.

var wave_select: OptionButton

func _ready() -> void:
	# 1. Clear old UI elements (declutter)
	for child in get_children():
		child.queue_free()
	
	# 2. Setup clean container with margins
	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)
	
	var layout = VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	margin.add_child(layout)
	
	# 3. Build New UI
	# Header
	var lbl = Label.new()
	lbl.text = "Wave Control"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(lbl)
	
	# Wave Selector
	wave_select = OptionButton.new()
	wave_select.tooltip_text = "Select a wave from waves.json"
	layout.add_child(wave_select)
	
	# Action Buttons (HBox)
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	layout.add_child(hbox)
	
	var btn_start = Button.new()
	btn_start.text = "Start"
	btn_start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_start.pressed.connect(_on_spawn_wave_button_pressed)
	hbox.add_child(btn_start)
	
	var btn_stop = Button.new()
	btn_stop.text = "Stop"
	btn_stop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_stop.pressed.connect(_on_stop_wave_button_pressed)
	hbox.add_child(btn_stop)
	
	# Utility Buttons
	var btn_reload = Button.new()
	btn_reload.text = "Reload JSON"
	btn_reload.pressed.connect(_on_reload_pressed)
	layout.add_child(btn_reload)
	
	# 4. Populate Data
	_populate_waves()

func _populate_waves() -> void:
	wave_select.clear()
	var count = WaveManager.get_total_waves()
	if count == 0:
		wave_select.add_item("No Waves Found")
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
