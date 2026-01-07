class_name InventoryComponent
extends Node

## Inventory that holds items, with optional filtering and I/O configuration.

signal inventory_changed

@export var max_slots: int = 1
@export var slot_capacity: int = 50

@export_group("Permissions")
## If true, items can be inserted into this inventory by external systems (conveyors, etc).
@export var can_receive: bool = true
## If true, items can be extracted from this inventory by external systems.
@export var can_output: bool = true
## If true, this inventory ignores directional logic (accepts/outputs from any side).
@export var omni_directional: bool = false

@export_group("Filters")
## If not empty, ONLY items in this list can be added (Whitelist).
@export var allowed_items: Array[Resource] = []
## Items in this list cannot be added (Blacklist). Checked before whitelist.
@export var denied_items: Array[Resource] = []

# Array of Dictionaries: { "item": ItemResource, "count": int } or null
var slots: Array = []

func _ready():
	slots.resize(max_slots)
	slots.fill(null)

func is_item_allowed(item: ItemResource) -> bool:
	if not item: return false
	
	# 1. Blacklist Check (Priority)
	if not denied_items.is_empty():
		if _is_in_list(item, denied_items):
			return false
	
	# 2. Whitelist Check
	if not allowed_items.is_empty():
		return _is_in_list(item, allowed_items)
			
	return true

func _is_in_list(item: ItemResource, list: Array[Resource]) -> bool:
	# Check reference equality
	if item in list: return true
	# Check path equality (for different instances of same resource)
	for entry in list:
		if entry and entry.resource_path == item.resource_path:
			return true
	return false

func add_item(item: ItemResource, count: int = 1) -> int:
	if not item: return count
	if not is_item_allowed(item): return count
	
	var initial_count = count
	
	# 1. Try to stack
	for i in range(max_slots):
		if slots[i] != null and slots[i].item == item:
			var space = slot_capacity - slots[i].count
			var to_add = min(space, count)
			slots[i].count += to_add
			count -= to_add
			if count == 0:
				emit_signal("inventory_changed")
				return 0

	# 2. Try empty slots
	if count > 0:
		for i in range(max_slots):
			if slots[i] == null:
				var to_add = min(slot_capacity, count)
				slots[i] = { "item": item, "count": to_add }
				count -= to_add
				if count == 0:
					emit_signal("inventory_changed")
					return 0
	
	if count < initial_count: # If we added anything
		emit_signal("inventory_changed")
		
	return count # Return remaining amount

func get_first_item() -> ItemResource:
	for slot in slots:
		if slot != null and slot.count > 0:
			return slot.item
	return null

func remove_item(item: ItemResource, count: int = 1) -> bool:
	for i in range(max_slots):
		if slots[i] != null and slots[i].item == item:
			if slots[i].count >= count:
				slots[i].count -= count
				if slots[i].count <= 0:
					slots[i] = null
				emit_signal("inventory_changed")
				return true
	return false

func has_space_for(item: ItemResource) -> bool:
	if not is_item_allowed(item): return false
	
	# Check for stack space
	for i in range(max_slots):
		if slots[i] != null and slots[i].item == item:
			if slots[i].count < slot_capacity:
				return true
	# Check for empty slot
	for i in range(max_slots):
		if slots[i] == null:
			return true
	return false

func has_item() -> bool:
	return get_first_item() != null