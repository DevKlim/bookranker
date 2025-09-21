@tool
extends Node

class_name Attack

signal editor_frame_changed(frame)

# --- Inspector Tools ---
@export_group("Editor Tools")
@export_range(0, 200, 1, "or_greater") var editor_preview_frame: int = 0:
	set(value):
		if editor_preview_frame == value:
			return
		editor_preview_frame = value
		if Engine.is_editor_hint():
			emit_signal("editor_frame_changed", editor_preview_frame)

@export_group("Attack Type")
@export_enum("Combo", "Skill") var attack_type: String = "Combo"
## If true, each hitbox can hit a target once. If false, hitting with any hitbox prevents other hitboxes in this attack from hitting the same target.
@export var multi_hit: bool = false
## For Skills, the base input action (e.g., "skill1", "skill2") that triggers it.
@export var skill_input_action: String = ""
## For Skills, path to the icon displayed on the UI.
@export_file("*.png", "*.svg") var icon_path: String = ""


@export_group("Combo Properties")
@export var attack_chain: StringName = &"default"
@export var combo_index: int = 1
## Check for states. Use '&' for AND. e.g., "Grounded", "Aerial", "Sprint&Jump". Case-sensitive.
@export var required_state: String = "Grounded"
@export_enum("attack1", "attack2") var required_input: String = "attack1"

@export_group("Costs & Cooldown")
@export var mana_cost: float = 0.0
@export var hp_cost: float = 0.0
@export var cooldown: float = 0.0 # Cooldown duration in seconds

@export_group("Animation & Timing")
@export var animation_name: StringName
@export var hitboxes: Array[HitboxData]
@export var end_lag_duration: float = 0.0
@export var cancel_frame: int = 999
@export var can_turn_around: bool = false
@export var can_directional_cancel: bool = false
@export var directional_cancel_start_frame: int = 0

@export_group("Invincibility")
## Frame on which invincibility starts (inclusive). Set to -1 to disable.
@export var invincibility_start_frame: int = -1
## Frame on which invincibility ends (exclusive). Set to -1 to disable.
@export var invincibility_end_frame: int = -1

@export_group("Physics")
@export_enum("None", "Apply Velocity", "Fixed Distance") var movement_type: String = "Apply Velocity"
## If true and this is an aerial attack, the player will enter an uncontrollable free-fall state until they land.
@export var enter_free_fall: bool = false

@export_category("Apply Velocity")
@export var applied_velocity: Vector2 = Vector2.ZERO
@export var applied_velocity_frame: int = 0

@export_category("Fixed Distance")
@export var move_distance: Vector2 = Vector2.ZERO
@export var move_duration: float = 0.2
@export var move_start_frame: int = 0