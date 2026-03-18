extends ArtifactBase

func on_mine_complete(agent: Node, target: Variant, _item: ItemResource) -> void:
	# 10% chance for a Lucky Strike (Double Yield) when mining ores
	if target is ItemResource and randf() < 0.10:
		var inv: InventoryComponent = null
		
		if agent.is_in_group("player"):
			inv = PlayerManager.game_inventory
		elif agent.has_method("get_node_or_null"):
			inv = agent.get_node_or_null("InventoryComponent")
			
		if inv and inv.has_space_for(target):
			inv.add_item(target, 1)
			
			# Send a notification if the player mined it
			if agent.is_in_group("player"):
				var ui = agent.get_node_or_null("/root/Main/GameUI")
				if ui and ui.has_method("show_notification"):
					ui.show_notification("Lucky Strike! Double yield.", Color(1.0, 0.84, 0.0)) # Gold color
