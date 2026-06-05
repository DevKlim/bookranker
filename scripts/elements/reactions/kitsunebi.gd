extends RefCounted

static func apply_direct(target: Node, source: Node, units: int, dmg: float) -> bool:
	var ec = target.get_node_or_null("ElementalComponent")
	if ec:
		ec.remove_status("ghost")
		ec.remove_status("igni")
		
	var networking = 0.0
	if is_instance_valid(source) and source.has_method("get_stat"):
		networking = source.get_stat("networking", 0.0)
		
	var f_dmg = networking + 0.5 * dmg
	
	if target.is_inside_tree():
		var scene = load("res://scenes/particles/kitsunebi_orbs.tscn")
		if scene:
			var inst = scene.instantiate()
			target.get_tree().current_scene.add_child(inst)
			inst.setup(target, source, f_dmg, units)

	return true
