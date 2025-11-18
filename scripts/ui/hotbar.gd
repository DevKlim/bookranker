extends PanelContainer

## Manages the build hotbar UI, creating buttons and handling input.

@export var buildables: Array[BuildableResource]

@onready var container: HBoxContainer = $MarginContainer/HBoxContainer

var _hotkey_map: Dictionary = {}
var _buttons: Array[Button] = []

func _ready() -> void:
	for child in container.get_children():
		child.queue_free()

	for i in range(buildables.size()):
		var buildable = buildables[i]
		if not is_instance_of(buildable, BuildableResource): continue

		var button = Button.new()
		button.icon = buildable.icon
		button.custom_minimum_size = Vector2(64, 64)
		button.tooltip_text = "%s (%d)" % [buildable.buildable_name, i + 1]
		button.pressed.connect(_on_button_pressed.bind(buildable))
		container.add_child(button)
		_buttons.append(button)
		
		var action_name = "hotbar_%d" % (i + 1)
		if InputMap.has_action(action_name):
			_hotkey_map[action_name] = buildable
	
	BuildManager.build_mode_changed.connect(_update_button_visuals)
	BuildManager.selected_buildable_changed.connect(_update_button_visuals)
	_update_button_visuals()


func _unhandled_input(event: InputEvent) -> void:
	for action_name in _hotkey_map:
		if event.is_action_pressed(action_name):
			var buildable: BuildableResource = _hotkey_map[action_name]
			_on_button_pressed(buildable)
			get_viewport().set_input_as_handled()
			return


func _on_button_pressed(buildable: BuildableResource) -> void:
	if BuildManager.is_building and BuildManager.selected_buildable == buildable:
		BuildManager.exit_build_mode()
	else:
		BuildManager.enter_build_mode(buildable)


func _update_button_visuals(_arg = null) -> void:
	var selected = BuildManager.selected_buildable
	var selected_layer = -1
	if BuildManager.is_building and selected:
		selected_layer = selected.layer

	for i in range(_buttons.size()):
		var button = _buttons[i]
		var buildable = buildables[i]
		
		button.modulate = Color.WHITE

		if selected == buildable:
			button.modulate = Color(1.3, 1.3, 1.3)
		elif selected_layer != -1 and buildable.layer != selected_layer:
			if selected_layer != BuildableResource.BuildLayer.TOOL:
				button.modulate = Color(0.6, 0.6, 0.6)
