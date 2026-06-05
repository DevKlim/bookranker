extends RefCounted

static func get_catalysts() -> Array:
	return ["plasma"]

static func apply_direct(target: Node, source: Node, units: int, dmg: float) -> bool:
	var lux = 0.0
	if is_instance_valid(source) and source.has_method("get_stat"):
		lux = source.get_stat("networking", 0.0)
		
	var buff = min(units + 1.0, 10.0 * max(1.0, lux)) * 0.3 + (lux * 0.1)
	var total_dmg = dmg + buff

	if target.has_method("take_damage_no_conduct"):
		target.take_damage_no_conduct(total_dmg, source)
	elif target.has_node("HealthComponent"):
		target.get_node("HealthComponent").take_damage_no_conduct(total_dmg, source)

	if target.is_inside_tree():
		var gm = target.get_tree().root.get_node_or_null("GameManager")
		if gm and gm.get("vfx_manager"):
			gm.vfx_manager.play_vfx("ionize_pins", target.global_position)

	return true
