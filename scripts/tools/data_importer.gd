@tool
extends Node

## Main orchestrator for content import.
## Delegates work to specific importer scripts found in scripts/tools/importers/.

@export var import_data: bool = false:
	set(value):
		if value:
			_run_import()
		import_data = false

@export var clean_up_data: bool = false:
	set(value):
		if value:
			_run_cleanup()
		clean_up_data = false

@export_enum("All", "Elements", "Items", "Buildables", "Recipes", "Enemies", "Allies", "Blocks", "Debug", "Clutter", "Attacks", "Events", "Mods") var target_category: String = "All":
	set(value):
		if target_category != value:
			target_category = value
			target_item_id = "All"
			notify_property_list_changed()

var target_item_id: String = "All"
@export var overwrite_existing: bool = false
@export var only_update_resources: bool = false
@export var mesh_library_path: String = "res://resources/mesh_library.tres"

const IMPORTER_BASE = "res://scripts/tools/importers/"
const CONTENT_DIR = "res://data/content/"
const RESOURCE_BASE_PATH = "res://resources/"

func _get_property_list() -> Array:
	var properties =[]
	var options = ["All"]
	
	if target_category != "All":
		var key_map = {
			"Elements": "elements", "Items": "items", "Blocks": "blocks",
			"Debug": "debug", "Recipes": "recipes", "Enemies": "enemies",
			"Allies": "allies", "Clutter": "clutter", "Attacks": "attacks",
			"Buildables": ["buildings", "wires"], "Events": "events", "Mods": "mods"
		}
		
		if key_map.has(target_category):
			var keys = key_map[target_category]
			if keys is Array:
				for k in keys: _collect_ids(_load_json_safe(k), options)
			else:
				_collect_ids(_load_json_safe(keys), options)

	properties.append({
		"name": "target_item_id",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(options)
	})
	
	return properties

func _collect_ids(data, out_array: Array) -> void:
	if typeof(data) == TYPE_ARRAY:
		for entry in data:
			if entry is Dictionary and entry.has("id"):
				out_array.append(str(entry["id"]))

func _load_json_safe(section: String):
	var path = CONTENT_DIR + section + ".json"
	if not FileAccess.file_exists(path): return null
	var file = FileAccess.open(path, FileAccess.READ)
	if not file: return null
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK: return json.data
	return null

func _get_importer(script_name: String):
	var script_path = IMPORTER_BASE + script_name
	if not ResourceLoader.exists(script_path):
		printerr("Importer script not found: " + script_path)
		return null
		
	var script = load(script_path)
	if script is Script:
		if script.can_instantiate():
			return script.new(target_item_id, overwrite_existing, only_update_resources)
		else:
			printerr("Importer script cannot be instantiated (syntax error?): " + script_name)
	else:
		printerr("Failed to load importer script: " + script_name)
	return null

func _run_import() -> void:
	print("--- Starting 3D Data Import [%s] ---" % target_category)
	_make_dirs()

	var run_imp = func(cat: String, script: String, method: String, file: String = ""):
		if target_category == "All" or target_category == cat:
			var data = _load_json_safe(file if file != "" else cat.to_lower())
			if data:
				var imp = _get_importer(script)
				if imp: imp.call(method, data)

	run_imp.call("Elements", "element_importer.gd", "import_elements")
	run_imp.call("Attacks", "attack_importer.gd", "import_attacks")
	run_imp.call("Items", "item_importer.gd", "import_items")
	run_imp.call("Mods", "mod_importer.gd", "import_mods")
	
	if target_category == "All" or target_category == "Blocks":
		var data = _load_json_safe("blocks")
		if data:
			var block_imp = _get_importer("block_importer.gd")
			if block_imp: block_imp.import_blocks(data, mesh_library_path)
			
	run_imp.call("Debug", "block_importer.gd", "import_debug_blocks")
	
	if target_category == "All" or target_category == "Buildables":
		var build_imp = _get_importer("buildable_importer.gd")
		if build_imp:
			var b_data = _load_json_safe("buildings")
			if b_data: build_imp.import_buildables(b_data, "building")
			var w_data = _load_json_safe("wires")
			if w_data: build_imp.import_buildables(w_data, "wire")
			
	run_imp.call("Recipes", "recipe_importer.gd", "import_recipes")
	run_imp.call("Enemies", "enemy_importer.gd", "import_enemies")
	run_imp.call("Allies", "ally_importer.gd", "import_allies")
	run_imp.call("Clutter", "clutter_importer.gd", "import_clutter")
	run_imp.call("Events", "event_importer.gd", "import_events")
	
	print("--- Data Import Complete ---")
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()

func _make_dirs() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/items/")
	DirAccess.make_dir_recursive_absolute("res://assets/ores/")
	DirAccess.make_dir_recursive_absolute("res://assets/buildables/")
	DirAccess.make_dir_recursive_absolute(CONTENT_DIR)
	for d in["elements/", "items/", "buildables/", "recipes/", "enemies/", "allies/", "clutter/", "attacks/", "events/", "mods/"]:
		DirAccess.make_dir_recursive_absolute(RESOURCE_BASE_PATH + d)
	DirAccess.make_dir_recursive_absolute("res://scenes/buildables/")
	DirAccess.make_dir_recursive_absolute("res://scenes/enemies/")
	DirAccess.make_dir_recursive_absolute("res://scenes/allies/")
	DirAccess.make_dir_recursive_absolute("res://scenes/clutter/")
	DirAccess.make_dir_recursive_absolute("res://scenes/attacks/")

func _run_cleanup() -> void:
	print("--- Starting Orphan Cleanup ---")
	
	var get_valid = func(key: String) -> Array:
		var ids =[]
		var data = _load_json_safe(key)
		if data is Array:
			for item in data: ids.append(str(item["id"]))
		return ids
	
	var clean_folder = func(path: String, valid: Array):
		var dir = DirAccess.open(path)
		if not dir: return
		dir.list_dir_begin()
		var file = dir.get_next()
		while file != "":
			if not dir.current_is_dir() and file.ends_with(".tres"):
				var id = file.get_basename()
				if not id in valid:
					print("Cleanup: Deleting %s (Not in manifest)" % file)
					dir.remove(file)
			file = dir.get_next()
	
	if target_category == "All" or target_category == "Recipes":
		clean_folder.call(RESOURCE_BASE_PATH + "recipes/", get_valid.call("recipes"))
	if target_category == "All" or target_category == "Items":
		clean_folder.call(RESOURCE_BASE_PATH + "items/", get_valid.call("items"))
	if target_category == "All" or target_category == "Mods":
		clean_folder.call(RESOURCE_BASE_PATH + "mods/", get_valid.call("mods"))
	if target_category == "All" or target_category == "Elements":
		clean_folder.call(RESOURCE_BASE_PATH + "elements/", get_valid.call("elements"))
	if target_category == "All" or target_category == "Attacks":
		clean_folder.call(RESOURCE_BASE_PATH + "attacks/", get_valid.call("attacks"))
	if target_category == "All" or target_category == "Clutter":
		clean_folder.call(RESOURCE_BASE_PATH + "clutter/", get_valid.call("clutter"))
	if target_category == "All" or target_category == "Allies":
		clean_folder.call(RESOURCE_BASE_PATH + "allies/", get_valid.call("allies"))
	if target_category == "All" or target_category == "Events":
		clean_folder.call(RESOURCE_BASE_PATH + "events/", get_valid.call("events"))
		
	print("--- Cleanup Complete ---")
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()
