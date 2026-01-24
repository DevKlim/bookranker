extends PanelContainer

const SLOT_COUNT = 10
@onready var container: HBoxContainer = $MarginContainer/HBoxContainer
var _buttons: Array[Button] = []

# Track active slot index locally
var selected_slot_index: int = -1

func _ready() -> void:
	for child in container.get_children(): child.queue_free()
	for i in range(SLOT_COUNT):
		var button = Button.new()
		button.custom_minimum_size = Vector2(64, 64)
		button.expand_icon = true
		
		# Center Icons in Hotbar
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		
		# Add Quantity Label
		var lbl = Label.new()
		lbl.name = "CountLabel"
		lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		lbl.add_theme_constant_override("outline_size", 4)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		lbl.anchors_preset = Control.PRESET_BOTTOM_RIGHT
		lbl.position = Vector2(-4, -2)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE 
		button.add_child(lbl)
		
		button.pressed.connect(_on_slot_pressed.bind(i))
		button.set_drag_forwarding(Callable(self, "_get_slot_drag_data").bind(i), Callable(self, "_can_drop"), Callable(self, "_drop").bind(i))
		container.add_child(button)
		_buttons.append(button)
	
	PlayerManager.player_inventory.inventory_changed.connect(_update_visuals)
	BuildManager.selected_buildable_changed.connect(_update_visuals)
	# Listen to build mode changes to clear highlight when right-clicking/canceling
	BuildManager.build_mode_changed.connect(_on_build_mode_changed)
	_update_visuals()

func _on_slot_pressed(index: int) -> void:
	var slot = PlayerManager.player_inventory.slots[index]
	
	# Deselect if clicking the same slot
	if selected_slot_index == index:
		selected_slot_index = -1
		if BuildManager.is_building: BuildManager.exit_build_mode()
		PlayerManager.set_equipped_item(null)
		_update_visuals()
		return
	
	# Select new slot
	selected_slot_index = index
	
	if slot == null:
		if BuildManager.is_building: BuildManager.exit_build_mode()
		PlayerManager.set_equipped_item(null)
		_update_visuals()
		return
		
	var res = slot.item
	if res is BuildableResource:
		PlayerManager.set_equipped_item(null)
		# If user clicks a buildable, enter build mode
		if BuildManager.is_building and BuildManager.selected_buildable == res:
			pass
		else:
			BuildManager.enter_build_mode(res)
	elif res is ItemResource:
		# Just highlight items (e.g. weapons/tools) but exit build mode
		BuildManager.exit_build_mode()
		PlayerManager.set_equipped_item(res)
	
	_update_visuals()

func _on_build_mode_changed(is_building: bool) -> void:
	# If build mode is cancelled externally (e.g. Right Click), clear slot highlight
	if not is_building:
		if selected_slot_index != -1:
			var slot = PlayerManager.player_inventory.slots[selected_slot_index]
			# If the selected item was a Buildable, we deselect it.
			if slot and slot.item is BuildableResource:
				selected_slot_index = -1
		_update_visuals()

func _update_visuals(_arg = null) -> void:
	var slots = PlayerManager.player_inventory.slots
	
	for i in range(SLOT_COUNT):
		var button = _buttons[i]
		var lbl = button.get_node("CountLabel")
		var slot = slots[i]
		
		if slot:
			button.icon = slot.item.icon
			button.text = "" # Hide number if item exists
			lbl.text = str(slot.count) # Show count
			if slot.item is BuildableResource: button.tooltip_text = "%s (%d)" % [slot.item.buildable_name, slot.count]
			else: button.tooltip_text = "%s (%d)" % [slot.item.item_name, slot.count]
		else:
			button.icon = null
			button.text = str((i + 1) % 10) # Show slot number if empty
			lbl.text = ""
			button.tooltip_text = "Slot %d" % ((i + 1) % 10)
		
		# Highlight selected slot
		if i == selected_slot_index:
			button.modulate = Color(0.5, 1.0, 0.5)
		else:
			button.modulate = Color.WHITE

# --- Drag and Drop Logic ---

func _get_slot_drag_data(_pos, index: int) -> Variant:
	var slot = PlayerManager.player_inventory.slots[index]
	if not slot: return null
	
	var preview = TextureRect.new()
	preview.texture = slot.item.icon
	preview.size = Vector2(40, 40)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.z_index = 100 # Ensure on top
	set_drag_preview(preview)
	
	return { 
		"type": "inventory_drag", 
		"inventory": PlayerManager.player_inventory, 
		"slot_index": index, 
		"item": slot.item, 
		"count": slot.count 
	}

func _can_drop(_pos, data) -> bool:
	if typeof(data) != TYPE_DICTIONARY: return false
	return data.type in ["creative_spawn", "inventory_drag"]

func _drop(_pos, data, index: int) -> void:
	var inv = PlayerManager.player_inventory
	
	if data.type == "creative_spawn":
		var res = data.resource
		var stack = 64
		if res is ItemResource: stack = res.stack_size
		inv.slots[index] = { "item": res, "count": stack }
		inv.inventory_changed.emit()
		
	elif data.type == "inventory_drag":
		var source_inv = data.inventory
		var s_idx = data.slot_index
		
		# Prevent moving empty
		if s_idx >= source_inv.slots.size() or not source_inv.slots[s_idx]: return
		
		var s_slot = source_inv.slots[s_idx]
		var item = s_slot.item
		var count = s_slot.count
		var t_slot = inv.slots[index]
		
		if source_inv == inv:
			# Internal Swap
			if t_slot == null:
				inv.slots[index] = s_slot
				inv.slots[s_idx] = null
			elif inv._items_match(t_slot.item, item):
				var cap = inv._get_stack_limit(t_slot.item)
				var space = cap - t_slot.count
				var move = min(space, count)
				t_slot.count += move
				s_slot.count -= move
				if s_slot.count <= 0: inv.slots[s_idx] = null
			else:
				inv.slots[index] = s_slot
				inv.slots[s_idx] = t_slot
			inv.inventory_changed.emit()
		else:
			# External Transfer (e.g. Machine -> Hotbar)
			if t_slot == null:
				inv.slots[index] = { "item": item, "count": count }
				source_inv.slots[s_idx] = null
			elif inv._items_match(t_slot.item, item):
				var cap = inv._get_stack_limit(t_slot.item)
				var space = cap - t_slot.count
				var move = min(space, count)
				t_slot.count += move
				source_inv.slots[s_idx].count -= move
				if source_inv.slots[s_idx].count <= 0:
					source_inv.slots[s_idx] = null
			else:
				# Swap if allowed
				if source_inv.is_item_allowed(t_slot.item):
					var temp = { "item": t_slot.item, "count": t_slot.count }
					inv.slots[index] = { "item": item, "count": count }
					source_inv.slots[s_idx] = temp
				else:
					return
			
			inv.inventory_changed.emit()
			source_inv.inventory_changed.emit()
