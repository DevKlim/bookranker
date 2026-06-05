extends RefCounted

static func apply_direct(target: Node, source: Node, units: int, dmg: float) -> bool:
	var lux = 0.0
	if is_instance_valid(source) and source.has_method("get_stat"):
		lux = source.get_stat("networking", 0.0)
		
	var heal_amt = lux + (2.0 * units) + dmg

	if target.has_method("heal"):
		target.heal(heal_amt)
	elif target.has_node("HealthComponent"):
		target.get_node("HealthComponent").heal(heal_amt)
		
	if target.is_inside_tree():
		var gm = target.get_tree().root.get_node_or_null("GameManager")
		if gm and gm.get("vfx_manager"):
			gm.vfx_manager.play_vfx("aether_heal", target.global_position)

	return true
