class_name PixieTrail
extends Node3D

enum FlyState { ASCEND, CRUISE, HOVER, DIVE }

var target: Node
var source: Node
var heal_amount: float
var speed: float = 14.0

var current_state: FlyState = FlyState.ASCEND
var start_pos: Vector3
var hover_timer: float = 0.2

func setup(p_target: Node, p_source: Node, p_heal_amount: float, p_start_pos: Vector3) -> void:
	target = p_target
	source = p_source
	heal_amount = p_heal_amount
	start_pos = p_start_pos
	global_position = start_pos
	
func _process(delta: float) -> void:
	if not is_instance_valid(target) or target.get("is_dead"):
		queue_free()
		return
		
	var dest_pos = Vector3.ZERO
	var current_speed = speed
	
	match current_state:
		FlyState.ASCEND:
			dest_pos = start_pos + Vector3(0, 5.0, 0)
			current_speed = speed * 0.8
			if global_position.y >= dest_pos.y - 0.2:
				current_state = FlyState.CRUISE
				
		FlyState.CRUISE:
			dest_pos = target.global_position + Vector3(0, 5.0, 0)
			var flat_pos = Vector2(global_position.x, global_position.z)
			var flat_dest = Vector2(dest_pos.x, dest_pos.z)
			if flat_pos.distance_squared_to(flat_dest) < 0.5:
				current_state = FlyState.HOVER
				
		FlyState.HOVER:
			dest_pos = target.global_position + Vector3(0, 5.0, 0)
			current_speed = speed * 0.5 
			hover_timer -= delta
			if hover_timer <= 0:
				current_state = FlyState.DIVE
				
		FlyState.DIVE:
			dest_pos = target.global_position + Vector3(0, 1.0, 0)
			current_speed = speed * 2.5
			if global_position.distance_squared_to(dest_pos) < 0.5:
				_heal_target()
				return
				
	if current_speed > 0:
		var dir = (dest_pos - global_position).normalized()
		global_position += dir * current_speed * delta

func _heal_target() -> void:
	if target.has_method("heal"):
		target.heal(heal_amount)
	elif target.has_node("HealthComponent"):
		target.get_node("HealthComponent").heal(heal_amount)
		
	queue_free()
