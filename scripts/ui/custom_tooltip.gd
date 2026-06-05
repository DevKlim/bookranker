class_name CustomTooltip
extends PanelContainer

var resource: Resource
var timer: float = 0.0
var details_container: VBoxContainer
var expanded: bool = false

func _init(res: Resource):
	resource = res
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.95)
	style.border_width_left = 2; style.border_width_top = 2
	style.border_width_right = 2; style.border_width_bottom = 2
	style.corner_radius_top_left = 6; style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6; style.corner_radius_bottom_right = 6
	
	var r_str = res.get("rarity") if "rarity" in res else "C"
	var r_color = _get_rarity_color(r_str)
	style.border_color = r_color
	add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)
	
	var vbox = VBoxContainer.new()
	margin.add_child(vbox)
	
	var header_hbox = HBoxContainer.new()
	vbox.add_child(header_hbox)
	
	var title = Label.new()
	title.text = res.get("item_name") if "item_name" in res else (res.get("buildable_name") if "buildable_name" in res else "Unknown")
	title.add_theme_color_override("font_color", r_color)
	title.add_theme_font_size_override("font_size", 16)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_hbox.add_child(title)
	
	var rank_lbl = Label.new()
	rank_lbl.text = "[%s]" % r_str
	rank_lbl.add_theme_color_override("font_color", r_color)
	rank_lbl.add_theme_font_size_override("font_size", 16)
	header_hbox.add_child(rank_lbl)
	
	var type_lbl = Label.new()
	var cat = res.get("item_category") if "item_category" in res else (res.get("build_category") if "build_category" in res else "Item")
	type_lbl.text = cat
	type_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	vbox.add_child(type_lbl)
	
	details_container = VBoxContainer.new()
	details_container.visible = false
	vbox.add_child(details_container)
	
	var sep = HSeparator.new()
	details_container.add_child(sep)
	
	var desc = Label.new()
	var desc_text = res.get("description") if "description" in res else ""
	if desc_text == "" and "tool_type" in res and res.get("tool_type") != "none":
		desc_text = "A tool used for " + res.get("tool_type")
	if desc_text != "":
		desc.text = desc_text
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc.custom_minimum_size = Vector2(250, 0)
		desc.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		details_container.add_child(desc)
		details_container.add_child(HSeparator.new())
	
	var stats_grid = GridContainer.new()
	stats_grid.columns = 2
	stats_grid.add_theme_constant_override("h_separation", 24)
	details_container.add_child(stats_grid)
	
	_populate_stats(stats_grid)

func _process(delta: float):
	if not expanded:
		timer += delta
		if timer >= 1.0: # Shortened to 1s to feel snappier 
			expanded = true
			details_container.visible = true
			details_container.modulate.a = 0.0
			var t = create_tween()
			t.tween_property(details_container, "modulate:a", 1.0, 0.3)
			reset_size()

func _get_rarity_color(rarity: String) -> Color:
	match rarity.to_upper():
		"F": return Color(0.5, 0.5, 0.5)
		"D": return Color(1.0, 1.0, 1.0)
		"C": return Color(0.33, 1.0, 0.33)
		"B": return Color(0.33, 0.33, 1.0)
		"A": return Color(0.66, 0.33, 1.0)
		"S": return Color(1.0, 0.84, 0.0)
		"SS": return Color(1.0, 0.27, 0.0)
		"SS+": return Color(0.0, 1.0, 1.0)
	return Color(0.33, 1.0, 0.33)

func _populate_stats(grid: GridContainer):
	var overrides = resource.get("custom_tooltip_labels") if "custom_tooltip_labels" in resource else {}
	var used_overrides =[]
	
	var add_stat = func(default_name: String, val: String, color: Color = Color(0.7,0.7,0.7), val_color: Color = Color.WHITE):
		var name_to_use = default_name
		if overrides.has(default_name):
			name_to_use = str(overrides[default_name])
			used_overrides.append(default_name)
		
		# Allow completely hiding a stat if the override is "HIDDEN"
		if name_to_use == "HIDDEN": return
		
		var n = Label.new(); n.text = name_to_use + ":"; n.add_theme_color_override("font_color", color)
		var v = Label.new(); v.text = val; v.add_theme_color_override("font_color", val_color)
		grid.add_child(n); grid.add_child(v)
		
	if resource is BuildableResource:
		if resource.max_health > 0: add_stat.call("HP", str(resource.max_health))
		if resource.power_consumption > 0: add_stat.call("Power Use", str(resource.power_consumption) + " W", Color(0.7, 0.7, 0.7), Color(1.0, 0.5, 0.5))
		if resource.power_consumption < 0: add_stat.call("Power Gen", str(-resource.power_consumption) + " W", Color(0.7, 0.7, 0.7), Color(0.5, 1.0, 0.5))
		if resource.attack_damage > 0:
			add_stat.call("Damage", str(resource.attack_damage))
			if resource.process_speed > 0:
				add_stat.call("DPS", "%.1f" % (resource.attack_damage / resource.process_speed))
		elif resource.process_speed != 1.0 and resource.process_speed > 0:
			add_stat.call("Process Speed", str(resource.process_speed))
	else:
		if resource.get("damage") and resource.get("damage") > 0: add_stat.call("Damage", str(resource.get("damage")))
		if resource.get("element") and resource.get("element") != null: add_stat.call("Element", resource.get("element").element_name)
		if resource.get("stack_size") and resource.get("stack_size") > 1: add_stat.call("Max Stack", str(resource.get("stack_size")))

		if resource.equipment_type == ItemResource.EquipmentType.MOD:
			var is_core = resource.modifiers.get("type") == "core"
			add_stat.call("Mod Type", "Core" if is_core else "Building", Color(0.5, 0.8, 1.0))
			if resource.modifiers.get("permanent"):
				add_stat.call("CURSE", "Cannot be removed", Color(1.0, 0.0, 0.0), Color(1.0, 0.2, 0.2))
				
			var effects = resource.modifiers.get("effects", {})
			for k in effects.keys():
				var val = effects[k]
				var float_val = float(val)
				var is_positive = float_val > 0
				
				# Invert logic for debuff-sounding stats
				if k.ends_with("_mult") and k.begins_with("power_consumption"): is_positive = float_val < 0
				elif k.ends_with("_mult") and k.begins_with("incoming_damage"): is_positive = float_val < 0
				
				var sign_str = "+" if float_val > 0 else ""
				var format_val = "%s%.2f" % [sign_str, float_val]
				if k.ends_with("_mult"):
					format_val = "%s%d%%" % [sign_str, int(float_val * 100)]
				
				var readable_k = k.replace("_mult", "").replace("_flat", "").replace("_", " ").capitalize()
				var val_color = Color(0.4, 1.0, 0.4) if is_positive else Color(1.0, 0.4, 0.4)
				add_stat.call(readable_k, format_val, Color(0.8, 0.8, 0.8), val_color)

	for k in overrides.keys():
		if not used_overrides.has(k):
			add_stat.call(k, str(overrides[k]))

