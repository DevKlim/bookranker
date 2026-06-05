extends RefCounted

static func execute(target: Node, source: Node, ctx: Dictionary) -> void:
	var units = ctx.get("reaction_units", 1)
	var source_dmg = ctx.get("damage", 0.0)
	var aqua_units_before = ctx.get("aqua_units_before", 0)
	
	var networking = 0.0
	if is_instance_valid(source) and source.has_method("get_stat"):
		networking = source.get_stat("networking", 0.0)
		
	var f_dmg = 1.0 + (0.1 * units * (source_dmg + aqua_units_before) * networking)
	
	if target.has_method("take_damage_no_conduct"):
		target.take_damage_no_conduct(f_dmg, source)
	elif target.has_node("HealthComponent"):
		target.get_node("HealthComponent").take_damage_no_conduct(f_dmg, source)
			
	var ec = target.get_node_or_null("ElementalComponent")
	# Add the steam visual statically, ElementalComponent will manage removing it seamlessly
	if ec and not target.has_node("BoilSteam"):
		var steam = load("res://scenes/particles/boil_steam.tscn")
		if steam:
			var steam_inst = steam.instantiate()
			steam_inst.name = "BoilSteam"
			target.add_child(steam_inst)
			steam_inst.position = Vector3(0, 1, 0)

static func apply_direct(target: Node, source: Node, units: int) -> bool:
	execute(target, source, {"reaction_units": units, "damage": 10.0, "aqua_units_before": 0})
	return false # Return false to ensure the Status and UI Icon are still registered natively
