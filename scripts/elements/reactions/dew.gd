extends RefCounted

static func execute(target: Node, source: Node, ctx: Dictionary) -> void:
	var units = ctx.get("reaction_units", 1)
	
	var ec = target.get_node_or_null("ElementalComponent")
	if ec:
		ec.remove_status("aero")
		ec.remove_status("boil")
		
	var tile = target.get_tree().root.get_node("LaneManager").world_to_tile(target.global_position)
	var lm = target.get_tree().root.get_node("LaneManager")
	
	var dew_node = lm.get_node_or_null("DewArea_" + str(tile.x) + "_" + str(tile.y))
	if dew_node:
		var boil_units = 0
		if ec and ec.has_element("boil"): boil_units = ec.get_active_data("boil").units
		
		var networking = 0.0
		if is_instance_valid(source) and source.has_method("get_stat"):
			networking = source.get_stat("networking", 0.0)
			
		var reaction_dmg = 1.0 + boil_units + (0.5 * networking)
		var safe_source = source if is_instance_valid(source) else null
		
		if target.has_method("take_damage_no_conduct"):
			target.take_damage_no_conduct(reaction_dmg, safe_source)
		elif target.has_node("HealthComponent"):
			target.get_node("HealthComponent").take_damage_no_conduct(reaction_dmg, safe_source)
			
		if target.has_node("HealthComponent"):
			target.get_node("HealthComponent").stagger(0.5)
			
		dew_node.refresh(10.0)
	else:
		var scene = load("res://scenes/particles/dew_area.tscn")
		if scene:
			var dew = scene.instantiate()
			dew.name = "DewArea_" + str(tile.x) + "_" + str(tile.y)
			lm.add_child(dew)
			dew.setup(tile, 10.0, source)

static func apply_direct(target: Node, source: Node, units: int) -> bool:
	execute(target, source, {"reaction_units": units})
	return true
