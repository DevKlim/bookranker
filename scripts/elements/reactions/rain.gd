extends RefCounted

static func execute(target: Node, source: Node, ctx: Dictionary) -> void:
	var ec = target.get_node_or_null("ElementalComponent")
	if ec: ec.remove_status("dew")
		
	var tile = target.get_tree().root.get_node("LaneManager").world_to_tile(target.global_position)
	var lm = target.get_tree().root.get_node("LaneManager")
	
	var rain_node = lm.get_node_or_null("RainArea_" + str(tile.x) + "_" + str(tile.y))
	if rain_node:
		rain_node.refresh(30.0)
	else:
		var dew = lm.get_node_or_null("DewArea_" + str(tile.x) + "_" + str(tile.y))
		if dew: dew.queue_free()
			
		var rain = load("res://scripts/elements/areas/rain_area.gd").new()
		rain.name = "RainArea_" + str(tile.x) + "_" + str(tile.y)
		lm.add_child(rain)
		rain.setup(tile, 30.0, source)

static func apply_direct(target: Node, source: Node, units: int) -> bool:
	execute(target, source, {"reaction_units": units})
	return true
