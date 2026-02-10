@tool
class_name RecipeImporter
extends BaseImporter

func import_recipes(list: Array) -> void:
	var script = load(RECIPE_SCRIPT)
	for entry in list:
		if not entry is Dictionary: continue
		var path = RESOURCE_BASE_PATH + "recipes/" + str(entry.get("id", "unknown")) + ".tres"
		if not _should_process(str(entry.get("id")), path): continue
		
		var res = _get_or_create_resource(path, script)
		res.recipe_name = str(entry.get("name", "Recipe"))
		res.category = str(entry.get("category", "assembly"))
		res.craft_time = entry.get("time", 1.0)
		res.tier = int(entry.get("tier", 1))
		
		# --- Process Inputs ---
		var inputs_array = []
		if entry.has("inputs") and entry["inputs"] is Dictionary:
			for k in entry["inputs"]:
				var r = _resolve_resource_id(str(k))
				if r:
					inputs_array.append({ "resource": r, "count": int(entry["inputs"][k]) })
		res.inputs = inputs_array

		# --- Process Outputs ---
		var outputs_array = []
		# Support legacy single output fields for convenience
		if entry.has("output"):
			var r = _resolve_resource_id(str(entry["output"]))
			if r:
				var count = int(entry.get("count", 1))
				outputs_array.append({ "resource": r, "count": count })
		# Support explicit outputs map (overrides single if present)
		if entry.has("outputs") and entry["outputs"] is Dictionary:
			outputs_array.clear()
			for k in entry["outputs"]:
				var r = _resolve_resource_id(str(k))
				if r:
					outputs_array.append({ "resource": r, "count": int(entry["outputs"][k]) })
		
		res.outputs = outputs_array

		ResourceSaver.save(res, path)
