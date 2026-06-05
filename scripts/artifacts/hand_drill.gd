extends ToolBase

func get_valid_target(agent: Node, tool_item: ItemResource) -> Dictionary:
	# Always let the base tool resolve generic targets (like Clutter) first.
	var base_target = super.get_valid_target(agent, tool_item)
	if not base_target.is_empty():
		return base_target
		
	var tile = LaneManager.world_to_tile(agent.global_position)
	var tile_world = LaneManager.tile_to_world(tile)
	
	# Priority 2: Ore (Drill Specific)
	var ore = LaneManager.get_ore_at_world_pos(tile_world)
	if ore:
		return { "target": ore, "type": "ore", "tile": tile }
		
	# Priority 3: Ground / Floor tiles (Drill Specific)
	if LaneManager.grid_map:
		var cell_pos = Vector3i(tile.x, 0, tile.y)
		var block_id = LaneManager.grid_map.get_cell_item(cell_pos)
		if block_id != GridMap.INVALID_CELL_ITEM and LaneManager.block_id_to_item_map.has(block_id):
			return { "target": LaneManager.block_id_to_item_map[block_id], "type": "ground", "tile": tile }
			
	return {}

func process_mine_completion(agent: Node, target_data: Dictionary, tool_item: ItemResource) -> bool:
	# Defer to base for defaults like clutter
	if super.process_mine_completion(agent, target_data, tool_item):
		return true
		
	var inv = _get_inventory(agent)
	if not inv: return false
	
	if target_data.type == "ore" or target_data.type == "ground":
		var target_item = target_data.target as ItemResource
		
		# Drill Specific Mod: 10% chance for a Lucky Strike (Double Yield) when mining
		var count = 1
		if target_data.type == "ore" and randf() < 0.10:
			count = 2
			if agent.is_in_group("player"):
				var ui = agent.get_node_or_null("/root/Main/GameUI")
				if ui and ui.has_method("show_notification"):
					ui.show_notification("Lucky Strike! Double yield.", Color(1.0, 0.84, 0.0))
		
		if inv.has_space_for(target_item):
			for i in range(count):
				inv.add_item(target_item, 1)
			var tile = target_data.get("tile", LaneManager.world_to_tile(agent.global_position))
			LaneManager.consume_ore_at(tile)
		elif agent.is_in_group("player"):
			var ui = agent.get_node_or_null("/root/Main/GameUI")
			if ui and ui.has_method("show_notification"):
				ui.show_notification("Inventory Full!", Color.RED)
		return true
		
	return false

func can_mine_tile(tile: Vector2i) -> bool:
	if super.can_mine_tile(tile): return true
	
	var tile_world = LaneManager.tile_to_world(tile)
	if LaneManager.get_ore_at_world_pos(tile_world):
		return true
		
	if LaneManager.grid_map:
		var cell_pos = Vector3i(tile.x, 0, tile.y)
		var block_id = LaneManager.grid_map.get_cell_item(cell_pos)
		if block_id != GridMap.INVALID_CELL_ITEM and LaneManager.block_id_to_item_map.has(block_id):
			return true
			
	return false
