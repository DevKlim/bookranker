extends RefCounted

static func execute(target: Node, source: Node, ctx: Dictionary) -> void:
	var reaction_dmg = ctx.get("reaction_damage", 50.0)
	
	var ec = target.get_node_or_null("ElementalComponent")
	if ec: ec.remove_all_statuses()
	
	if target.is_inside_tree() and target.get_tree().root.has_node("ElementManager"):
		var em = target.get_tree().root.get_node("ElementManager")
		em.apply_aoe_damage(target, 2.5, max(50.0, reaction_dmg), source, false, 300.0)
		
		var gm = target.get_tree().root.get_node_or_null("GameManager")
		if gm and gm.get("vfx_manager"):
			gm.vfx_manager.play_vfx("fuse", target.global_position)

static func apply_direct(target: Node, source: Node, _units: int) -> bool:
	var dmg = 50.0
	var ec = target.get_node_or_null("ElementalComponent")
	if ec: ec.remove_all_statuses()
	
	if target.is_inside_tree() and target.get_tree().root.has_node("ElementManager"):
		var em = target.get_tree().root.get_node("ElementManager")
		em.apply_aoe_damage(target, 2.5, dmg, source, false, 300.0)
		
		var gm = target.get_tree().root.get_node_or_null("GameManager")
		if gm and gm.get("vfx_manager"):
			gm.vfx_manager.play_vfx("fuse", target.global_position)
	return true