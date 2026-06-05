class_name UIHelper extends RefCounted

static func create_slot_btn_base() -> Button:
	var b = Button.new()
	b.custom_minimum_size = Vector2(64, 64)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	var center = CenterContainer.new()
	center.name = "IconCenter"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(center)
	return b

static func fill_slot_btn(b: Button, slot_data) -> void:
	if slot_data:
		var it = slot_data.item
		if "item_name" in it: b.tooltip_text = it.item_name
		elif "buildable_name" in it: b.tooltip_text = it.buildable_name
		
		var tr = TextureRect.new()
		tr.texture = it.icon
		tr.custom_minimum_size = Vector2(64, 64)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = Control.TEXTURE_FILTER_NEAREST
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		var center = b.get_node("IconCenter")
		if center: center.add_child(tr)
		
		var l = Label.new()
		l.text = str(slot_data.count)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		l.offset_right = -4
		l.offset_bottom = -2
		var font = load("res://assets/fonts/v2-fs-tahoma-8px.otf")
		if font: l.add_theme_font_override("font", font)
		l.add_theme_font_size_override("font_size", 16)
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		l.add_theme_constant_override("outline_size", 4)
		b.add_child(l)

# ---- Shared Drag & Drop Logic ---- #

static func handle_shift_click(source_inv: Node, slot_idx: int) -> void:
	if not source_inv or slot_idx < 0 or slot_idx >= source_inv.slots.size(): return
	var slot = source_inv.slots[slot_idx]
	if not slot: return
	
	var item = slot.item
	var count = slot.count
	
	var main = Engine.get_main_loop().current_scene
	var ui = main.get_node_or_null("GameUI")
	if not ui: return
	
	var target_inv = null
	var pm_inv = main.get_node_or_null("/root/PlayerManager").game_inventory
	if not pm_inv: return
	
	# 1. Check if a building/chest inventory is open
	if ui.inventory_gui and ui.inventory_gui.visible:
		var ctx = ui.inventory_gui.current_context
		var in_inv = ctx.get("input_inventory") if ctx else null
		var gen_inv = ui.inventory_gui.current_inventory
		
		if source_inv == pm_inv:
			# Player -> Machine/Chest
			target_inv = in_inv if in_inv else gen_inv
		else:
			# Machine/Chest -> Player
			target_inv = pm_inv
			
	# 2. Check if player menu is open and an ally is selected
	elif ui.player_menu and ui.player_menu.visible and ui.player_menu.current_ally:
		var ally_inv = ui.player_menu._get_ally_inventory(ui.player_menu.current_ally)
		if ally_inv:
			if source_inv != ally_inv:
				target_inv = ally_inv
			else:
				target_inv = pm_inv
	
	# 3. Always fallback to Player Inventory if extracting from building while Player Menu is closed
	if not target_inv:
		if source_inv != pm_inv:
			target_inv = pm_inv
		else:
			var pm = main.get_node_or_null("/root/PlayerManager")
			if pm and pm.is_creative_mode and ui.player_menu and ui.player_menu.visible:
				source_inv.slots[slot_idx] = null
				if source_inv.has_signal("inventory_changed"):
					source_inv.inventory_changed.emit()
			return
		
	# Quick transfer into ally specific slots if target is an ally:
	if target_inv.get_parent() and target_inv.get_parent().is_in_group("allies"):
		var specific_slot = -1
		if item.get("equipment_type") != null and item.equipment_type != 0:
			match item.equipment_type:
				1: specific_slot = 0 # TOOL
				2: specific_slot = 1 # WEAPON
				3: specific_slot = 2 # ARMOR
				4: specific_slot = 3 # ACCESSORY
		
		if specific_slot != -1 and target_inv.slots.size() > specific_slot:
			if target_inv.slots[specific_slot] == null or target_inv.slots[specific_slot].item == item:
				if target_inv.slots[specific_slot] == null:
					target_inv.slots[specific_slot] = {"item": item, "count": count}
					source_inv.slots[slot_idx] = null
				else:
					var cap = 99
					if target_inv.has_method("_get_stack_limit"): cap = target_inv._get_stack_limit(item)
					elif item.get("stack_size"): cap = item.stack_size
					var space = cap - target_inv.slots[specific_slot].count
					var move = min(space, count)
					target_inv.slots[specific_slot].count += move
					source_inv.slots[slot_idx].count -= move
					if source_inv.slots[slot_idx].count <= 0: source_inv.slots[slot_idx] = null
					
				if target_inv.has_signal("inventory_changed"): target_inv.inventory_changed.emit()
				if source_inv.has_signal("inventory_changed"): source_inv.inventory_changed.emit()
				return
				
	# General transfer
	var remainder = target_inv.add_item(item, count)
	var taken = count - remainder
	if taken > 0:
		source_inv.slots[slot_idx].count -= taken
		if source_inv.slots[slot_idx].count <= 0:
			source_inv.slots[slot_idx] = null
		if source_inv.has_signal("inventory_changed"): source_inv.inventory_changed.emit()

static func drag_inv(_at_position: Vector2, inv: Node, i: int, btn: Control):
	var s = inv.slots[i]
	if not s: return null
	btn.set_drag_preview(WindowUtils.create_drag_preview(s.item.icon))
	return { "type": "inventory_drag", "inventory": inv, "slot_index": i, "item": s.item, "count": s.count }

