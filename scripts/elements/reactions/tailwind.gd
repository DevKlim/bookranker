extends RefCounted

static func apply_direct(target: Node, source: Node, units: int, dmg: float) -> bool:
	var networking = 0.0
	var speed = 0.0
	if is_instance_valid(source) and source.has_method("get_stat"):
		networking = source.get_stat("networking", 0.0)
		speed = source.get_stat("speed", 0.0)
		
	var f_dmg = 1.0 + (0.25 * networking) + (0.2 * speed)
	
	var em = target.get_tree().root.get_node_or_null("ElementManager")
	if not em: return true

	# Fetch enemies far behind the current target to blow damage/element into
	var behind_enemies = em.get_closest_enemies_behind(target, 10) 
	
	for e in behind_enemies:
		if is_instance_valid(e):
			if e.has_method("take_damage_no_conduct"):
				e.take_damage_no_conduct(f_dmg, source)
			elif e.has_node("HealthComponent"):
				e.get_node("HealthComponent").take_damage_no_conduct(f_dmg, source)
			
			var primary_id = "igni" # fallback
			var ec = target.get_node_or_null("ElementalComponent")
			if ec:
				if ec.has_element("igni"): primary_id = "igni"
				elif ec.has_element("aqua"): primary_id = "aqua"
				elif ec.has_element("volt"): primary_id = "volt"
				
			var el_res = em.get_element(primary_id)
			if el_res:
				em.call_deferred("apply_element", e, el_res, source, 0.0, 1, false)
				
	if target.is_inside_tree() and em.get_tree().root.has_node("GameManager"):
		var gm = em.get_tree().root.get_node("GameManager")
		if gm.get("vfx_manager"):
			gm.vfx_manager.play_vfx("tailwind", target.global_position)
			
	return true
