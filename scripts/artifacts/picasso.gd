extends RefCounted

func _get_inventory(source: Node) -> InventoryComponent:
	return source.get_node_or_null("InventoryComponent")

func can_attack(source: Node, attack: AttackResource) -> bool:
	var is_creative = false
	if source.get_tree().root.has_node("PlayerManager"):
		is_creative = source.get_tree().root.get_node("PlayerManager").is_creative_mode
	if is_creative: return true
	
	var inv = _get_inventory(source)
	if not inv: return false
	
	var ink_res = load("res://resources/items/ink.tres")
	if not ink_res: return false
	
	var ink_count = 0
	for slot in inv.slots:
		if slot != null and typeof(slot) == TYPE_DICTIONARY and slot.item == ink_res:
			ink_count += slot.count
			
	return ink_count >= 9

func modify_damage(base_damage: float, source: Node, attack: AttackResource) -> float:
	var is_creative = false
	if source.get_tree().root.has_node("PlayerManager"):
		is_creative = source.get_tree().root.get_node("PlayerManager").is_creative_mode
		
	var inv = _get_inventory(source)
	if not inv and not is_creative: return 0.0
	
	var ink_res = load("res://resources/items/ink.tres")
	if not ink_res and not is_creative: return 0.0
	
	var ink_count = 999
	if not is_creative:
		ink_count = 0
		for slot in inv.slots:
			if slot != null and typeof(slot) == TYPE_DICTIONARY and slot.item == ink_res:
				ink_count += slot.count
				
	if ink_count < 9 and not is_creative: return 0.0
	
	var item = source.get("active_weapon_item")
	var target_num = item.get_meta("target_number", 5) if item else 5
	var luck = source.get_stat("luck_stat", 0.0) if source.has_method("get_stat") else 0.0
	
	var n = 1
	var chance = clamp(luck / 100.0, 0.0, 1.0)
	
	if randf() < chance:
		if randf() < 0.7: n = target_num
		else: n = clamp(target_num + randi_range(-1, 1), 1, 9)
	else:
		n = randi_range(1, 9)
	
	n = min(ink_count, n)
	
	var nearest = null
	var min_d = 15.0 
	var enemies = source.get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if is_instance_valid(e) and not e.get("is_dead"):
			var d = source.global_position.distance_to(e.global_position)
			if d < min_d:
				min_d = d
				nearest = e
			
	if is_instance_valid(nearest):
		if not is_creative and inv:
			inv.remove_item(ink_res, n)
			
		var final_dmg = float(n)
		var duration = float(n) * 0.35
		
		# Extend the cooldown strictly by the drawing duration so the player cannot attack again
		source.set_meta("picasso_draw_duration", duration)
		
		# Spawn the manual 3D Stroke scene
		var vfx_scene = load("res://scenes/attacks/ink_stroke_vfx.tscn")
		if vfx_scene:
			var vfx = vfx_scene.instantiate()
			source.get_tree().current_scene.add_child(vfx)
			# Offset it slightly up and in front so it reads well
			vfx.global_position = nearest.global_position + Vector3(0, 1.5, 0.5)
			vfx.setup(n, duration)
		
		source.get_tree().create_timer(duration).timeout.connect(func():
			if is_instance_valid(nearest) and not nearest.get("is_dead"):
				if source.get_tree().root.has_node("GameManager"):
					source.get_tree().root.get_node("GameManager").vfx_manager.play_vfx("y2k_reaction", nearest.global_position)
				
				var em = source.get_tree().root.get_node_or_null("ElementManager")
				var dark_elem = em.get_element("dark") if em else null
				
				if nearest.has_method("take_damage"):
					nearest.take_damage(final_dmg, dark_elem, source)
				elif nearest.has_node("HealthComponent"):
					nearest.get_node("HealthComponent").take_damage(final_dmg, dark_elem, source)
		)

	return 0.0

func modify_cooldown(base_cd: float, source: Node, attack: AttackResource) -> float:
	var draw_dur = source.get_meta("picasso_draw_duration", 0.0)
	source.set_meta("picasso_draw_duration", 0.0)
	return base_cd + draw_dur

func on_right_click(item: ItemResource, parent_ui: Control) -> void:
	var layer_root = CanvasLayer.new()
	layer_root.layer = 160
	layer_root.process_mode = Node.PROCESS_MODE_ALWAYS
	
	var script = GDScript.new()
	script.source_code = """
extends CanvasLayer
func _input(event):
	if event.is_action_pressed("ui_cancel"):
		queue_free()
		get_viewport().set_input_as_handled()
"""
	script.reload()
	layer_root.set_script(script)
	
	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	layer_root.add_child(bg)
	
	var window_root = Control.new()
	var vp_size = DisplayServer.window_get_size()
	window_root.size = Vector2(300, 200)
	window_root.position = (Vector2(vp_size) - window_root.size) / 2.0
	layer_root.add_child(window_root)
	
	var panel = PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.1, 0.95)
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_left = 12
	sb.corner_radius_bottom_right = 12
	sb.border_width_bottom = 2
	sb.border_width_top = 2
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_color = Color(0.3, 0.3, 0.3)
	panel.add_theme_stylebox_override("panel", sb)
	
	var custom_theme = Theme.new()
	var font = load("res://assets/fonts/v2-fs-tahoma-8px.otf")
	if font:
		custom_theme.default_font = font
		custom_theme.default_font_size = 16
	panel.theme = custom_theme
	window_root.add_child(panel)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)
	
	var main_vbox = VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 15)
	margin.add_child(main_vbox)
	
	var top_hbox = HBoxContainer.new()
	var title_lbl = Label.new()
	title_lbl.text = "Picasso Target Number"
	title_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.add_child(title_lbl)
	
	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(30, 30)
	var cls_style = StyleBoxFlat.new()
	cls_style.bg_color = Color(1.0, 0.3, 0.3, 0.5)
	cls_style.corner_radius_top_left = 6; cls_style.corner_radius_top_right = 6
	cls_style.corner_radius_bottom_left = 6; cls_style.corner_radius_bottom_right = 6
	close_btn.add_theme_stylebox_override("normal", cls_style)
	close_btn.pressed.connect(layer_root.queue_free)
	top_hbox.add_child(close_btn)
	main_vbox.add_child(top_hbox)
	
	var center_grid = GridContainer.new()
	center_grid.columns = 2
	center_grid.add_theme_constant_override("h_separation", 15)
	main_vbox.add_child(center_grid)
	
	var tg_label = Label.new()
	tg_label.text = "Target Number:"
	tg_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	center_grid.add_child(tg_label)
	
	var spin = SpinBox.new()
	spin.min_value = 1
	spin.max_value = 9
	spin.value = item.get_meta("target_number", 5)
	center_grid.add_child(spin)
	
	var save_btn = Button.new()
	save_btn.text = "Save Config"
	save_btn.custom_minimum_size = Vector2(0, 40)
	save_btn.pressed.connect(func():
		item.set_meta("target_number", int(spin.value))
		layer_root.queue_free()
	)
	main_vbox.add_child(save_btn)
	
	parent_ui.get_tree().root.add_child(layer_root)
