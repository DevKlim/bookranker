@tool
class_name EventImporter
extends BaseImporter

func import_events(list: Array) -> void:
	var script = load("res://scripts/resources/event_resource.gd")
	DirAccess.make_dir_recursive_absolute("res://resources/events/")
	
	for entry in list:
		if not entry is Dictionary: continue
		var id = str(entry.get("id", "unknown_event"))
		var path = "res://resources/events/" + id + ".tres"
		
		if not _should_process(id, path): continue
		
		var res = _get_or_create_resource(path, script)
		res.id = id
		res.event_name = str(entry.get("name", "Random Event"))
		res.description = str(entry.get("description", ""))
		
		if entry.has("icon") and ResourceLoader.exists(entry["icon"]):
			res.icon = load(entry["icon"])
		
		res.min_level = int(entry.get("min_level", 1))
		res.weight = float(entry.get("weight", 1.0))
		res.effect_type = str(entry.get("effect_type", ""))
		res.duration = float(entry.get("duration", 0.0))
		
		if entry.has("parameters") and entry["parameters"] is Dictionary:
			res.parameters = entry["parameters"]
		
		ResourceSaver.save(res, path)
		