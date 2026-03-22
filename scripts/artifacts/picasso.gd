extends RefCounted

func modify_cooldown(base_cd: float, source: Node, attack: AttackResource) -> float:
	var inv = source.get_node_or_null("InventoryComponent")
	if not inv: return base_cd
	
	var ink_res = load("res://resources/items/ink.tres")
	if not ink_res: return base_cd
	
	var ink_count = 0
	for slot in inv.slots:
		if slot and slot.item == ink_res:
			ink_count += slot.count
			
	var n = min(ink_count, randi_range(1, 9))
	source.set_meta("picasso_n", n)
	
	if n > 0:
		return 1.0 + (n * 0.5)
	return base_cd

func modify_damage(base_damage: float, source: Node, attack: AttackResource) -> float:
	var n = source.get_meta("picasso_n", 0)
	if n > 0:
		var inv = source.get_node_or_null("InventoryComponent")
		var ink_res = load("res://resources/items/ink.tres")
		if inv and ink_res:
			inv.remove_item(ink_res, n)
		source.set_meta("picasso_n", 0)
		return float(n)
	return base_damage