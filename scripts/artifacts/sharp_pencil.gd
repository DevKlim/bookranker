extends RefCounted

func on_attack(source: Node, target: Node, item: ItemResource, damage: float) -> void:
	var uses = source.get_meta("sharp_pencil_uses", 64)
	uses -= 1
	source.set_meta("sharp_pencil_uses", uses)
	
	if uses <= 0:
		source.set_meta("sharp_pencil_uses", 64)
		var inv = source.get_node_or_null("InventoryComponent")
		if inv:
			inv.remove_item(item, 1)
			var dull = load("res://resources/items/dull_pencil.tres")
			if dull:
				inv.add_item(dull, 1)
				