static func can_drop(_pos: Vector2, d) -> bool:
	return typeof(d) == TYPE_DICTIONARY and d.has("type")

static func can_drop_building(_pos: Vector2, data, inv: Node) -> bool:
	if typeof(data) != TYPE_DICTIONARY or data.get("type") != "inventory_drag": return false
	if not inv or not inv.get("can_receive"): return false
	if inv.has_method("is_item_allowed") and not inv.is_item_allowed(data.item): return false
	return true

static func can_drop_ally(_pos: Vector2, d, inv: Node, idx: int) -> bool:
	if not (typeof(d) == TYPE_DICTIONARY and d.has("type") and d.has("item")): return false
	var item = d.item
	if item.get("equipment_type") != null and item.equipment_type != 0:
		var target_slot = item.equipment_type - 1
		# Prevent putting wrong equipment into an equipment slot
		if idx <= 3 and idx != target_slot: return false
	elif idx <= 3:
		# Prevent non-equipment items going into equipment slots
		return false
	return true

static func drop_inv(_pos: Vector2, d: Dictionary, target_inv: Node, i: int) -> void:
	generic_drop(d, target_inv, i)

static func drop_ally(_pos: Vector2, d: Dictionary, inv: Node, i: int) -> void:
	# Intelligent Ally Auto-Equip Redirection
	if d.has("item") and d.item.get("equipment_type") != null and d.item.equipment_type != 0:
		var target_slot = d.item.equipment_type - 1
		if i <= 3:
			# Force equipment into designated slot if dropped anywhere in the top slots
			i = target_slot
		elif inv.slots[target_slot] == null:
			# Auto-equip if dropped in backpack but the correct equipment slot is completely empty
			i = target_slot
			
	generic_drop(d, inv, i)

static func generic_drop(data: Dictionary, target_inv: Node, target_idx: int) -> void:
	var src = data.get("inventory")
	var item = data.get("item", data.get("resource"))
	var count = data.get("count", 1)
	
	if data.get("type") == "creative_spawn":
		var cap = item.get("stack_size", 64)
		var t_slot = target_inv.slots[target_idx]
		if t_slot == null:
			target_inv.slots[target_idx] = {"item": item, "count": cap}
		elif t_slot.item == item:
			t_slot.count = cap
		else:
			target_inv.add_item(item, cap)
		if target_inv.has_signal("inventory_changed"): target_inv.inventory_changed.emit()
		
	elif data.get("type") == "inventory_drag" and src:
		if src == target_inv:
			# Internal Drag/Swap Logic
			var t_slot = target_inv.slots[target_idx]
			if t_slot == null:
				target_inv.slots[target_idx] = src.slots[data.slot_index]
				src.slots[data.slot_index] = null
			elif t_slot.item == item:
				var cap = 99
				if target_inv.has_method("_get_stack_limit"): cap = target_inv._get_stack_limit(item)
				elif item.get("stack_size"): cap = item.stack_size
				
				var space = cap - t_slot.count
				var move = min(space, count)
				t_slot.count += move
				src.slots[data.slot_index].count -= move
				if src.slots[data.slot_index].count <= 0:
					src.slots[data.slot_index] = null
			else:
				var temp = target_inv.slots[target_idx]
				target_inv.slots[target_idx] = src.slots[data.slot_index]
				src.slots[data.slot_index] = temp
			if target_inv.has_signal("inventory_changed"): target_inv.inventory_changed.emit()
		else:
			# External Transfer Logic
			var cap = 99
			if target_inv.has_method("_get_stack_limit"): cap = target_inv._get_stack_limit(item)
			elif item.get("stack_size"): cap = item.stack_size
			
			var t_slot = target_inv.slots[target_idx]
			var taken = 0
			
			if t_slot == null:
				target_inv.slots[target_idx] = {"item": item, "count": min(count, cap)}
				taken = min(count, cap)
			elif t_slot.item == item:
				var space = cap - t_slot.count
				var move = min(space, count)
				t_slot.count += move
				taken = move
				
			var remaining = count - taken
			if remaining > 0 and target_inv.has_method("add_item"):
				var left_over = target_inv.add_item(item, remaining)
				taken += (remaining - left_over)
				
			if taken > 0:
				var s_slot = src.slots[data.slot_index]
				if s_slot and s_slot.item == item:
					s_slot.count -= taken
					if s_slot.count <= 0: src.slots[data.slot_index] = null
					if src.has_signal("inventory_changed"): src.inventory_changed.emit()
				else:
					if src.has_method("remove_item"): src.remove_item(item, taken)
					
			if target_inv.has_signal("inventory_changed"): target_inv.inventory_changed.emit()

static func can_drop_trash(_pos, data) -> bool:
	var pm = Engine.get_main_loop().root.get_node_or_null("PlayerManager")
	if not pm or not pm.is_creative_mode: return false
	return typeof(data) == TYPE_DICTIONARY and data.has("type") and data.type == "inventory_drag"

static func drop_trash(_pos, data) -> void:
	if data.has("inventory") and data.has("item") and data.has("count"):
		var inv = data.inventory
		var slot_idx = data.get("slot_index", -1)
		if slot_idx != -1 and inv.slots[slot_idx] != null and inv.slots[slot_idx].item == data.item:
			inv.slots[slot_idx] = null
			if inv.has_signal("inventory_changed"): inv.inventory_changed.emit()
		else:
			if inv.has_method("remove_item"): inv.remove_item(data.item, data.count)
