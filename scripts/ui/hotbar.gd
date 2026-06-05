extends PanelContainer

const SLOT_COUNT = 9
@onready var container: HBoxContainer = $MarginContainer/HBoxContainer
var _buttons: Array[Button] =[]

# Track active slot index locally
var selected_slot_index: int = -1

var remover_button: Button
var remover_lbl: Label

func _ready() -> void:
	# Wipe default gray box padding so it perfectly fits the glass window
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	
	# Set proper alignment so scaled-up dimensions neatly place the elements centrally
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	
	for child in container.get_children(): child.queue_free()
	for i in range(SLOT_COUNT):
		var button = Button.new()
		button.custom_minimum_size = Vector2(64, 64)
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		button.set_script(preload("res://scripts/ui/slot_button.gd"))

		# Center Container prevents Button's inner margins from fractionally shrinking the 64x64 TextureRect
		var center = CenterContainer.new()
		center.name = "IconCenter"
		center.set_anchors_preset(Control.PRESET_FULL_RECT)
		center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(center)

		var tr = TextureRect.new()
		tr.name = "ItemIcon"
		tr.custom_minimum_size = Vector2(64, 64)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = Control.TEXTURE_FILTER_NEAREST
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(tr)
		
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
		var font = load("res://assets/fonts/v2-fs-tahoma-8px.otf")
		if font: lbl.add_theme_font_override("font", font)
		lbl.add_theme_font_size_override("font_size", 16)
		button.add_child(lbl)
		
		button.pressed.connect(_on_slot_pressed.bind(i))
		button.set_drag_forwarding(Callable(self, "_get_slot_drag_data").bind(i, button), Callable(self, "_custom_can_drop"), Callable(self, "_drop").bind(i))
		
		button.gui_input.connect(func(event: InputEvent):
			if event.is_action_pressed("build_copy") and PlayerManager.is_creative_mode:
				if i < PlayerManager.game_inventory.slots.size() and PlayerManager.game_inventory.slots[i]:
					var drag_data = _get_slot_drag_data(Vector2.ZERO, i, button)
					if drag_data:
						button.force_drag(drag_data, WindowUtils.create_drag_preview(drag_data.item.icon))
			
			# Context Menu for right-clicking items (build_cancel)
			if event.is_action_pressed("build_cancel"):
				if i < PlayerManager.game_inventory.slots.size() and PlayerManager.game_inventory.slots[i]:
					_show_slot_context_menu(i, PlayerManager.game_inventory.slots[i])
		)
		
		container.add_child(button)
		_buttons.append(button)

	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(10, 0)
	container.add_child(spacer)
	
	remover_button = Button.new()
	remover_button.custom_minimum_size = Vector2(64, 64)
	remover_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	remover_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	
	var r_center = CenterContainer.new()
	r_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	r_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	remover_button.add_child(r_center)

	var r_tr = TextureRect.new()
	r_tr.custom_minimum_size = Vector2(64, 64)
	r_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r_tr.texture_filter = Control.TEXTURE_FILTER_NEAREST
	r_tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r_center.add_child(r_tr)
	
	remover_button.text = "DEL"
	remover_button.add_theme_color_override("font_color", Color.RED)

	remover_lbl = Label.new()
	remover_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	remover_lbl.add_theme_constant_override("outline_size", 4)
	remover_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	remover_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	remover_lbl.anchors_preset = Control.PRESET_BOTTOM_RIGHT
	remover_lbl.position = Vector2(-4, -2)
	remover_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE 
	remover_button.add_child(remover_lbl)
	
	remover_button.pressed.connect(_on_remover_pressed)
	remover_button.tooltip_text = "Remove Tool"
	container.add_child(remover_button)
	
	PlayerManager.game_inventory.inventory_changed.connect(_update_visuals)
	BuildManager.selected_buildable_changed.connect(_update_visuals)
	BuildManager.build_mode_changed.connect(_on_build_mode_changed)
	PlayerManager.equipped_item_changed.connect(_on_equipped_item_changed)
	BuildManager.remove_mode_changed.connect(_update_visuals)
	_update_visuals()

