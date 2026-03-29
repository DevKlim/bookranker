class_name LootComponent
extends Node

var inventory: InventoryComponent
var has_been_populated: bool = false

func _ready() -> void:
	var parent = get_parent()
	if "display_name" in parent:
		parent.display_name = "Loot"
	
	inventory = parent.get_node_or_null("InventoryComponent")
	if not inventory:
		inventory = parent.get_node_or_null("InputInventory")
		
	if inventory:
		call_deferred("_connect_inventory")

func _connect_inventory() -> void:
	if inventory and not inventory.is_connected("inventory_changed", _on_inventory_changed):
		inventory.inventory_changed.connect(_on_inventory_changed)
	_on_inventory_changed() # Initial check

func _on_inventory_changed() -> void:
	call_deferred("_check_empty")

func _check_empty() -> void:
	if not is_instance_valid(inventory) or not is_instance_valid(get_parent()) or get_parent().is_queued_for_deletion():
		return
		
	if inventory.has_item():
		has_been_populated = true
	elif has_been_populated:
		var parent = get_parent()
		if parent.has_node("GridComponent"):
			var grid_comp = parent.get_node("GridComponent")
			if grid_comp.tile_coord != Vector2i(-1, -1):
				if Engine.has_singleton("LaneManager"):
					LaneManager.unregister_entity(grid_comp.tile_coord, grid_comp.layer)
		parent.queue_free()
