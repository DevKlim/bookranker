class_name WorldDropTarget
extends Control

## Efficient drop target for dragging items from UI to 3D world without causing lag

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	# Check format only. Avoid expensive 3D raycasts here!
	return typeof(data) == TYPE_DICTIONARY and data.has("item")

func _drop_data(at_position: Vector2, data: Variant) -> void:
	if not (typeof(data) == TYPE_DICTIONARY and data.has("item")): return
	
	var main = get_tree().current_scene
	if main and main.has_method("get_mouse_raycast"):
		# Perform the expensive raycast only ONCE upon dropping
		var ray = main.get_mouse_raycast()
		if ray and ray.has("collider"):
			var col = ray.collider
			if is_instance_valid(col):
				var count = 1
				if data.has("count"):
					count = data.count
				elif data.has("inventory") and data.has("slot_index"):
					var src_inv = data.inventory
					if "slots" in src_inv and data.slot_index >= 0 and data.slot_index < src_inv.slots.size():
						var slot = src_inv.slots[data.slot_index]
						if typeof(slot) == TYPE_DICTIONARY and slot.has("count"):
							count = slot.count
				
				if count <= 0: return
				
				var accepted = 0
				var remainder = count
				
				var target_inv = col.get("inventory_component")
				var mod_inv = col.get("mod_inventory")
				
				# 1. Try inserting into the primary inventory component
				if target_inv and target_inv is InventoryComponent and target_inv.can_receive:
					remainder = target_inv.add_item(data.item, remainder)
					
				# 2. If items are left over (e.g. it's a Mod and the main inventory rejected it), try mod inventory
				if remainder > 0 and mod_inv and mod_inv is InventoryComponent and mod_inv.can_receive:
					remainder = mod_inv.add_item(data.item, remainder)
					
				# 3. Fallback for entities that don't expose an InventoryComponent directly but can receive
				if remainder == count and col.has_method("receive_item"):
					var temp_accepted = 0
					for i in range(remainder):
						if col.receive_item(data.item, null):
							temp_accepted += 1
						else:
							break
					remainder -= temp_accepted
					
				accepted = count - remainder
				
				# Deduct the accepted amount from the source inventory slot
				if accepted > 0 and data.has("inventory"):
					var src_inv = data.inventory
					if data.has("slot_index") and "slots" in src_inv and data.slot_index >= 0 and data.slot_index < src_inv.slots.size():
						var slot = src_inv.slots[data.slot_index]
						# Directly modify the slot to prevent sweeping other slots containing the same item type
						if typeof(slot) == TYPE_DICTIONARY and slot.has("item") and slot.item == data.item:
							slot.count -= accepted
							if slot.count <= 0:
								src_inv.slots[data.slot_index] = null
							if src_inv.has_signal("inventory_changed"):
								src_inv.emit_signal("inventory_changed")
						else:
							if src_inv.has_method("remove_item"): src_inv.remove_item(data.item, accepted)
					else:
						if src_inv.has_method("remove_item"): src_inv.remove_item(data.item, accepted)
