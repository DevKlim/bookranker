extends RefCounted

static func apply_direct(target: Node, source: Node, units: int, dmg: float) -> bool:
	var networking = 0.0
	if is_instance_valid(source) and source.has_method("get_stat"):
		networking = source.get_stat("networking", 0.0)
		
	var f_dmg = (units * networking) + 2.0
			
	if not target.is_inside_tree(): return false
	var scene_root = target.get_tree().current_scene
	var tree_root = target.get_tree().root

	var poof_scene = load("res://scenes/particles/ghost.tscn")
	if poof_scene:
		var poof = poof_scene.instantiate()
		scene_root.add_child(poof)
		poof.global_position = target.global_position
	
	var valid_enemies: Array[Node] =[]
	var lm = tree_root.get_node_or_null("LaneManager")
	if lm:
		for lane_array in lm.enemies_by_lane.values():
			for e in lane_array:
				if is_instance_valid(e) and e != target and not e.get("is_dead"):
					valid_enemies.append(e)
					
	if valid_enemies.is_empty():
		var all_enemies = target.get_tree().get_nodes_in_group("enemies")
		for e in all_enemies:
			if is_instance_valid(e) and e != target and not e.get("is_dead"):
				valid_enemies.append(e)
				
	valid_enemies.shuffle()
	var targets: Array[Node] =[]
	for i in range(min(3, valid_enemies.size())):
		targets.append(valid_enemies[i])
		
	if targets.size() > 0:
		var proj_scene = load("res://scenes/particles/ghost_trail.tscn")
		if proj_scene:
			for t in targets:
				var proj = proj_scene.instantiate()
				scene_root.add_child(proj)
				proj.setup(t, source, f_dmg, units, target.global_position + Vector3(0, 1.0, 0))

	return false
