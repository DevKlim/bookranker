extends RefCounted

static func get_catalysts() -> Array:
	return ["channel"]

static func apply_direct(target: Node, source: Node, units: int, dmg: float) -> bool:
	var ChannelReaction = load("res://scripts/elements/reactions/channel.gd")
	if ChannelReaction:
		ChannelReaction._trigger_aoe(target, source, dmg, units, "aqua")
	return true