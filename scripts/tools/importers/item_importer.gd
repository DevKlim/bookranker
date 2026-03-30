@tool
class_name ItemImporter
extends BaseImporter

func import_items(list: Array) -> void:
	var script = load(ITEM_SCRIPT)
	for entry in list:
		if not entry is Dictionary: continue
		var path = RESOURCE_BASE_PATH + "items/" + str(entry.get("id", "unknown")) + ".tres"
		if not _should_process(str(entry.get("id")), path): continue
		var res = _get_or_create_resource(path, script)
		res.item_name = str(entry.get("name", "Unnamed"))
		if entry.has("texture") and ResourceLoader.exists(entry["texture"]):
			res.icon = load(entry["texture"])
		if entry.has("item_data") and entry["item_data"] is Dictionary:
			var d = entry["item_data"]
			res.damage = d.get("damage", 0.0)
			res.stack_size = d.get("stack", 50)
			res.modifiers = d.get("modifiers", {})
			
			# Use set() to safely assign new properties even if script cache is stale
			res.set("element_units", int(d.get("element_units", 1)))
			res.set("ignore_element_cooldown", bool(d.get("ignore_element_cd", false)))
			
			if d.has("element"):
				var ep = RESOURCE_BASE_PATH + "elements/" + str(d["element"]) + ".tres"
				if ResourceLoader.exists(ep): res.element = load(ep)
				else: res.element = null
		
		# Tool Data
		if entry.has("tool_data") and entry["tool_data"] is Dictionary:
			var td = entry["tool_data"]
			res.is_tool = true
			res.tool_type = td.get("type", "none")
			res.action_time = float(td.get("time", 1.0))
			var off = td.get("offset",[0, 0, 0])
			if off.size() >= 3:
				res.highlight_offset = Vector3(off[0], off[1], off[2])
			else:
				res.highlight_offset = Vector3.ZERO
		else:
			res.is_tool = false
		
		# Attack Config (Weapons)
		if entry.has("attack_config"):
			var ac_data = entry["attack_config"]
			
			# Case 1: Reference to external Attack Resource (String ID)
			if ac_data is String:
				var atk_path = "res://resources/attacks/" + ac_data + ".tres"
				if ResourceLoader.exists(atk_path):
					res.attack_config = load(atk_path)
				else:
					printerr("ItemImporter: Attack resource '%s' not found for item '%s'" %[ac_data, res.item_name])

			# Case 2: Inline definition (Dictionary)
			elif ac_data is Dictionary:
				var atk_res = AttackResource.new()
				atk_res.id = str(entry.get("id")) + "_attack"
				atk_res.base_damage = ac_data.get("base_damage", res.damage)
				atk_res.cooldown = ac_data.get("cooldown", 1.0)
				atk_res.min_range = int(ac_data.get("min_range", 0))
				atk_res.max_range = int(ac_data.get("max_range", 1))
				atk_res.range_width = int(ac_data.get("range_width", 0))
				atk_res.is_aoe = bool(ac_data.get("is_aoe", false))
				atk_res.scaling_stat = ac_data.get("scaling_stat", "attack_damage")
				atk_res.scaling_factor = float(ac_data.get("scaling_factor", 1.0))
				
				if ac_data.has("element"):
					var el_path = RESOURCE_BASE_PATH + "elements/" + str(ac_data["element"]) + ".tres"
					if ResourceLoader.exists(el_path): atk_res.element = load(el_path)
				
				# Projectile Config
				if ac_data.get("spawn_projectile", false):
					atk_res.spawn_projectile = true
					atk_res.projectile_speed = float(ac_data.get("projectile_speed", 10.0))
					if ac_data.has("projectile_color"): atk_res.projectile_color = Color(ac_data["projectile_color"])
					if ac_data.has("projectile_scene"):
						atk_res.projectile_scene = load(ac_data["projectile_scene"])
					else:
						atk_res.projectile_scene = load("res://scenes/entities/projectile.tscn")
				
				_apply_formulas_and_weights(atk_res, ac_data)
				res.attack_config = atk_res
		
		# Equipment Type
		var eq_str = entry.get("equipment_type", "none").to_lower()
		var ItemResClass = load(ITEM_SCRIPT)
		match eq_str:
			"tool": res.equipment_type = ItemResClass.EquipmentType.TOOL
			"weapon": res.equipment_type = ItemResClass.EquipmentType.WEAPON
			"armor": res.equipment_type = ItemResClass.EquipmentType.ARMOR
			"accessory", "artifact": res.equipment_type = ItemResClass.EquipmentType.ACCESSORY
			_: res.equipment_type = ItemResClass.EquipmentType.NONE
		
		res.is_ore = false
		res.ore_block_name = ""
		var file = FileAccess.open("res://data/content/blocks.json", FileAccess.READ)
		if file:
			var json = JSON.new()
			if json.parse(file.get_as_text()) == OK and json.data is Array:
				for b in json.data:
					if b.has("ore_item") and str(b["ore_item"]) == str(entry["id"]):
						res.is_ore = true
						res.ore_block_name = str(b.get("name", ""))
						break

		ResourceSaver.save(res, path)
