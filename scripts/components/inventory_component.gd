class_name InventoryComponent
extends Node

## Inventory that holds items (ItemResource OR BuildableResource).

signal inventory_changed

@export var max_slots: int = 1
@export var slot_capacity: int = 50

@export_group("Permissions")
@export var can_receive: bool = true
@export var can_output: bool = true
@export var omni_directional: bool = false

@export_group("Filters")
@export var allowed_items: Array[Resource] = []
@export var denied_items: Array[Resource] = []

# Array of Dictionaries: { "item": Resource, "count": int } or null
var slots: Array = []

func _ready():
	slots.resize(max_slots)
	slots.fill(null)

func is_item_allowed(item: Resource) -> bool:
	if not item: return false
	if not (item is ItemResource or item is BuildableResource): return false
	
	if not denied_items.is_empty():
		if _is_in_list(item, denied_items): return false
	
	if not allowed_items.is_empty():
		return _is_in_list(item, allowed_items)
			
	return true

func _is_in_list(item: Resource, list: Array[Resource]) -> bool:
	if item in list: return true
	for entry in list:
		if entry and entry.resource_path == item.resource_path:
			return true
	return false

func add_item(item: Resource, count: int = 1) -> int:
	if not item: return count
	if not is_item_allowed(item): return count
	
	var cap = _get_stack_limit(item)
	var initial_count = count
	
	# 1. Try to stack in existing slots
	for i in range(max_slots):
		if slots[i] != null:
			if _items_match(slots[i].item, item):
				var space = cap - slots[i].count
				if space > 0:
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
				var to_add = min(cap, count)
				slots[i] = { "item": item, "count": to_add }
				count -= to_add
				if count == 0:
					emit_signal("inventory_changed")
					return 0
	
	if count < initial_count:
		emit_signal("inventory_changed")
		
	return count

func _items_match(item_a: Resource, item_b: Resource) -> bool:
	if item_a == item_b: return true
	if item_a.resource_path != "" and item_a.resource_path == item_b.resource_path: return true
	return false

func get_first_item() -> Resource:
	for slot in slots:
		if slot != null and slot.count > 0:
			return slot.item
	return null

func has_item_count(item: Resource, amount: int) -> bool:
	var total = 0
	for slot in slots:
		if slot != null and _items_match(slot.item, item):
			total += slot.count
			if total >= amount: return true
	return false

func remove_item(item: Resource, count: int = 1) -> bool:
	# Verify we have enough first (optional, but safer)
	if not has_item_count(item, count): return false
	
	var remaining_to_remove = count
	
	# Pass 1: Remove
	for i in range(max_slots):
		if slots[i] != null and _items_match(slots[i].item, item):
			var taken = min(slots[i].count, remaining_to_remove)
			slots[i].count -= taken
			remaining_to_remove -= taken
			
			if slots[i].count <= 0:
				slots[i] = null
			
			if remaining_to_remove <= 0:
				emit_signal("inventory_changed")
				return true
	
	emit_signal("inventory_changed")
	return remaining_to_remove == 0

func has_space_for(item: Resource) -> bool:
	if not is_item_allowed(item): return false
	var cap = _get_stack_limit(item)
	for i in range(max_slots):
		if slots[i] != null and _items_match(slots[i].item, item):
			if slots[i].count < cap: return true
	for i in range(max_slots):
		if slots[i] == null: return true
	return false

func has_item() -> bool:
	return get_first_item() != null

## Helper to handle both ItemResource and BuildableResource properties
func _get_stack_limit(res: Resource) -> int:
	if res is ItemResource:
		return res.stack_size
	# Buildables default to global slot capacity or 64
	return slot_capacity

## --- Recipe Helpers ---

func has_ingredients_for(recipe: RecipeResource) -> bool:
	if recipe.inputs.is_empty(): return true
	
	for entry in recipe.inputs:
		if not has_item_count(entry.resource, entry.count):
			return false
	return true

func consume_ingredients_for(recipe: RecipeResource) -> bool:
	if not has_ingredients_for(recipe): return false
	
	for entry in recipe.inputs:
		remove_item(entry.resource, entry.count)
	return true
