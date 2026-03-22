@tool
class_name BuildableImporter
extends BaseImporter

func import_buildables(list: Array, _category: String) -> void:
	var script = load(BUILDABLE_SCRIPT)
	for entry in list:
		if not entry is Dictionary: continue
		var path = RESOURCE_BASE_PATH + "buildables/" + str(entry.get("id", "unknown")) + ".tres"
		if not _should_process(str(entry.get("id")), path): continue
		
		var res = _get_or_create_resource(path, script)
		if "scene" in res: res.scene = null 

		var new_scene_path = ""
		var expected_scene_path = SCENE_BUILDABLES_PATH + str(entry.get("id")) + ".tscn"
		
		# Always generate if structure, visuals or template exists.
		if entry.has("visuals") or entry.has("structure") or entry.has("template"):
			new_scene_path = expected_scene_path
			_generate_building_scene(entry, new_scene_path)
		elif ResourceLoader.exists(expected_scene_path):
			# Fallback to existing manually-created scene
			new_scene_path = expected_scene_path
			
		res.buildable_name = str(entry.get("name", "Unnamed"))
		res.description = str(entry.get("description", ""))
		
		var tex_path = ""
		if entry.has("structure") and not entry["structure"].is_empty():
			tex_path = entry["structure"][0].get("texture", "")
		elif entry.has("texture"): tex_path = entry["texture"]
		elif entry.has("visuals") and entry["visuals"].has("texture"): tex_path = entry["visuals"]["texture"]
		
		if tex_path != "" and ResourceLoader.exists(tex_path):
			res.icon = load(tex_path)
		
		res.width = 1
		res.height = 1
		if entry.has("grid") and entry["grid"] is Dictionary:
			res.width = entry["grid"].get("width", 1)
			res.height = entry["grid"].get("height", 1)
			res.layer = 0 if entry["grid"].get("layer") == "wire" else 1
		elif entry.has("structure"):
			var min_x = 0; var max_x = 0; var min_z = 0; var max_z = 0
			for part in entry["structure"]:
				var off = part.get("offset",[0,0])
				min_x = min(min_x, off[0]); max_x = max(max_x, off[0])
				min_z = min(min_z, off[1]); max_z = max(max_z, off[1])
			res.width = (max_x - min_x) + 1
			res.height = (max_z - min_z) + 1
		elif entry.has("visuals") and entry["visuals"].has("width") and entry["visuals"].has("height"):
			var w_px = entry["visuals"].get("width", 32)
			var h_px = entry["visuals"].get("height", 32)
			res.width = max(1, int(w_px / 32))
			res.height = max(1, int(h_px / 32))
			
		if entry.has("logic") and entry["logic"] is Dictionary:
			res.has_input = entry["logic"].get("has_input", false)
			res.has_output = entry["logic"].get("has_output", false)
			var io_config = entry["logic"].get("io_config", {})
			res.default_input_mask = _parse_io_mask(io_config.get("input",["all"]))
			res.default_output_mask = _parse_io_mask(io_config.get("output", ["all"]))
		
		res.display_offset = Vector2.ZERO 
		if new_scene_path != "":
			res.scene = ResourceLoader.load(new_scene_path, "", ResourceLoader.CACHE_MODE_REPLACE)
		ResourceSaver.save(res, path)

