@tool
extends Control

# --- COLOR SETUP ---
@export_group("Colors")
@export var instant_fill_color: Color = Color.RED:
	set(value):
		instant_fill_color = value
		_update_bar_colors()

@export var delayed_fill_color: Color = Color(1, 1, 1, 0.7):
	set(value):
		delayed_fill_color = value
		_update_bar_colors()

@export var background_color: Color = Color(0.2, 0.2, 0.2):
	set(value):
		background_color = value
		_update_bar_colors()

# --- EDITOR PREVIEW ---
# This new group lets you test the bar's value in the editor.
@export_group("Editor Preview")
@export_range(0.0, 100.0) var editor_value: float = 100.0:
	set(value):
		editor_value = value
		_update_editor_preview()

# --- TWEEN SETUP ---
@export_group("Animation")
@export var tween_delay: float = 0.5
@export var tween_duration: float = 0.4

# --- NODE REFERENCES ---
@onready var instant_fill: ProgressBar = $InstantFill
@onready var delayed_fill: ProgressBar = $DelayedFill
@onready var label: Label = $Label

# --- PRIVATE VARIABLES ---
var _current_tween: Tween

func _ready():
	_update_bar_colors()

# --- UPDATE FUNCTIONS ---
func _update_bar_colors():
	if not is_inside_tree(): return

	var delayed_bg_style = StyleBoxFlat.new()
	delayed_bg_style.bg_color = background_color
	delayed_fill.add_theme_stylebox_override("background", delayed_bg_style)

	var delayed_fill_style = StyleBoxFlat.new()
	delayed_fill_style.bg_color = delayed_fill_color
	delayed_fill.add_theme_stylebox_override("fill", delayed_fill_style)

	var instant_bg_style = StyleBoxFlat.new()
	instant_bg_style.bg_color = Color.TRANSPARENT
	instant_fill.add_theme_stylebox_override("background", instant_bg_style)

	var instant_fill_style = StyleBoxFlat.new()
	instant_fill_style.bg_color = instant_fill_color
	instant_fill.add_theme_stylebox_override("fill", instant_fill_style)

# This new function updates the bar's value in the editor only
func _update_editor_preview():
	# This ensures the code only runs in the editor, not in the game
	if not Engine.is_editor_hint():
		return
	if not is_inside_tree():
		return
		
	# Set the bars' values and label based on the editor_value
	instant_fill.value = editor_value
	delayed_fill.value = editor_value
	label.text = "%d / 100" % editor_value


# --- GAME LOGIC FUNCTIONS ---
func initialize(initial_value, max_val):
	"""Sets the initial state of the bar when the game starts."""
	instant_fill.max_value = max_val
	delayed_fill.max_value = max_val
	instant_fill.value = initial_value
	delayed_fill.value = initial_value
	label.text = "%d / %d" % [initial_value, max_val]


func update_bar(current_value, max_val):
	"""Updates the bar instantly and starts the delayed tween during gameplay."""
	# Don't run this logic in the editor
	if Engine.is_editor_hint():
		return
		
	instant_fill.max_value = max_val
	instant_fill.value = current_value
	label.text = "%d / %d" % [current_value, max_val]

	if _current_tween and _current_tween.is_valid():
		_current_tween.kill()

	_current_tween = create_tween()
	_current_tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	_current_tween.tween_property(delayed_fill, "value", current_value, tween_duration).set_delay(tween_delay)