func _show_slot_context_menu(index: int, slot: Dictionary) -> void:
	var options = []
	
	options.append({"label": "Drop Item", "callback": func():
		PlayerManager.game_inventory.slots[index] = null
		PlayerManager.game_inventory.inventory_changed.emit()
	})
	
	if slot.item is BuildableResource and slot.item.buildable_name == "Attack Spawner":
		options.append({"label": "Quick Configure Spawner", "callback": func():
			if ResourceLoader.exists("res://scripts/ui/quick_config_menu.gd"):
				var qc = load("res://scripts/ui/quick_config_menu.gd")
				qc.open(slot, self)
		})
		
		var pop_enabled = slot.get("meta", {}).get("play_on_place", false)
		options.append({"label": "Play-On-Place: " + ("ON" if pop_enabled else "OFF"), "callback": func():
			if not slot.has("meta"): slot["meta"] = {}
			slot["meta"]["play_on_place"] = not pop_enabled
			_update_visuals()
		})
		
	# Explicit target check for Picasso config menu
	if slot.item is ItemResource and slot.item.item_name == "Picasso":
		options.append({"label": "Set Target Number", "callback": func():
			var script_inst = null
			if slot.item.has_method("get_artifact_instance"):
				script_inst = slot.item.get_artifact_instance()
			elif slot.item.get("artifact_script") != null:
				script_inst = slot.item.get("artifact_script").new()
				
			if script_inst and script_inst.has_method("on_right_click"):
				script_inst.on_right_click(slot.item, self)
		})
			
	var ui = get_tree().current_scene.get_node_or_null("GameUI")
	if ui:
		var mouse_pos = get_viewport().get_mouse_position()
		ui.show_context_menu(mouse_pos, options)

func _on_remover_pressed() -> void:
	if selected_slot_index == -2:
		selected_slot_index = -1
		BuildManager.exit_build_mode()
		_update_visuals()
		return
		
	selected_slot_index = -2
	PlayerManager.set_equipped_item(null)
	var remover_res = BuildableResource.new()
	remover_res.buildable_name = "Remover"
	remover_res.layer = BuildableResource.BuildLayer.TOOL
	BuildManager.enter_build_mode(remover_res)
	_update_visuals()

func _on_slot_pressed(index: int) -> void:
	if Input.is_key_pressed(KEY_SHIFT):
		UIHelper.handle_shift_click(PlayerManager.game_inventory, index)
		return

	if index >= PlayerManager.game_inventory.slots.size(): return

	var slot = PlayerManager.game_inventory.slots[index]
	
	if selected_slot_index == index:
		selected_slot_index = -1
		if BuildManager.is_building: BuildManager.exit_build_mode()
		if PlayerManager.equipped_item: PlayerManager.set_equipped_item(null)
		_update_visuals()
		return
	
	selected_slot_index = index
	
	if slot == null:
		if BuildManager.is_building: BuildManager.exit_build_mode()
		if PlayerManager.equipped_item: PlayerManager.set_equipped_item(null)
		_update_visuals()
		return
		
	var res = slot.item
	if res is BuildableResource:
		if PlayerManager.equipped_item: PlayerManager.set_equipped_item(null)
		
		# Save slot metadata universally to PlayerManager so instantiated tools/buildings can read it!
		PlayerManager.set_meta("active_build_meta", slot.get("meta", {}))
		
		if BuildManager.is_building and BuildManager.selected_buildable == res:
			pass
		else:
			BuildManager.enter_build_mode(res)
	elif res is ItemResource:
		if BuildManager.is_building: BuildManager.exit_build_mode()
		PlayerManager.set_equipped_item(res)
	
	_update_visuals()

func _on_build_mode_changed(is_building: bool) -> void:
	if not is_building:
		if selected_slot_index != -1:
			if selected_slot_index == -2:
				selected_slot_index = -1
			elif selected_slot_index < PlayerManager.game_inventory.slots.size():
				var slot = PlayerManager.game_inventory.slots[selected_slot_index]
				if slot and slot.item is BuildableResource:
					selected_slot_index = -1
			else:
				selected_slot_index = -1
		_update_visuals()

