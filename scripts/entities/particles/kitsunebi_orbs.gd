class_name KitsunebiOrbs
extends Node3D

var target: Node
var source: Node
var damage: float
var units: int
var _loops: float = 0.0
var _speed: float = PI * 2.0 

var _hit_enemies: Dictionary = {}

func setup(p_target: Node, p_source: Node, p_dmg: float, p_units: int) -> void:
	target = p_target
	source = p_source
	damage = p_dmg
	units = p_units
	if is_instance_valid(target):
		global_position = target.global_position

func _process(delta: float) -> void:
	if not is_instance_valid(target) or target.get("is_dead"):
		queue_free()
		return
		
	global_position = target.global_position
	rotation.y += _speed * delta
	_loops += (_speed * delta) / (PI * 2.0)
	
	if _loops >= 2.0:
		queue_free()

func _on_area_entered(body: Node3D) -> void:
	if body == target: return
	if body.is_in_group("loot_buildings"): return
	
	var valid = false
	if body.is_in_group("enemies"): valid = true
	
	if not valid: return
	if _hit_enemies.has(body): return
	_hit_enemies[body] = true
	
	var safe_source = source if is_instance_valid(source) else null
	if body.has_method("take_damage_no_conduct"):
		body.take_damage_no_conduct(damage, safe_source)
	elif body.has_node("HealthComponent"):
		body.get_node("HealthComponent").take_damage_no_conduct(damage, safe_source)
		
	var em = get_tree().root.get_node_or_null("ElementManager")
	var ec = body.get_node_or_null("ElementalComponent")
	if em and ec:
		var ghost = em.get_element("ghost")
		if ghost:
			# Only add as aura, don't cascade the ghost reaction pop
			ec.add_or_refresh_status(ghost, units)
