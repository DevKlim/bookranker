extends Node
class_name AnimationComponent

@export_group("Core Movement")
@export var idle: StringName = &"Idle"
@export var walk: StringName = &"Walk"
@export var run: StringName = &"Sprint"
@export var crouch_idle: StringName = &"Crouch_Idle"
@export var crouch_walk: StringName = &"Crouch_Walk"
@export var running_slide: StringName = &"Slide"

@export_group("Jumping & Falling")
@export var jump_start: StringName = &"Jump_Start"
@export var sprint_jump_start: StringName = &"Air_Spin"
@export var fall: StringName = &"Fall"
@export var land: StringName = &"Land"

@export_group("Environment Interaction")
@export var ledge_grab: StringName = &"Ledge_Climb"

@export_group("Recovery & Damage")
@export var get_up: StringName # No default animation yet
@export var get_up_attack: StringName # No default animation yet
@export var hurt: StringName = &"Hurt"
@export var death: StringName = &"Death"