func _on_equipped_item_changed(item: Resource) -> void:
	if not item:
		if selected_slot_index != -1:
			if selected_slot_index == -2:
				selected_slot_index = -1
			elif selected_slot_index < PlayerManager.game_inventory.slots.size():
				var slot = PlayerManager.game_inventory.slots[selected_slot_index]
				if slot and slot.item is ItemResource:
					selected_slot_index = -1
			else:
				selected_slot_index = -1
		_update_visuals()

func _update_visuals(_arg = null) -> void:
	var slots = PlayerManager.game_inventory.slots
	
	for i in range(SLOT_COUNT):
		var button = _buttons[i]
		var tr = button.get_node("IconCenter/ItemIcon")
		var lbl = button.get_node("CountLabel")
		
		var slot = null
		if i < slots.size():
			slot = slots[i]
		else:
			tr.texture = null
			button.text = "X"
			lbl.text = ""
			button.set_meta("tooltip_res", null)
			button.tooltip_text = "Locked Slot"
			button.modulate = Color(0.5, 0.5, 0.5, 0.5)
			continue
		
		if slot:
			tr.texture = slot.item.icon
			button.text = ""
			lbl.text = str(slot.count)
			
			button.set_meta("tooltip_res", slot.item)
			button.tooltip_text = " "
		else:
			tr.texture = null
			button.text = str((i + 1) % 10)
			lbl.text = ""
			button.set_meta("tooltip_res", null)
			button.tooltip_text = "Slot %d" % ((i + 1) % 10)
		
		if i == selected_slot_index:
			button.modulate = Color(0.5, 1.0, 0.5)
		else:
			button.modulate = Color.WHITE

	if remover_button:
		if selected_slot_index == -2:
			remover_button.modulate = Color(1.0, 0.5, 0.5)
			var mode_str = ""
			match BuildManager.current_remove_mode:
				BuildManager.RemoveMode.ALL: mode_str = "ALL"
				BuildManager.RemoveMode.BUILDING_ONLY: mode_str = "BLD"
				BuildManager.RemoveMode.WIRE_ONLY: mode_str = "WIR"
			remover_lbl.text = mode_str
		else:
			remover_button.modulate = Color.WHITE
			remover_lbl.text = ""

func _custom_can_drop(pos, data) -> bool:
	if typeof(data) == TYPE_DICTIONARY and data.get("type") == "creative_copy": return true
	return UIHelper.can_drop(pos, data)

func _get_slot_drag_data(_pos, index: int, btn: Control) -> Variant:
	if index >= PlayerManager.game_inventory.slots.size(): return null
	var slot = PlayerManager.game_inventory.slots[index]
	if not slot: return null
	
	if selected_slot_index != -1:
		selected_slot_index = -1
		if BuildManager.is_building: BuildManager.exit_build_mode()
		if PlayerManager.equipped_item: PlayerManager.set_equipped_item(null)
		_update_visuals()

	if PlayerManager.is_creative_mode and Input.is_action_pressed("build_copy"):
		btn.set_drag_preview(WindowUtils.create_drag_preview(slot.item.icon))
		return { "type": "creative_copy", "item": slot.item, "count": slot.count }

	return UIHelper.drag_inv(_pos, PlayerManager.game_inventory, index, btn)

func _drop(_pos, data, index: int) -> void:
	var inv = PlayerManager.game_inventory
	if index >= inv.slots.size(): return
	if typeof(data) == TYPE_DICTIONARY and data.get("type") == "creative_copy":
		var existing = inv.slots[index]
		if not existing:
			inv.slots[index] = {"item": data.item, "count": data.count}
			inv.inventory_changed.emit()
		elif existing.item == data.item:
			var space = existing.item.stack_size - existing.count
			var add = min(space, data.count)
			existing.count += add
			inv.inventory_changed.emit()
		else:
			inv.slots[index] = {"item": data.item, "count": data.count}
			inv.inventory_changed.emit()
		return
	UIHelper.drop_inv(_pos, data, inv, index)
