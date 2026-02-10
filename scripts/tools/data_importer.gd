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

@export_enum("All", "Elements", "Items", "Buildables", "Recipes", "Enemies", "Allies", "Blocks", "Debug", "Clutter", "Attacks") var target_category: String = "All":
	set(value):
		if target_category != value:
			target_category = value
			target_item_id = "All"
			notify_property_list_changed()

var target_item_id: String = "All"
@export var overwrite_existing: bool = false
@export var mesh_library_path: String = "res://resources/mesh_library.tres"

const IMPORTER_BASE = "res://scripts/tools/importers/"
const JSON_PATH = "res://data/content_manifest.json"
const RESOURCE_BASE_PATH = "res://resources/"

func _get_property_list() -> Array:
	var properties = []
	var options = ["All"]
	
	if target_category != "All":
		var temp_data = _load_json_safe()
		if temp_data is Dictionary:
			var key_map = {
				"Elements": "elements", "Items": "items", "Blocks": "blocks",
				"Debug": "debug", "Recipes": "recipes", "Enemies": "enemies",
				"Allies": "allies", "Clutter": "clutter", "Attacks": "attacks",
				"Buildables": ["buildings", "wires"]
			}
			
			if key_map.has(target_category):
				var keys = key_map[target_category]
				if keys is Array:
					for k in keys: _collect_ids(temp_data, k, options)
				else:
					_collect_ids(temp_data, keys, options)

	properties.append({
		"name": "target_item_id",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(options)
	})
	
	return properties

func _collect_ids(data: Dictionary, key: String, out_array: Array) -> void:
	if data.has(key) and data[key] is Array:
		for entry in data[key]:
			if entry is Dictionary and entry.has("id"):
				out_array.append(str(entry["id"]))

func _load_json_safe():
	if not FileAccess.file_exists(JSON_PATH): return null
	var file = FileAccess.open(JSON_PATH, FileAccess.READ)
	if not file: return null
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK: return json.data
	return null

func _run_import() -> void:
	print("--- Starting 3D Data Import [%s] ---" % target_category)
	var raw_data = _load_json_safe()
	if not (raw_data is Dictionary):
		printerr("Failed to load JSON manifest.")
		return
	var data: Dictionary = raw_data
	
	_make_dirs()

	# Instantiate Importers
	var elem_imp = load(IMPORTER_BASE + "element_importer.gd").new(target_item_id, overwrite_existing)
	var attack_imp = load(IMPORTER_BASE + "attack_importer.gd").new(target_item_id, overwrite_existing)
	var item_imp = load(IMPORTER_BASE + "item_importer.gd").new(target_item_id, overwrite_existing)
	var block_imp = load(IMPORTER_BASE + "block_importer.gd").new(target_item_id, overwrite_existing)
	var recipe_imp = load(IMPORTER_BASE + "recipe_importer.gd").new(target_item_id, overwrite_existing)
	var build_imp = load(IMPORTER_BASE + "buildable_importer.gd").new(target_item_id, overwrite_existing)
	var enemy_imp = load(IMPORTER_BASE + "enemy_importer.gd").new(target_item_id, overwrite_existing)
	var ally_imp = load(IMPORTER_BASE + "ally_importer.gd").new(target_item_id, overwrite_existing)
	var clutter_imp = load(IMPORTER_BASE + "clutter_importer.gd").new(target_item_id, overwrite_existing)

	# Process Order: Elements -> Attacks -> Items -> Others
	
	if (target_category == "All" or target_category == "Elements") and data.has("elements"):
		elem_imp.import_elements(data["elements"])

	if (target_category == "All" or target_category == "Attacks") and data.has("attacks"):
		attack_imp.import_attacks(data["attacks"])

	if (target_category == "All" or target_category == "Items") and data.has("items"):
		item_imp.import_items(data["items"])
		
	if (target_category == "All" or target_category == "Blocks") and data.has("blocks"):
		block_imp.import_blocks(data["blocks"], mesh_library_path)
		
	if (target_category == "All" or target_category == "Debug") and data.has("debug"):
		block_imp.import_debug_blocks(data["debug"])
		
	if (target_category == "All" or target_category == "Buildables"):
		if data.has("buildings"): build_imp.import_buildables(data["buildings"], "building")
		if data.has("wires"): build_imp.import_buildables(data["wires"], "wire")
		
	if (target_category == "All" or target_category == "Recipes") and data.has("recipes"):
		recipe_imp.import_recipes(data["recipes"])
		
	if (target_category == "All" or target_category == "Enemies") and data.has("enemies"):
		enemy_imp.import_enemies(data["enemies"])
		
	if (target_category == "All" or target_category == "Allies") and data.has("allies"):
		ally_imp.import_allies(data["allies"])
		
	if (target_category == "All" or target_category == "Clutter") and data.has("clutter"):
		clutter_imp.import_clutter(data["clutter"])
	
	print("--- Data Import Complete ---")
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()

func _make_dirs() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/items/")
	DirAccess.make_dir_recursive_absolute("res://assets/ores/")
	DirAccess.make_dir_recursive_absolute("res://assets/buildables/")
	for d in ["elements/", "items/", "buildables/", "recipes/", "enemies/", "allies/", "clutter/", "attacks/"]:
		DirAccess.make_dir_recursive_absolute(RESOURCE_BASE_PATH + d)
	DirAccess.make_dir_recursive_absolute("res://scenes/buildables/")
	DirAccess.make_dir_recursive_absolute("res://scenes/enemies/")
	DirAccess.make_dir_recursive_absolute("res://scenes/allies/")
	DirAccess.make_dir_recursive_absolute("res://scenes/clutter/")
	DirAccess.make_dir_recursive_absolute("res://scenes/attacks/")

func _run_cleanup() -> void:
	print("--- Starting Orphan Cleanup ---")
	var data = _load_json_safe()
	if not (data is Dictionary): return
	
	var get_valid = func(key: String) -> Array:
		var ids = []
		if data.has(key):
			for item in data[key]: ids.append(str(item["id"]))
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
	if target_category == "All" or target_category == "Elements":
		clean_folder.call(RESOURCE_BASE_PATH + "elements/", get_valid.call("elements"))
	if target_category == "All" or target_category == "Attacks":
		clean_folder.call(RESOURCE_BASE_PATH + "attacks/", get_valid.call("attacks"))
	if target_category == "All" or target_category == "Clutter":
		clean_folder.call(RESOURCE_BASE_PATH + "clutter/", get_valid.call("clutter"))
	if target_category == "All" or target_category == "Allies":
		clean_folder.call(RESOURCE_BASE_PATH + "allies/", get_valid.call("allies"))
		
	print("--- Cleanup Complete ---")
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()
