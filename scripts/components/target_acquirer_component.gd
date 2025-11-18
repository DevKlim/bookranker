class_name TargetAcquirerComponent
extends Node

## A component that uses an Area2D to find and track the closest target.
## It is designed for turrets to find enemies.


## Signal emitted when a new target is acquired.
signal target_acquired(target)
## Signal emitted when the current target is lost (e.g., goes out of range or dies).
signal target_lost(last_target)


## The physics layer(s) that this component should consider as valid targets.
## This should be set in the Godot editor.
@export_flags_2d_physics var target_layers

## The current target being tracked.
var current_target: Node2D = null:
	# When the target changes, emit the appropriate signal.
	set(value):
		if current_target != value:
			var old_target = current_target
			current_target = value
			if current_target:
				emit_signal("target_acquired", current_target)
			else:
				emit_signal("target_lost", old_target)

# Reference to the detection_area child node.
@onready var detection_area: Area2D = $DetectionArea


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Ensure the component has a detection area.
	assert(detection_area, "TargetAcquirerComponent requires a child Area2D named 'DetectionArea'.")
	
	# Set the collision mask of the detection area to the specified target layers.
	detection_area.collision_mask = target_layers


## Called every frame. The parameter is prefixed with an underscore
## because it is not used in the function body.
func _process(_delta: float) -> void:
	# If there is a current target, check if it's still valid.
	if current_target:
		# If the target has been freed (e.g., destroyed), lose the target.
		if not is_instance_valid(current_target):
			self.current_target = null
			return
		
		# If the target is no longer overlapping the detection area, lose it.
		if not detection_area.overlaps_body(current_target):
			self.current_target = null
	
	# If there is no current target, try to find a new one.
	if not current_target:
		find_closest_target()


## Scans all bodies within the detection area and sets the closest one as the target.
func find_closest_target() -> void:
	var overlapping_bodies = detection_area.get_overlapping_bodies()
	if overlapping_bodies.is_empty():
		return

	var closest_body: Node2D = null
	var min_distance_sq = INF  # Use squared distance for efficiency (avoids sqrt).
	var parent_pos = get_parent().global_position

	for body in overlapping_bodies:
		var distance_sq = parent_pos.distance_squared_to(body.global_position)
		if distance_sq < min_distance_sq:
			min_distance_sq = distance_sq
			closest_body = body
	
	# If a closest body was found, set it as the new target.
	if closest_body:
		self.current_target = closest_body