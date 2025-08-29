@tool
extends Node

class_name Attack

signal editor_frame_changed(frame)

const EditorHitbox = preload("res://scripts/editor/EditorHitbox.gd")

# --- Inspector Tools ---
@export_group("Editor Tools")
@export_range(0, 200, 1, "or_greater") var editor_preview_frame: int = 0:
	set(value):
		if editor_preview_frame == value:
			return
		editor_preview_frame = value
		if Engine.is_editor_hint():
			emit_signal("editor_frame_changed", editor_preview_frame)

@export var add_new_hitbox_node: bool = false:
	set(value):
		if value:
			_add_new_hitbox_node()

@export_group("Combo Properties")
@export var attack_chain: StringName = &"default"
@export var combo_index: int = 1
@export_enum("Grounded", "Aerial", "Running", "Crouching") var required_state: String = "Grounded"
@export_enum("attack1", "attack2") var required_input: String = "attack1"

@export_group("Animation & Timing")
@export var animation_name: StringName
@export var end_lag_duration: float = 0.0
@export var cancel_frame: int = 999
@export var can_turn_around: bool = false
@export var can_directional_cancel: bool = false
@export var directional_cancel_start_frame: int = 0

@export_group("Physics")
@export_enum("None", "Apply Velocity", "Fixed Distance") var movement_type: String = "Apply Velocity"

@export_category("Apply Velocity")
@export var applied_velocity: Vector2 = Vector2.ZERO
@export var applied_velocity_frame: int = 0

@export_category("Fixed Distance")
@export var move_distance: Vector2 = Vector2.ZERO
@export var move_duration: float = 0.2
@export var move_start_frame: int = 0


# --- Editor Tool Logic ---

func _add_new_hitbox_node():
	if not Engine.is_editor_hint():
		return
	
	var new_hitbox = EditorHitbox.new()
	add_child(new_hitbox)
	
	# Set the owner so it gets saved with the scene. This is vital.
	new_hitbox.owner = get_tree().edited_scene_root