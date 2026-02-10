@tool
class_name AttackImporter
extends BaseImporter

func import_attacks(list: Array) -> void:
	var script = load("res://scripts/resources/attack_resource.gd")
	
	DirAccess.make_dir_recursive_absolute("res://resources/attacks/")
	
	for entry in list:
		if not entry is Dictionary: continue
		var id = str(entry.get("id", "unknown_attack"))
		var path = "res://resources/attacks/" + id + ".tres"
		
		if not _should_process(id, path): continue
		
		var res = _get_or_create_resource(path, script)
		res.id = id
		
		res.cooldown = float(entry.get("cooldown", 1.0))
		res.animation_name = str(entry.get("animation_name", "attack"))
		
		res.base_damage = float(entry.get("damage", 10.0))
		res.scaling_stat = str(entry.get("scaling_stat", "attack_damage"))
		res.scaling_factor = float(entry.get("scaling_factor", 1.0))
		
		# Range
		res.min_range = int(entry.get("min_range", 0))
		res.max_range = int(entry.get("max_range", 1))
		res.range_width = int(entry.get("range_width", 0))
		res.is_aoe = bool(entry.get("is_aoe", false))
		
		# Visuals
		if entry.has("visual_scene"):
			var scene_path = entry["visual_scene"]
			if ResourceLoader.exists(scene_path):
				res.visual_scene = load(scene_path)
		
		res.visual_spawn_point = int(entry.get("spawn_point", 0))
		res.attach_visual_to_source = bool(entry.get("attach_to_source", false))
		var off = entry.get("offset", [0, 0.5, 0])
		if off.size() >= 3:
			res.visual_offset = Vector3(off[0], off[1], off[2])
			
		res.visual_duration = float(entry.get("visual_duration", 0.5))
		
		ResourceSaver.save(res, path)
