extends RefCounted

static func execute(target: Node, source: Node, ctx: Dictionary) -> void:
	var units = ctx.get("reaction_units", 1)
	
	var ec = target.get_node_or_null("ElementalComponent")
	if ec:
		ec.remove_status("ghost")
		ec.remove_status("aqua")
		
	if target.has_node("UndineComponent"):
		var existing = target.get_node("UndineComponent")
		existing.reset_duration()
		return
		
	var undine = load("res://scripts/components/undine_component.gd").new()
	target.add_child(undine)
	undine.setup(target, source)

static func apply_direct(target: Node, source: Node, units: int) -> bool:
	execute(target, source, {"reaction_units": units})
	return true
