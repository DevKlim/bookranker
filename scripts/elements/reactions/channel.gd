class_name ReactionChannel
extends RefCounted

static func apply_direct(target: Node, source: Node, units: int, dmg: float) -> bool:
	var base_el = "aqua" 
	var em = target.get_tree().root.get_node_or_null("ElementManager")
	if not em: return false
	
	_trigger_aoe(target, source, dmg, units, base_el)
	return false 

static func _trigger_aoe(target: Node, source: Node, dmg: float, units: int, base_el: String) -> void:
	var em = target.get_tree().root.get_node_or_null("ElementManager")
	if not em: return
	
	# Scale down the chain damage to prevent exponential damage stacking in dense groups
	var chain_dmg = max(dmg * 0.4, 2.0)
	var radius = 1.5 
	var neighbors = em._get_neighbors_in_radius(target, radius)
	if not neighbors.has(target): neighbors.append(target)
	
	for n in neighbors:
		if is_instance_valid(n) and not n.is_queued_for_deletion():
			if n.has_method("take_damage_no_conduct"):
				n.take_damage_no_conduct(chain_dmg, source)
			elif n.has_node("HealthComponent"):
				n.get_node("HealthComponent").take_damage_no_conduct(chain_dmg, source)
			
			if base_el and n != target and is_instance_valid(n) and not n.is_queued_for_deletion():
				var el_res = em.get_element(base_el)
				if el_res:
					# Direct call instead of call_deferred to avoid "Cannot convert argument 1" serialization errors
					em.apply_element(n, el_res, source, 0.0, units, false)
					
	if is_instance_valid(target) and target.is_inside_tree():
		var vfx_name = "channel_aoe_aqua" if base_el == "aqua" else "channel_aoe_magne"
		if em.get_tree().root.has_node("GameManager"):
			var gm = em.get_tree().root.get_node("GameManager")
			if gm.get("vfx_manager"):
				gm.vfx_manager.play_vfx(vfx_name, target.global_position)
