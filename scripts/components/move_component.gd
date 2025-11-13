class_name MoveComponent
extends Node

## A component that handles movement for a CharacterBody2D parent.
## It moves the parent towards a specified target position.


## The speed at which the entity moves, in pixels per second.
@export var move_speed: float = 100.0

## The target position the entity will move towards.
var target_position: Vector2

# A reference to the parent CharacterBody2D.
var _body: CharacterBody2D


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Get the parent node and ensure it's a CharacterBody2D.
	_body = get_parent()
	assert(_body is CharacterBody2D, "MoveComponent must be a child of a CharacterBody2D.")
	
	# Initially, the target is its own position so it doesn't move.
	target_position = _body.global_position


## Called every physics frame. The parameter is prefixed with an underscore
## because it is not used in the function body.
func _physics_process(_delta: float) -> void:
	# If the body is very close to the target, stop moving.
	if _body.global_position.distance_to(target_position) < 5.0:
		_body.velocity = Vector2.ZERO
		return
	
	# Calculate the direction towards the target.
	var direction = (_body.global_position.direction_to(target_position)).normalized()
	
	# Set the velocity to move in that direction at the defined speed.
	_body.velocity = direction * move_speed
	
	# move_and_slide() is a built-in CharacterBody2D function that handles movement and collisions.
	_body.move_and_slide()

