class_name ArtifactBase
extends RefCounted

func on_equip(agent: Node, item: ItemResource) -> void:
	pass

func on_unequip(agent: Node, item: ItemResource) -> void:
	pass

func on_use(agent: Node, target: Node, item: ItemResource) -> void:
	pass

func on_attack(agent: Node, target: Node, item: ItemResource, damage: float) -> void:
	pass

func on_mine_complete(agent: Node, target: Variant, item: ItemResource) -> void:
	pass

func on_right_click(item: ItemResource, parent_ui: Control) -> void:
	pass

# --- Tool Specific Virtuals ---

## Returns a Dictionary detailing the target, type, and tile if valid.
func get_valid_target(agent: Node, tool_item: ItemResource) -> Dictionary:
	return {}

## Executes the logic for when a mining action completes. Return true if fully handled.
func process_mine_completion(agent: Node, target_data: Dictionary, tool_item: ItemResource) -> bool:
	return false

## Used for grid highlighting by controllers.
func can_mine_tile(tile: Vector2i) -> bool:
	return false
