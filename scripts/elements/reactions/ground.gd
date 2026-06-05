extends RefCounted

static func execute(target: Node, _source: Node, _ctx: Dictionary) -> void:
	var ec = target.get_node_or_null("ElementalComponent")
	if ec:
		ec.remove_status("volt")

static func apply_direct(target: Node, source: Node, units: int) -> bool:
	execute(target, source, {"reaction_units": units})
	return true