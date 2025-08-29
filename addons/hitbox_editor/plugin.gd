@tool
extends EditorPlugin

const AttackScript = preload("res://scripts/Attack.gd")

var animation_scrubber: HSlider
var frame_label: Label
var currently_selected_attack: Attack = null

func _enter_tree():
	var bottom_panel = get_editor_interface().get_editor_viewport_2d().get_parent()
	var ui_container = HBoxContainer.new()
	ui_container.name = "AnimationScrubberContainer"
	
	animation_scrubber = HSlider.new()
	animation_scrubber.custom_minimum_size = Vector2(200, 0)
	animation_scrubber.step = 1
	animation_scrubber.value_changed.connect(_on_scrubber_value_changed)
	
	frame_label = Label.new()
	frame_label.text = " Frame: 0 / 0 "
	
	ui_container.add_child(Label.new()) # Spacer
	ui_container.add_child(frame_label)
	ui_container.add_child(animation_scrubber)
	ui_container.add_child(Label.new()) # Spacer
	
	bottom_panel.add_child(ui_container)
	ui_container.hide()

	get_editor_interface().get_selection().selection_changed.connect(_on_selection_changed)

func _exit_tree():
	var bottom_panel = get_editor_interface().get_editor_viewport_2d().get_parent()
	var ui_container = bottom_panel.get_node_or_null("AnimationScrubberContainer")
	if ui_container:
		ui_container.queue_free()

	if is_instance_valid(currently_selected_attack):
		if currently_selected_attack.is_connected("editor_frame_changed", _on_inspector_frame_changed):
			currently_selected_attack.editor_frame_changed.disconnect(_on_inspector_frame_changed)

	get_editor_interface().get_selection().selection_changed.disconnect(_on_selection_changed)

func _on_selection_changed():
	var selected_nodes = get_editor_interface().get_selection().get_selected_nodes()
	var ui_container = get_editor_interface().get_editor_viewport_2d().get_parent().get_node("AnimationScrubberContainer")
	
	# Disconnect from previously selected attack node
	if is_instance_valid(currently_selected_attack):
		if currently_selected_attack.is_connected("editor_frame_changed", _on_inspector_frame_changed):
			currently_selected_attack.editor_frame_changed.disconnect(_on_inspector_frame_changed)
		
		# Hide its hitboxes
		for child in currently_selected_attack.get_children():
			if "start_frame" in child:
				child.hide()

	# If the new selection is not an Attack node, hide everything and return
	if selected_nodes.is_empty() or not selected_nodes[0].get_script() == AttackScript:
		ui_container.hide()
		currently_selected_attack = null
		return
	
	currently_selected_attack = selected_nodes[0]
	
	var player = currently_selected_attack.get_parent().get_parent() if currently_selected_attack.get_parent() else null
	if not is_instance_valid(player): return
	
	var sprite: AnimatedSprite2D = player.get_node_or_null("AnimatedSprite2D")
	if not is_instance_valid(sprite): return
	
	var anim_name = currently_selected_attack.animation_name
	if sprite.sprite_frames.has_animation(anim_name):
		var frame_count = sprite.sprite_frames.get_frame_count(anim_name)
		animation_scrubber.max_value = frame_count - 1 if frame_count > 0 else 0
		sprite.play(anim_name)
		sprite.stop()
		
		# Set initial frame and connect the signal
		_update_frame(currently_selected_attack.editor_preview_frame, true)
		currently_selected_attack.editor_frame_changed.connect(_on_inspector_frame_changed)
		
		ui_container.show()
	else:
		ui_container.hide()

func _on_scrubber_value_changed(value: float):
	# Called when the BOTTOM SLIDER is moved.
	_update_frame(value)

func _on_inspector_frame_changed(value: int):
	# Called when the INSPECTOR property is changed.
	_update_frame(value, true)

func _update_frame(value: float, from_inspector: bool = false):
	if not is_instance_valid(currently_selected_attack):
		return
		
	var player = currently_selected_attack.get_parent().get_parent()
	var sprite: AnimatedSprite2D = player.get_node_or_null("AnimatedSprite2D")
	if not is_instance_valid(sprite): return

	var frame = int(value)
	
	# 1. Update sprite frame and UI label.
	sprite.frame = frame
	frame_label.text = " Frame: %d / %d " % [frame, animation_scrubber.max_value]

	# 2. Update the other controller (if the change didn't come from it).
	if from_inspector:
		animation_scrubber.set_value_no_signal(frame)
	else:
		# Use set_block_signals to prevent an infinite loop.
		currently_selected_attack.set_block_signals(true)
		currently_selected_attack.editor_preview_frame = frame
		currently_selected_attack.set_block_signals(false)

	# 3. Update hitbox visibility.
	for child in currently_selected_attack.get_children():
		if "start_frame" in child and "end_frame" in child:
			var is_active = (frame >= child.start_frame and frame < child.end_frame)
			child.visible = is_active