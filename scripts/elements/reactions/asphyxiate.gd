extends RefCounted

static func execute(target: Node, source: Node, ctx: Dictionary) -> void:
	var real_target = target
	var shell = null
	if target is AbyssShellComponent:
		shell = target
		real_target = target.target
	else:
		shell = target.get_node_or_null("AbyssShell")
        
	var ec = real_target.get_node_or_null("ElementalComponent")
	var fog_units = 0
	if ec and ec.has_element("fog"):
		fog_units = ec.get_active_data("fog").units
		ec.remove_status("fog")
		
	var tile = real_target.get_tree().root.get_node("LaneManager").world_to_tile(real_target.global_position)
	var lm = real_target.get_tree().root.get_node("LaneManager")
	
	var dews_consumed = 0
	for x in range(-2, 3):
		for y in range(-2, 3):
			var t = tile + Vector2i(x, y)
			var dew = lm.get_node_or_null("DewArea_" + str(t.x) + "_" + str(t.y))
			if dew:
				dews_consumed += 1
				dew.queue_free()
				
	var total_consumed = fog_units + dews_consumed
	var dmg = 1.0 + (2.0 * total_consumed)
	
	var networking = 1.0
	if is_instance_valid(source) and source.has_method("get_stat"):
		networking = max(0.1, source.get_stat("networking", 1.0))
		
	var tick_rate = min(3.0, 15.0 / networking)
	
	if shell:
		if shell.has_meta("asphyxiate_dmg"):
			shell.set_meta("asphyxiate_dmg", shell.get_meta("asphyxiate_dmg") + 1.0)
		else:
			shell.set_meta("asphyxiate_dmg", dmg)
			shell.set_meta("asphyxiate_tick_rate", tick_rate)
			shell.set_meta("asphyxiate_timer", tick_rate)
			
	if real_target.is_inside_tree() and real_target.get_tree().root.has_node("GameManager"):
		var gm = real_target.get_tree().root.get_node("GameManager")
		if gm.get("vfx_manager"):
			gm.vfx_manager.play_vfx("asphyxiate_spike", real_target.global_position)

static func apply_direct(target: Node, source: Node, units: int) -> bool:
	execute(target, source, {"reaction_units": units})
	return true
