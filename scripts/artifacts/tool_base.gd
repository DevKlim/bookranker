class_name ToolBase
extends ArtifactBase

## Inheritable base script for all actionable tools. Handles standard default logic.

func get_valid_target(agent: Node, tool_item: ItemResource) -> Dictionary:
	var tile = LaneManager.world_to_tile(agent.global_position)
	
	# Priority 1: Clutter (All tools can clear clutter by default)
	var clutter = LaneManager.get_entity_at(tile, "building")
	if clutter is ClutterObject:
		return { "target": clutter, "type": "clutter", "tile": tile }
		
	return {}

func process_mine_completion(agent: Node, target_data: Dictionary, tool_item: ItemResource) -> bool:
	var inv = _get_inventory(agent)
	if not inv: return false
	
	# Default Clutter Resolution
	if target_data.type == "clutter":
		var clutter = target_data.target as ClutterObject
		if is_instance_valid(clutter):
			clutter.take_damage(9999.0)
		return true
		
	return false

func can_mine_tile(tile: Vector2i) -> bool:
	# Base check allows highlighting of clutter
	var clutter = LaneManager.get_entity_at(tile, "building")
	if clutter is ClutterObject:
		return true
	return false

func _get_inventory(agent: Node) -> InventoryComponent:
	if agent.has_method("get_node_or_null"):
		return agent.get_node_or_null("InventoryComponent")
	return null

