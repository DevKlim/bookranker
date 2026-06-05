extends RefCounted

static func execute(target: Node, source: Node, ctx: Dictionary) -> void:
	var id1 = ctx.get("id_a", "")
	var id2 = ctx.get("id_b", "")
	
	var ec = target.get_node_or_null("ElementalComponent")
	if ec: 
		ec.remove_status("ghost")
		if ec.has_element("dew"): ec.remove_status("dew")
		elif ec.has_element("rain"): ec.remove_status("rain")
		
	var tile = target.get_tree().root.get_node("LaneManager").world_to_tile(target.global_position)
	var lm = target.get_tree().root.get_node("LaneManager")
	
	var dew = lm.get_node_or_null("DewArea_" + str(tile.x) + "_" + str(tile.y))
	if dew: dew.queue_free()
	var rain = lm.get_node_or_null("RainArea_" + str(tile.x) + "_" + str(tile.y))
	if rain: rain.queue_free()
	
	var area_name = "EctomistArea_" + str(tile.x) + "_" + str(tile.y)
	if lm.has_node(area_name):
		return
		
	var ecto = load("res://scripts/elements/areas/ectomist_area.gd").new()
	ecto.name = area_name
	lm.add_child(ecto)
	ecto.setup(tile, source)

static func apply_direct(target: Node, source: Node, units: int) -> bool:
	execute(target, source, {"reaction_units": units})
	return true