func _generate_building_scene(data: Dictionary, save_path: String) -> void:
	var inst = StaticBody3D.new()
	inst.name = str(data.get("name", "GeneratedBuilding"))
	var template_path = data.get("template")
	if template_path and ResourceLoader.exists(template_path):
		var temp_res = load(template_path)
		var temp_inst = temp_res.instantiate()
		inst.set_script(temp_inst.get_script()) 
		temp_inst.free()
	else:
		inst.set_script(load("res://scripts/entities/base_building.gd"))
	
	var visual_parent = inst
	var logic = data.get("logic", {})
	if logic.get("rotates", false):
		var rot = Node3D.new()
		rot.name = "Rotatable"
		inst.add_child(rot)
		visual_parent = rot
	
	var layout_config: Array[Vector2i] =[]
	if data.has("structure"):
		var structure_list = data["structure"]
		var pivot_shift = Vector2i.ZERO
		for part in structure_list:
			if part.get("is_center", false):
				var off = part.get("offset",[0, 0])
				pivot_shift = Vector2i(off[0], off[1])
				break
		var idx = 0
		for part in structure_list:
			var raw_offset = part.get("offset",[0, 0])
			var final_offset = Vector2i(raw_offset[0], raw_offset[1]) - pivot_shift
			layout_config.append(final_offset)
			var pos_offset = Vector3(final_offset.x, 0, final_offset.y)
			var mi = MeshInstance3D.new()
			mi.name = "Block_%d" % idx
			mi.mesh = _create_advanced_block_mesh(part.get("texture", ""), Vector3(1, 1, 1), false, true)
			mi.position = pos_offset
			mi.rotation_degrees.y = part.get("rotation", 0)
			visual_parent.add_child(mi)
			var col = CollisionShape3D.new()
			col.name = "Collision_%d" % idx
			var shape = BoxShape3D.new()
			shape.size = Vector3(1, 1, 1)
			col.position = pos_offset + Vector3(0, 1, 0)
			col.shape = shape
			inst.add_child(col)
			idx += 1
	else:
		var width = 1
		var height = 1
		if data.has("grid") and data["grid"].has("width"):
			width = data["grid"].get("width", 1)
			height = data["grid"].get("height", 1)
		elif data.has("dimensions"):
			width = data["dimensions"][0]
			height = data["dimensions"][2] 
		elif data.has("visuals") and data["visuals"].has("width"):
			width = max(1, int(data["visuals"].get("width", 32) / 32.0))
			height = max(1, int(data["visuals"].get("height", 32) / 32.0))
			
		var vis_data = data.get("visuals", {})
		var type = vis_data.get("type", "block") # Default to block
		
		if type == "sprite":
			_add_visuals(visual_parent, vis_data)
		else:
			var tex_path = vis_data.get("texture", "")
			var mi = MeshInstance3D.new()
			mi.name = "BlockVisual"
			mi.mesh = _create_advanced_block_mesh(tex_path, Vector3(width, 1, height), false, true)
			mi.position = Vector3((width - 1) * 0.5, 0, (height - 1) * 0.5)
			visual_parent.add_child(mi)

		for x in range(width):
			for y in range(height):
				layout_config.append(Vector2i(x, y))

		var col = CollisionShape3D.new()
		col.name = "CollisionShape3D"
		var shape = BoxShape3D.new()
		shape.size = Vector3(width, 1, height)
		col.position = Vector3((width - 1) * 0.5, 0.5, (height - 1) * 0.5)
		col.shape = shape
		inst.add_child(col)

	_apply_param(inst, "layout_config", layout_config)
	if logic.get("targeting", false):
		var tac = _add_component(inst, COMP_TARGET, "TargetAcquirerComponent")
		tac.target_layers = 1
		var area = Area3D.new()
		area.name = "DetectionArea"
		var s = SphereShape3D.new()
		s.radius = 5.0
		var c = CollisionShape3D.new()
		c.name = "Shape"
		c.shape = s
		area.add_child(c)
		tac.add_child(area)
	
	if logic.get("processing", false):
		_add_component(inst, COMP_CRAFTER, "CrafterComponent")

	if logic.get("emit_projectile", false) or logic.get("shooting", false) or logic.has("attack_config"):
		var attacker = _add_component(inst, COMP_SHOOTER, "AttackerComponent") 
		
		if logic.has("attack_config"):
			var atk_path = "res://resources/attacks/" + str(logic["attack_config"]) + ".tres"
			if ResourceLoader.exists(atk_path):
				attacker.basic_attack = load(atk_path)

		var marker = Marker3D.new()
		marker.name = "ProjectileOrigin"
		marker.position = Vector3(0, 0.5, 0.6)
		visual_parent.add_child(marker)

	if logic.has("inventory") and logic["inventory"] is Dictionary:
		var inv_data = logic["inventory"]
		var inv = _add_component(inst, COMP_INVENTORY, "InventoryComponent")
		inv.max_slots = inv_data.get("slots", 1)
		inv.slot_capacity = inv_data.get("capacity", 50)
		inv.can_receive = inv_data.get("can_receive", true)
		inv.can_output = inv_data.get("can_output", true)
		inv.omni_directional = inv_data.get("omni", false)
		if inv_data.has("whitelist") and inv_data["whitelist"] is Array:
			var allowed: Array[Resource] =[]
			for item_id in inv_data["whitelist"]:
				var p = RESOURCE_BASE_PATH + "items/" + str(item_id) + ".tres"
				if ResourceLoader.exists(p): allowed.append(load(p))
			if not allowed.is_empty(): inv.set("allowed_items", allowed)
		if inv_data.has("blacklist") and inv_data["blacklist"] is Array:
			var denied: Array[Resource] =[]
			for item_id in inv_data["blacklist"]:
				var p = RESOURCE_BASE_PATH + "items/" + str(item_id) + ".tres"
				if ResourceLoader.exists(p): denied.append(load(p))
			if not denied.is_empty(): inv.set("denied_items", denied)
	
	_add_component(inst, COMP_ELEMENTAL, "ElementalComponent")
	
	_apply_logic_params(inst, data)
	if logic.has("power_cost"):
		_apply_param(inst, "power_consumption", float(logic["power_cost"]))
	if logic.has("health"):
		_apply_param(inst, "max_health", float(logic["health"]))
	if logic.has("stats"):
		_apply_param(inst, "stats", logic["stats"])
		
	if logic.has("io_config"):
		var io = logic["io_config"]
		var i_mask = _parse_io_mask(io.get("input", ["all"]))
		var o_mask = _parse_io_mask(io.get("output", ["all"]))
		_apply_param(inst, "default_input_mask", i_mask)
		_apply_param(inst, "default_output_mask", o_mask)
	_save_scene(inst, save_path)
