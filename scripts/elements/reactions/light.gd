extends RefCounted

static func apply_direct(target: Node, source: Node, units: int, dmg: float) -> bool:
	var lux = 0.0
	if is_instance_valid(source) and source.has_method("get_stat"):
		lux = source.get_stat("networking", 0.0)
			
	var miss_chance = (lux + 25.0) / 5.0
	target.set_meta("light_miss_chance", miss_chance)
	
	if target.is_inside_tree():
		var gm = target.get_tree().root.get_node_or_null("GameManager")
		if gm and gm.get("vfx_manager"):
			gm.vfx_manager.play_vfx("light_glow", target.global_position)
	
	return false # False allows it to append as an aura after direct evaluation.
