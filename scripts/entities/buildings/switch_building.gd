class_name SwitchBuilding
extends BaseBuilding

var is_switch: bool = true
var switch_state: bool = true
var cooldown_timer: float = 0.0

var _toggle_bg: Panel
var _knob: Panel
var _cooldown_label: Label
var _last_displayed_state = null

func _ready() -> void:
	super._ready()
	is_active = true # Always remain powered on
	
	# Set initial sprite color based on state
	var sprite = _get_main_sprite()
	if sprite:
		sprite.modulate = Color.WHITE if switch_state else Color(0.4, 0.4, 0.4)

func _setup_power_component() -> void:
	# Override to prevent registering as a consumer. Switch does not need power.
	pass

func _on_power_status_changed(_has_power: bool) -> void:
	# Force the switch to constantly act as if it has power
	is_active = true
	super._on_power_status_changed(true)

func _process(delta: float) -> void:
	if cooldown_timer > 0.0:
		cooldown_timer -= delta
		if cooldown_timer < 0.0:
			cooldown_timer = 0.0
		
	_update_custom_ui()

# Built-in framework method called by InventoryGUI to mount custom interfaces safely
func build_custom_ui(container: Control) -> void:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	
	var title = Label.new()
	title.text = "Circuit Control"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var font = load("res://assets/fonts/v2-fs-tahoma-8px.otf")
	if font: title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
	vbox.add_child(title)
	
	_toggle_bg = Panel.new()
	_toggle_bg.custom_minimum_size = Vector2(100, 40)
	_toggle_bg.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	
	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.3, 0.8, 0.3) if switch_state else Color(0.8, 0.3, 0.3)
	bg_style.corner_radius_top_left = 20; bg_style.corner_radius_top_right = 20
	bg_style.corner_radius_bottom_left = 20; bg_style.corner_radius_bottom_right = 20
	_toggle_bg.add_theme_stylebox_override("panel", bg_style)
	
	_knob = Panel.new()
	_knob.custom_minimum_size = Vector2(36, 36)
	
	var knob_style = StyleBoxFlat.new()
	knob_style.bg_color = Color.WHITE # Pure white toggle knob
	knob_style.corner_radius_top_left = 18; knob_style.corner_radius_top_right = 18
	knob_style.corner_radius_bottom_left = 18; knob_style.corner_radius_bottom_right = 18
	knob_style.border_width_bottom = 3
	knob_style.border_color = Color(0, 0, 0, 0.2)
	_knob.add_theme_stylebox_override("panel", knob_style)
	
	_toggle_bg.add_child(_knob)
	
	var target_x = 62.0 if switch_state else 2.0
	_knob.position = Vector2(target_x, 2)
	
	_last_displayed_state = switch_state
	
	_toggle_bg.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_toggle_bg.accept_event() # Consume the event
			toggle_switch()
	)
	
	vbox.add_child(_toggle_bg)
	
	_cooldown_label = Label.new()
	_cooldown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if font: _cooldown_label.add_theme_font_override("font", font)
	_cooldown_label.add_theme_font_size_override("font_size", 14)
	_cooldown_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	_cooldown_label.text = "Ready"
	vbox.add_child(_cooldown_label)
	
	container.add_child(vbox)

func _update_custom_ui() -> void:
	if not is_instance_valid(_toggle_bg) or not is_instance_valid(_knob) or not is_instance_valid(_cooldown_label):
		return
		
	var bg_style = _toggle_bg.get_theme_stylebox("panel") as StyleBoxFlat
	
	if cooldown_timer > 0.0:
		bg_style.bg_color = Color(0.6, 0.6, 0.6)
		_cooldown_label.text = "Cycling... %.1fs" % cooldown_timer
		_last_displayed_state = null # Force animation replay immediately when cooldown ends
	else:
		_cooldown_label.text = "Ready"
		
		# Animate the UI visually only when the state fully processes/changes
		if _last_displayed_state != switch_state:
			_last_displayed_state = switch_state
			
			var target_x = 62.0 if switch_state else 2.0
			var target_color = Color(0.3, 0.8, 0.3) if switch_state else Color(0.8, 0.3, 0.3)
			
			if is_instance_valid(get_tree()):
				var tween = get_tree().create_tween().set_parallel(true)
				tween.tween_property(_knob, "position:x", target_x, 0.15).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
				tween.tween_property(bg_style, "bg_color", target_color, 0.15)

func toggle_switch() -> void:
	if cooldown_timer > 0.0:
		return
		
	switch_state = !switch_state
	var speed_stat = get_stat("process_speed", 1.0)
	cooldown_timer = 1.0 / max(0.1, speed_stat)
	
	var sprite = _get_main_sprite()
	if sprite:
		sprite.modulate = Color.WHITE if switch_state else Color(0.4, 0.4, 0.4)
		
	if is_instance_valid(WiringManager):
		WiringManager.update_network()
