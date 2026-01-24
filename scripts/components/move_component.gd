class_name MoveComponent
extends Node

## A component that handles movement for a CharacterBody3D parent.

@export var move_speed: float = 5.0
# Reduced default stop distance to allow precise arrival
@export var stop_distance: float = 0.02

var target_position: Vector3
var _body: CharacterBody3D

func _ready() -> void:
	_body = get_parent()
	assert(_body is CharacterBody3D, "MoveComponent must be a child of a CharacterBody3D.")
	target_position = _body.global_position

func _physics_process(_delta: float) -> void:
	var dist = _body.global_position.distance_to(target_position)
	
	if dist < stop_distance:
		_body.velocity = Vector3.ZERO
		return
	
	var direction = (_body.global_position.direction_to(target_position)).normalized()
	_body.velocity = direction * move_speed
	_body.move_and_slide()
