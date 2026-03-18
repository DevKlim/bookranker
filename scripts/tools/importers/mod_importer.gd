@tool
class_name ModImporter
extends BaseImporter

func import_mods(list: Array) -> void:
	var script = load("res://scripts/resources/item_resource.gd")
	for entry in list:
		if not entry is Dictionary: continue
		var mod_id = str(entry.get("id", "unknown"))
		var path = "res://resources/mods/" + mod_id + ".tres"
		if not _should_process(mod_id, path): continue
		var res = _get_or_create_resource(path, script)
		res.item_name = str(entry.get("name", "Unnamed Mod"))
		if entry.has("texture") and ResourceLoader.exists(entry["texture"]):
			res.icon = load(entry["texture"])
		
		var ItemResClass = load("res://scripts/resources/item_resource.gd")
		if "MOD" in ItemResClass.EquipmentType.keys():
			res.equipment_type = ItemResClass.EquipmentType.MOD
			
		res.modifiers = {
			"cost": entry.get("cost", 0),
			"type": entry.get("type", "building"),
			"effects": entry.get("effects", {})
		}

		ResourceSaver.save(res, path)
		
		# Generate placeholder script
		var script_path = "res://scripts/modchips/" + mod_id + ".gd"
		if not FileAccess.file_exists(script_path):
			DirAccess.make_dir_recursive_absolute("res://scripts/modchips/")
			var file = FileAccess.open(script_path, FileAccess.WRITE)
			if file:
				file.store_string("extends ModChip\n\nfunc _on_apply() -> void:\n\tpass\n\nfunc _on_remove() -> void:\n\tpass\n")
				file.close()
