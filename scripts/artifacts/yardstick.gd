extends RefCounted

func on_attack(source: Node, target: Node, item: ItemResource, damage: float) -> void:
	# Use metadata on the source since artifact instance is cached per item type, not per instance
	var uses = source.get_meta("yardstick_uses", 52)
	uses -= 1
	source.set_meta("yardstick_uses", uses)
	
	if uses <= 0:
		source.set_meta("yardstick_uses", 52) # Reset for the next one
		var inv = source.get_node_or_null("InventoryComponent")
		if inv:
			inv.remove_item(item, 1)
			