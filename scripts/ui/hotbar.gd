extends PanelContainer

## Manages the build hotbar UI, creating buttons and handling input.

@export var buildables: Array[BuildableResource]

@onready var container: HBoxContainer = $MarginContainer/HBoxContainer

# A dictionary to map an action name (e.g., "hotbar_1") to a buildable resource.
var _hotkey_map: Dictionary = {}


func _ready() -> void:
	# Ensure the container is empty before populating.
	for child in container.get_children():
		child.queue_free()

	# Create a button for each buildable resource.
	for i in range(buildables.size()):
		var buildable = buildables[i]
		if not is_instance_of(buildable, BuildableResource):
			continue

		var button = Button.new()
		button.icon = buildable.icon
		button.custom_minimum_size = Vector2(64, 64)
		
		# Set the tooltip text that appears on hover.
		button.tooltip_text = "%s (%d)" % [buildable.buildable_name, i + 1]
		
		button.pressed.connect(_on_button_pressed.bind(buildable))
		container.add_child(button)
		
		# Map the hotkey action to the buildable.
		var action_name = "hotbar_%d" % (i + 1)
		if InputMap.has_action(action_name):
			_hotkey_map[action_name] = buildable


func _unhandled_input(event: InputEvent) -> void:
	# Check if any of our mapped hotkey actions were pressed.
	for action_name in _hotkey_map:
		if event.is_action_pressed(action_name):
			var buildable: BuildableResource = _hotkey_map[action_name]
			_on_button_pressed(buildable)
			# Mark as handled to prevent other nodes from processing it.
			get_viewport().set_input_as_handled()
			return


func _on_button_pressed(buildable: BuildableResource) -> void:
	# If we're already building the same thing, exit build mode.
	if BuildManager.is_building and BuildManager.selected_buildable == buildable:
		BuildManager.exit_build_mode()
	else: # Otherwise, enter build mode with the selected item.
		BuildManager.enter_build_mode(buildable)