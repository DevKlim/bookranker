class_name GhostTrail
extends Node3D

enum FlyState { ASCEND, CRUISE, HOVER, DIVE }

var target: Node
var source: Node
var damage: float
var units: int
var speed: float = 12.0

var current_state: FlyState = FlyState.ASCEND
var start_pos: Vector3
var hover_timer: float = 0.3

func setup(p_target: Node, p_source: Node, p_dmg: float, p_units: int, p_start_pos: Vector3) -> void:
	target = p_target
	source = p_source
	damage = p_dmg
	units = p_units
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
			# Fly up high into the skies
			dest_pos = start_pos + Vector3(0, 6.0, 0)
			current_speed = speed * 0.8
			if global_position.y >= dest_pos.y - 0.2:
				current_state = FlyState.CRUISE
				
		FlyState.CRUISE:
			# Move across the sky to the target's XZ location
			dest_pos = target.global_position + Vector3(0, 6.0, 0)
			var flat_pos = Vector2(global_position.x, global_position.z)
			var flat_dest = Vector2(dest_pos.x, dest_pos.z)
			if flat_pos.distance_squared_to(flat_dest) < 0.5:
				current_state = FlyState.HOVER
				
		FlyState.HOVER:
			# Briefly float above the target, tracking its movement slightly
			dest_pos = target.global_position + Vector3(0, 6.0, 0)
			current_speed = speed * 0.5 
			hover_timer -= delta
			if hover_timer <= 0:
				current_state = FlyState.DIVE
				
		FlyState.DIVE:
			# Plunge straight down into the target
			dest_pos = target.global_position + Vector3(0, 1.0, 0)
			current_speed = speed * 2.5
			if global_position.distance_squared_to(dest_pos) < 0.5:
				_hit_target()
				return
				
	if current_speed > 0:
		var dir = (dest_pos - global_position).normalized()
		global_position += dir * current_speed * delta

func _hit_target() -> void:
	var safe_source = source if is_instance_valid(source) else null
	if target.has_method("take_damage_no_conduct"):
		target.take_damage_no_conduct(damage, safe_source)
	elif target.has_node("HealthComponent"):
		target.get_node("HealthComponent").take_damage_no_conduct(damage, safe_source)
		
	var ec = target.get_node_or_null("ElementalComponent")
	var em = get_tree().root.get_node_or_null("ElementManager")
	if ec and em:
		var ghost = em.get_element("ghost")
		if ghost:
			# Directly add the status to bypass the ElementManager popping the reaction again
			ec.add_or_refresh_status(ghost, units)
			
	queue_free()
