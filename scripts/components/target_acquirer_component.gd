class_name TargetAcquirerComponent
extends Node

## A component that uses an Area3D to find and track the closest target.

signal target_acquired(target)
signal target_lost(last_target)

@export_flags_3d_physics var target_layers

var current_target: Node3D = null:
	set(value):
		if current_target != value:
			var old_target = current_target
			current_target = value
			if current_target:
				emit_signal("target_acquired", current_target)
			else:
				emit_signal("target_lost", old_target)

@onready var detection_area: Area3D = $DetectionArea
var validation_callback: Callable = Callable()

func _ready() -> void:
	assert(detection_area, "TargetAcquirerComponent requires a child Area3D named 'DetectionArea'.")
	detection_area.collision_mask = target_layers

func _process(_delta: float) -> void:
	if current_target:
		if not is_instance_valid(current_target):
			self.current_target = null
			return
		if not detection_area.overlaps_body(current_target):
			self.current_target = null
	
	if not current_target:
		find_closest_target()

func find_closest_target() -> void:
	var overlapping_bodies = detection_area.get_overlapping_bodies()
	if overlapping_bodies.is_empty():
		return

	var closest_body: Node3D = null
	var min_distance_sq = INF
	var parent_pos = get_parent().global_position

	for body in overlapping_bodies:
		if validation_callback.is_valid() and not validation_callback.call(body):
			continue

		var distance_sq = parent_pos.distance_squared_to(body.global_position)
		if distance_sq < min_distance_sq:
			min_distance_sq = distance_sq
			closest_body = body
	
	if closest_body:
		self.current_target = closest_body
