extends RefCounted

static func apply_direct(target: Node, source: Node, units: int, dmg: float) -> bool:
	var total_dmg = dmg * 1.5 + float(units) * 5.0
	if target.has_method("take_damage_no_conduct"):
		target.take_damage_no_conduct(total_dmg, source)
	elif target.has_node("HealthComponent"):
		target.get_node("HealthComponent").take_damage_no_conduct(total_dmg, source)
		
	if target.is_inside_tree():
		var gm = target.get_tree().root.get_node_or_null("GameManager")
		if gm and gm.get("vfx_manager"):
			gm.vfx_manager.play_vfx("plasma_burn", target.global_position)
			
	# Return false so it is added and kept as an aura
	return false