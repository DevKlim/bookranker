class_name InventoryComponent
extends Node

## Simple inventory to hold items.

signal inventory_changed

@export var max_slots: int = 1
@export var slot_capacity: int = 50

# Array of Dictionaries: { "item": ItemResource, "count": int } or null
var slots: Array = []

func _ready():
	slots.resize(max_slots)
	slots.fill(null)

func add_item(item: ItemResource, count: int = 1) -> int:
	if not item: return count
	
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
	
	if count < count: # If we added anything
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