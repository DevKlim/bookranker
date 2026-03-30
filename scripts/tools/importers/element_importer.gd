@tool
class_name ElementImporter
extends BaseImporter

func import_elements(list: Array) -> void:
	var script = load(ELEMENT_SCRIPT)
	for entry in list:
		if not entry is Dictionary: continue
		var path = RESOURCE_BASE_PATH + "elements/" + str(entry.get("id", "unknown")) + ".tres"
		if not _should_process(str(entry.get("id")), path): continue
		
		var res = _get_or_create_resource(path, script)
		res.element_name = str(entry.get("name", "Element"))
		if entry.has("color"):
			res.color = Color(entry["color"])
		res.duration = float(entry.get("duration", 5.0))
		res.application_cooldown = float(entry.get("cooldown", 0.0))
		res.reaction_rules = entry.get("reactions", {})
		res.stat_modifiers = entry.get("effects", {})
		
		_apply_formulas_and_weights(res, entry)
		
		ResourceSaver.save(res, path)
