extends RefCounted

static func apply_direct(target: Node, source: Node, units: int, dmg: float) -> bool:
	var lux = 0.0
	if is_instance_valid(source) and source.has_method("get_stat"):
		lux = source.get_stat("networking", 0.0)
		
	var heal_amt = lux + (1.5 * units) + (0.5 * dmg)
	
	if not target.is_inside_tree(): return true
	var tree_root = target.get_tree().root
	var scene_root = target.get_tree().current_scene
	var lm = tree_root.get_node_or_null("LaneManager")
	
	var valid_buildings =[]
	if lm:
		for tile in lm.grid_state.keys():
			var b = lm.grid_state[tile].get("building")
			if is_instance_valid(b) and not b.is_in_group("clutter"):
				valid_buildings.append(b)
				
	valid_buildings.shuffle()
	var targets =[]
	for i in range(min(3, valid_buildings.size())):
		targets.append(valid_buildings[i])
		
	if targets.size() > 0:
		var pixie_scene = load("res://scenes/particles/pixie_trail.tscn")
		if pixie_scene:
			for t in targets:
				var proj = pixie_scene.instantiate()
				scene_root.add_child(proj)
				proj.setup(t, source, heal_amt, target.global_position + Vector3(0, 1.0, 0))
				
	return true
