@tool
class_name ClutterImporter
extends BaseImporter

func import_clutter(list: Array) -> void:
	var script = load(CLUTTER_SCRIPT)
	for entry in list:
		if not entry is Dictionary: continue
		var path = RESOURCE_BASE_PATH + "clutter/" + str(entry.get("id", "unknown")) + ".tres"
		if not _should_process(str(entry.get("id")), path): continue
		
		# Generate the Scene for the clutter object
		var new_scene_path = SCENE_CLUTTER_PATH + str(entry.get("id")) + ".tscn"
		_generate_clutter_scene(entry, new_scene_path)
		
		var res = _get_or_create_resource(path, script)
		res.id = str(entry.get("id"))
		res.scene = load(new_scene_path)
		
		# Drops
		if entry.has("drops"):
			var drops = entry["drops"]
			var drop_id = drops.get("item", "")
			if drop_id != "":
				var i_res = _resolve_resource_id(drop_id)
				if i_res:
					res.drop_item = i_res
			res.drop_count = int(drops.get("count", 1))
		
		# Generation
		if entry.has("generation"):
			var gen = entry["generation"]
			res.min_depth = int(gen.get("min_depth", 0))
			res.max_depth = int(gen.get("max_depth", 30))
			res.rarity = float(gen.get("rarity", 0.1))
		
		ResourceSaver.save(res, path)

func _generate_clutter_scene(data: Dictionary, save_path: String) -> void:
	var inst = StaticBody3D.new()
	inst.name = str(data.get("name", "GeneratedClutter"))
	inst.set_script(load(ENTITY_CLUTTER_SCRIPT))
	
	# Create visuals
	var mi = MeshInstance3D.new()
	mi.name = "Visual"
	var block_tex = data.get("block_texture", "")
	mi.mesh = _create_advanced_block_mesh(block_tex, Vector3(1, 1, 1), false, true)
	inst.add_child(mi)
	
	# Create Collision
	var col = CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var box = BoxShape3D.new()
	box.size = Vector3(1, 1, 1)
	col.shape = box
	col.position = Vector3(0, 0.5, 0)
	inst.add_child(col)
	
	_add_component(inst, COMP_HEALTH, "HealthComponent")
	_add_component(inst, COMP_ELEMENTAL, "ElementalComponent")
	
	# Fix: Add GridComponent so it blocks building placement
	var grid = _add_component(inst, COMP_GRID, "GridComponent")
	grid.layer = "building"
	grid.snap_to_grid = true
	
	_save_scene(inst, save_path)
