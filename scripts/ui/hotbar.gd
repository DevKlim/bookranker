extends PanelContainer

## Manages the build hotbar UI with 10 slots. 
## Supports drag-and-drop assignment of buildables.

const SLOT_COUNT = 10

@onready var container: HBoxContainer = $MarginContainer/HBoxContainer

# Array[BuildableResource] - can contain nulls
var slots: Array = []
var _buttons: Array[Button] = []

# Exposed property to configure default items in the inspector/scene
@export var buildables: Array[BuildableResource] = []

func _ready() -> void:
	# Initialize slots array
	slots.resize(SLOT_COUNT)
	slots.fill(null)
	
	# Clear existing children
	for child in container.get_children():
		child.queue_free()

	# Create Slot Buttons
	for i in range(SLOT_COUNT):
		var button = Button.new()
		button.custom_minimum_size = Vector2(64, 64)
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.text = str((i + 1) % 10) # 1, 2... 9, 0
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		
		# Connect Click
		button.pressed.connect(_on_slot_pressed.bind(i))
		
		# Setup Drag & Drop
		button.set_drag_forwarding(Callable(), Callable(self, "_can_drop_on_slot"), Callable(self, "_drop_on_slot").bind(i))
		
		container.add_child(button)
		_buttons.append(button)
	
	# Pre-fill slots from export if present, otherwise load defaults from disk
	if not buildables.is_empty():
		for i in range(min(buildables.size(), SLOT_COUNT)):
			slots[i] = buildables[i]
	else:
		_load_defaults()

	BuildManager.build_mode_changed.connect(_update_visuals)
	BuildManager.selected_buildable_changed.connect(_update_visuals)
	_update_visuals()

func _load_defaults() -> void:
	# Automatically load all buildable resources from the folder
	var dir = DirAccess.open("res://resources/buildables")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		var idx = 0
		while file_name != "" and idx < SLOT_COUNT:
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var res = load("res://resources/buildables/" + file_name)
				if res is BuildableResource:
					slots[idx] = res
					idx += 1
			file_name = dir.get_next()
	_update_visuals()

func _unhandled_key_input(event: InputEvent) -> void:
	# Check for number keys 1-9, 0
	if event.is_pressed() and not event.is_echo():
		for i in range(1, 11):
			if Input.is_key_pressed(KEY_0 + (i % 10)): # 1->KEY_1... 10->KEY_0
				_on_slot_pressed(i - 1)
				get_viewport().set_input_as_handled()
				return

func _on_slot_pressed(index: int) -> void:
	var buildable = slots[index]
	if not buildable: return

	if BuildManager.is_building and BuildManager.selected_buildable == buildable:
		BuildManager.exit_build_mode()
	else:
		BuildManager.enter_build_mode(buildable)

# Drag & Drop Logic
func _can_drop_on_slot(_at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.get("type") == "buildable"

func _drop_on_slot(_at_position: Vector2, data: Variant, slot_index: int) -> void:
	var res = data.get("resource")
	if res is BuildableResource:
		slots[slot_index] = res
		_update_visuals()

func _update_visuals(_arg = null) -> void:
	var selected = BuildManager.selected_buildable
	
	for i in range(SLOT_COUNT):
		var button = _buttons[i]
		var buildable = slots[i]
		
		if buildable:
			button.icon = buildable.icon
			button.tooltip_text = "%s\nSlot %d" % [buildable.buildable_name, (i + 1) % 10]
		else:
			button.icon = null
			button.tooltip_text = "Empty Slot %d" % ((i + 1) % 10)
		
		# Highlight Logic
		button.modulate = Color.WHITE
		if buildable and selected == buildable:
			button.modulate = Color(0.5, 1.0, 0.5) # Greenish for active
