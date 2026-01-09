@tool
extends Node

## Click this bool in the inspector to run the import process.
@export var import_data: bool = false:
	set(value):
		if value:
			_run_import()
		import_data = false

## Click this bool to clean up files/blocks that are NOT in the manifest.
@export var clean_up_data: bool = false:
	set(value):
		if value:
			_run_cleanup()
		clean_up_data = false

@export_enum("All", "Elements", "Items", "Buildables", "Recipes", "Enemies", "Blocks", "Debug") var target_category: String = "All":
	set(value):
		if target_category != value:
			target_category = value
			target_item_id = "All" # Reset selection when category changes
			notify_property_list_changed()

## Selected specific ID to import. Populated dynamically based on category.
var target_item_id: String = "All"

@export var overwrite_existing: bool = false
@export var mesh_library_path: String = "res://resources/mesh_library.tres"

const DEBUG_MESH_LIBRARY_PATH = "res://resources/debug_mesh_library.tres"
const JSON_PATH = "res://data/content_manifest.json"
const RESOURCE_BASE_PATH = "res://resources/"

# Target folders for generated scenes
const SCENE_BUILDABLES_PATH = "res://scenes/buildables/"
const SCENE_ENEMIES_PATH = "res://scenes/enemies/"
const SCENE_GEN_BASE = "res://scenes/generated/" # Fallback

const ELEMENT_SCRIPT = "res://scripts/resources/element_resource.gd"
const ITEM_SCRIPT = "res://scripts/resources/item_resource.gd"
const RECIPE_SCRIPT = "res://scripts/resources/recipe_resource.gd"
const ENEMY_SCRIPT = "res://scripts/resources/enemy_resource.gd"
const BUILDABLE_SCRIPT = "res://scripts/resources/buildable_resource.gd"

# Component Script Paths
const COMP_SHOOTER = "res://scripts/components/shooter_component.gd"
const COMP_TARGET = "res://scripts/components/target_acquirer_component.gd"
const COMP_HEALTH = "res://scripts/components/health_component.gd"
const COMP_ATTACKER = "res://scripts/components/attacker_component.gd"
const COMP_MOVE = "res://scripts/components/move_component.gd"
const COMP_INVENTORY = "res://scripts/components/inventory_component.gd"
const ENTITY_ENEMY_SCRIPT = "res://scripts/entities/enemy.gd"

func _get_property_list() -> Array:
	var properties = []
	var options = ["All"]
	
	if target_category != "All":
		var temp_data = _load_json_safe()
		if temp_data is Dictionary:
			match target_category:
				"Elements": _collect_ids(temp_data, "elements", options)
				"Items": _collect_ids(temp_data, "items", options)
				"Blocks": _collect_ids(temp_data, "blocks", options)
				"Debug": _collect_ids(temp_data, "debug", options)
				"Recipes": _collect_ids(temp_data, "recipes", options)
				"Enemies": _collect_ids(temp_data, "enemies", options)
				"Buildables":
					_collect_ids(temp_data, "buildings", options)
					_collect_ids(temp_data, "wires", options)

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
	
	# Create necessary directories
	for d in ["elements/", "items/", "buildables/", "recipes/", "enemies/"]:
		DirAccess.make_dir_recursive_absolute(RESOURCE_BASE_PATH + d)
	
	DirAccess.make_dir_recursive_absolute(SCENE_GEN_BASE)
	DirAccess.make_dir_recursive_absolute(SCENE_BUILDABLES_PATH)
	DirAccess.make_dir_recursive_absolute(SCENE_ENEMIES_PATH)

	if (target_category == "All" or target_category == "Elements") and data.has("elements"):
		_import_elements(data["elements"], target_category)
	if (target_category == "All" or target_category == "Items") and data.has("items"):
		_import_items(data["items"], target_category)
	if (target_category == "All" or target_category == "Blocks") and data.has("blocks"):
		_import_blocks(data["blocks"], target_category)
	if (target_category == "All" or target_category == "Debug") and data.has("debug"):
		_import_debug_blocks(data["debug"], target_category)
	if (target_category == "All" or target_category == "Buildables"):
		if data.has("buildings"): _import_buildables(data["buildings"], "building", target_category)
		if data.has("wires"): _import_buildables(data["wires"], "wire", target_category)
	if (target_category == "All" or target_category == "Recipes") and data.has("recipes"):
		_import_recipes(data["recipes"], target_category)
	if (target_category == "All" or target_category == "Enemies") and data.has("enemies"):
		_import_enemies(data["enemies"], target_category)
	
	print("--- Data Import Complete ---")
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()

func _run_cleanup() -> void:
	print("--- Cleanup Logic Skipped for Brevity ---")

# --- Import Handlers ---

func _import_buildables(list, _category, target):
	var script = load(BUILDABLE_SCRIPT)
	for entry in list:
		if not entry is Dictionary: continue
		var path = RESOURCE_BASE_PATH + "buildables/" + str(entry.get("id", "unknown")) + ".tres"
		if not _should_process(str(entry.get("id")), path, target): continue
		
		var new_scene_path = ""
		# Generate scene if template + visuals/structure exist
		if entry.has("template") and (entry.has("visuals") or entry.has("structure")):
			new_scene_path = SCENE_BUILDABLES_PATH + str(entry.get("id")) + ".tscn"
			print("Generating Buildable Scene: " + str(entry.get("id")))
			_generate_building_scene(entry, new_scene_path)
			
		var res = _get_or_create_resource(path, script)
		res.buildable_name = str(entry.get("name", "Unnamed"))
		res.description = str(entry.get("description", ""))
		
		var tex_path = ""
		if entry.has("structure") and not entry["structure"].is_empty():
			tex_path = entry["structure"][0].get("texture", "")
		elif entry.has("texture"): tex_path = entry["texture"]
		elif entry.has("visuals") and entry["visuals"].has("texture"): tex_path = entry["visuals"]["texture"]
		
		if tex_path != "" and ResourceLoader.exists(tex_path):
			res.icon = load(tex_path)
		else:
			res.icon = null
		
		# Dimension Parsing
		res.width = 1
		res.height = 1
		
		if entry.has("grid") and entry["grid"] is Dictionary:
			res.width = entry["grid"].get("width", 1)
			res.height = entry["grid"].get("height", 1)
			res.layer = 0 if entry["grid"].get("layer") == "wire" else 1
		elif entry.has("structure"):
			# Auto-calculate bounding box from structure offsets
			var min_x = 0; var max_x = 0; var min_z = 0; var max_z = 0
			for part in entry["structure"]:
				var off = part.get("offset", [0,0])
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
			
			# Parse IO Masks
			var io_config = entry["logic"].get("io_config", {})
			res.default_input_mask = _parse_io_mask(io_config.get("input", ["all"]))
			res.default_output_mask = _parse_io_mask(io_config.get("output", ["all"]))
		
		res.display_offset = Vector2.ZERO 
			
		if new_scene_path != "":
			res.scene = ResourceLoader.load(new_scene_path, "", ResourceLoader.CACHE_MODE_REPLACE)
			
		ResourceSaver.save(res, path)

func _parse_io_mask(directions_array: Array) -> int:
	var mask = 0
	# 0: Down (Back/+Z), 1: Left (-X), 2: Up (Front/-Z), 3: Right (+X)
	# Bitmask: 1<<0, 1<<1, 1<<2, 1<<3
	
	if "all" in directions_array: return 15 # 1111
	if "none" in directions_array: return 0
	
	for d in directions_array:
		match d:
			"back", "down": mask |= (1 << 0)
			"left": mask |= (1 << 1)
			"front", "up": mask |= (1 << 2)
			"right": mask |= (1 << 3)
	return mask

func _import_enemies(list, target):
	var script = load(ENEMY_SCRIPT)
	for entry in list:
		if not entry is Dictionary: continue
		var path = RESOURCE_BASE_PATH + "enemies/" + str(entry.get("id", "unknown")) + ".tres"
		if not _should_process(str(entry.get("id")), path, target): continue
		
		var new_scene_path = ""
		if entry.has("scene_path"):
			new_scene_path = SCENE_ENEMIES_PATH + str(entry.get("id")) + ".tscn"
			print("Generating Enemy Scene Wrapper: " + str(entry.get("id")))
			_generate_enemy_scene(entry, new_scene_path)
		
		var res = _get_or_create_resource(path, script)
		res.enemy_name = str(entry.get("name", "Enemy"))
		
		if new_scene_path != "":
			res.scene = ResourceLoader.load(new_scene_path, "", ResourceLoader.CACHE_MODE_REPLACE)
		elif entry.has("template") and ResourceLoader.exists(entry["template"]):
			res.scene = load(entry["template"])
			
		if entry.has("logic") and entry["logic"] is Dictionary:
			res.health = entry["logic"].get("health", 50.0)
			res.speed = entry["logic"].get("speed", 50.0)
			res.defense = entry["logic"].get("defense", 0.0)
			res.elemental_resistances = entry["logic"].get("resistances", {})
			
		if entry.has("params") and entry["params"] is Dictionary:
			res.attack_damage = entry["params"].get("attack_damage", 10.0)
			res.attack_speed = entry["params"].get("attack_speed", 1.0)
			
		if entry.has("drops") and entry["drops"] is Array:
			res.drops = entry["drops"]

		ResourceSaver.save(res, path)

func _import_blocks(list, _target):
	var lib: MeshLibrary
	if ResourceLoader.exists(mesh_library_path):
		lib = load(mesh_library_path)
	else:
		lib = MeshLibrary.new()
	
	_populate_library_from_list(lib, list, _target)
	
	ResourceSaver.save(lib, mesh_library_path)
	print("Updated MeshLibrary at: " + mesh_library_path)

func _import_debug_blocks(list, _target):
	var lib: MeshLibrary
	if ResourceLoader.exists(DEBUG_MESH_LIBRARY_PATH):
		lib = load(DEBUG_MESH_LIBRARY_PATH)
	else:
		lib = MeshLibrary.new()
	
	_populate_library_from_list(lib, list, _target)
	
	ResourceSaver.save(lib, DEBUG_MESH_LIBRARY_PATH)
	print("Updated Debug MeshLibrary at: " + DEBUG_MESH_LIBRARY_PATH)

func _populate_library_from_list(lib: MeshLibrary, list: Array, _target: String) -> void:
	var existing_ids = lib.get_item_list()
	var next_id = 0
	for id in existing_ids:
		if id >= next_id: next_id = id + 1
	
	for entry in list:
		if not entry is Dictionary: continue
		var block_id = str(entry.get("id", "unknown"))
		if not _should_process(block_id, "", _target): continue

		var block_name = str(entry.get("name", "Unnamed Block"))
		var base_texture_path = str(entry.get("texture_base", ""))
		
		print("Processing Block: %s" % block_name)
		
		var size = Vector3(1, 1, 1)
		if entry.has("dimensions") and entry["dimensions"] is Array:
			var d = entry["dimensions"]
			if d.size() >= 3:
				size = Vector3(d[0], d[1], d[2])
		
		_create_mesh_item_in_library(lib, next_id, block_name, base_texture_path, size, false)
		next_id += 1
		
		if _check_texture_exists(base_texture_path, "on"):
			var on_name = block_name + " (ON)"
			_create_mesh_item_in_library(lib, next_id, on_name, base_texture_path, size, true)
			next_id += 1

func _import_elements(list, target):
	var script = load(ELEMENT_SCRIPT)
	for entry in list:
		if not entry is Dictionary: continue
		var path = RESOURCE_BASE_PATH + "elements/" + str(entry.get("id", "unknown")) + ".tres"
		if not _should_process(str(entry.get("id")), path, target): continue
		
		var res = _get_or_create_resource(path, script)
		res.element_name = str(entry.get("name", "Unnamed"))
		if entry.has("color"): res.color = Color(entry["color"])
		if entry.has("reactions") and entry["reactions"] is Dictionary: res.reaction_rules = entry["reactions"]
		if entry.has("effects") and entry["effects"] is Dictionary: res.effect_data = entry["effects"]
		ResourceSaver.save(res, path)

func _import_items(list, target):
	var script = load(ITEM_SCRIPT)
	for entry in list:
		if not entry is Dictionary: continue
		var path = RESOURCE_BASE_PATH + "items/" + str(entry.get("id", "unknown")) + ".tres"
		if not _should_process(str(entry.get("id")), path, target): continue
		
		var res = _get_or_create_resource(path, script)
		res.item_name = str(entry.get("name", "Unnamed"))
		if entry.has("texture") and ResourceLoader.exists(entry["texture"]):
			res.icon = load(entry["texture"])
		
		if entry.has("item_data") and entry["item_data"] is Dictionary:
			var d = entry["item_data"]
			res.damage = d.get("damage", 0.0)
			res.stack_size = d.get("stack", 50)
			res.modifiers = d.get("modifiers", {})
			if d.has("element"):
				var ep = RESOURCE_BASE_PATH + "elements/" + str(d["element"]) + ".tres"
				if ResourceLoader.exists(ep): res.element = load(ep)

		if entry.has("ore_generation") and entry["ore_generation"] is Dictionary:
			var gen = entry["ore_generation"]
			res.is_ore = true
			res.ore_block_name = str(gen.get("block", ""))
			res.min_depth = int(gen.get("min_depth", 0))
			res.max_depth = int(gen.get("max_depth", 30))
			res.rarity = float(gen.get("rarity", 0.0))
		else:
			res.is_ore = false

		ResourceSaver.save(res, path)

func _import_recipes(list, target):
	var script = load(RECIPE_SCRIPT)
	for entry in list:
		if not entry is Dictionary: continue
		var path = RESOURCE_BASE_PATH + "recipes/" + str(entry.get("id", "unknown")) + ".tres"
		if not _should_process(str(entry.get("id")), path, target): continue
		
		var res = script.new()
		res.recipe_name = str(entry.get("name", "Recipe"))
		res.craft_time = entry.get("time", 1.0)
		
		var op = RESOURCE_BASE_PATH + "items/" + str(entry.get("output", "")) + ".tres"
		if ResourceLoader.exists(op): 
			res.output_item = load(op)
			res.output_count = entry.get("count", 1)
			
		if entry.has("inputs") and entry["inputs"] is Dictionary and not entry["inputs"].is_empty():
			var k = entry["inputs"].keys()[0]
			var ip = RESOURCE_BASE_PATH + "items/" + str(k) + ".tres"
			if ResourceLoader.exists(ip):
				res.input_item = load(ip)
				res.input_count = entry["inputs"][k]
		ResourceSaver.save(res, path)

# --- Scene Generators ---

func _generate_building_scene(data, save_path):
	var inst = StaticBody3D.new()
	inst.name = str(data.get("name", "GeneratedBuilding"))
	
	# Add Script
	var template_path = data.get("template")
	if template_path and ResourceLoader.exists(template_path):
		var temp_res = load(template_path)
		var temp_inst = temp_res.instantiate()
		inst.set_script(temp_inst.get_script()) 
		temp_inst.free()

	var visual_parent = inst
	var logic = data.get("logic", {})
	
	if logic.get("rotates", false):
		var rot = Node3D.new()
		rot.name = "Rotatable"
		inst.add_child(rot)
		visual_parent = rot

	# Handle Structure vs Single Block Visuals
	var layout_config: Array[Vector2i] = []
	
	if data.has("structure"):
		var structure_list = data["structure"]
		var pivot_shift = Vector2i.ZERO
		var found_center = false
		
		# Pass 1: Find Center
		for part in structure_list:
			if part.get("is_center", false):
				var off = part.get("offset", [0, 0])
				pivot_shift = Vector2i(off[0], off[1])
				found_center = true
				break
		
		if not found_center and not structure_list.is_empty():
			print("Warning: No 'is_center' defined for %s. Defaulting to first block." % data.get("name"))
			var off = structure_list[0].get("offset", [0, 0])
			pivot_shift = Vector2i(off[0], off[1])

		# Pass 2: Generate
		var idx = 0
		for part in structure_list:
			var raw_offset = part.get("offset", [0, 0])
			# Calculate final offset relative to the designated center
			var final_offset = Vector2i(raw_offset[0], raw_offset[1]) - pivot_shift
			
			var tex = part.get("texture", "")
			var part_rot = part.get("rotation", 0)
			
			layout_config.append(final_offset)
			
			# 3D Position: X=final_offset.x, Z=final_offset.y. Y=0 (floor)
			var pos_offset = Vector3(final_offset.x, 0, final_offset.y)
			
			# Create Visual Mesh
			var mi = MeshInstance3D.new()
			mi.name = "Block_%d" % idx
			mi.mesh = _create_advanced_block_mesh(tex, Vector3(1, 1, 1), false, true)
			mi.position = pos_offset
			mi.rotation_degrees.y = part_rot
			visual_parent.add_child(mi)
			
			# Create Individual Collision Shape for this block
			var col = CollisionShape3D.new()
			col.name = "Collision_%d" % idx
			var shape = BoxShape3D.new()
			shape.size = Vector3(1, 1, 1)
			col.position = pos_offset + Vector3(0, 0.5, 0)
			col.shape = shape
			inst.add_child(col)
			
			idx += 1
	else:
		# Single block legacy logic
		_add_visuals(visual_parent, data.get("visuals", {}))
		layout_config.append(Vector2i.ZERO)
		
		# Single Collision
		var col = CollisionShape3D.new()
		col.name = "CollisionShape3D"
		var shape = BoxShape3D.new()
		var width = 1
		var height = 1
		if data.has("grid"):
			width = data["grid"].get("width", 1)
			height = data["grid"].get("height", 1)
		elif data.has("dimensions"):
			width = data["dimensions"][0]
			height = data["dimensions"][2] 
		
		shape.size = Vector3(width, 1, height)
		col.position = Vector3((width - 1) * 0.5, 0.5, (height - 1) * 0.5)
		col.shape = shape
		inst.add_child(col)

	# Set the layout config for the building script
	_apply_param(inst, "layout_config", layout_config)

	# Components
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

	if logic.get("emit_projectile", false) or logic.get("shooting", false):
		_add_component(inst, COMP_SHOOTER, "ShooterComponent")
		var shoot = inst.get_node("ShooterComponent")
		shoot.fire_point_path = NodePath("../Rotatable/ProjectileOrigin") 
		
		var marker = Marker3D.new()
		marker.name = "ProjectileOrigin"
		marker.position = Vector3(0, 0.5, 0.6)
		visual_parent.add_child(marker)
	
	# Inventory Component
	if logic.has("inventory") and logic["inventory"] is Dictionary:
		var inv_data = logic["inventory"]
		var inv = _add_component(inst, COMP_INVENTORY, "InventoryComponent")
		inv.max_slots = inv_data.get("slots", 1)
		inv.slot_capacity = inv_data.get("capacity", 50)
		inv.can_receive = inv_data.get("can_receive", true)
		inv.can_output = inv_data.get("can_output", true)
		inv.omni_directional = inv_data.get("omni", false)
		
		# Fix for Array assignment error using generic Array intermediate
		if inv_data.has("whitelist") and inv_data["whitelist"] is Array:
			var allowed: Array[Resource] = []
			for item_id in inv_data["whitelist"]:
				var p = RESOURCE_BASE_PATH + "items/" + str(item_id) + ".tres"
				if ResourceLoader.exists(p):
					allowed.append(load(p))
			if not allowed.is_empty():
				inv.set("allowed_items", allowed)
		
		if inv_data.has("blacklist") and inv_data["blacklist"] is Array:
			var denied: Array[Resource] = []
			for item_id in inv_data["blacklist"]:
				var p = RESOURCE_BASE_PATH + "items/" + str(item_id) + ".tres"
				if ResourceLoader.exists(p):
					denied.append(load(p))
			if not denied.is_empty():
				inv.set("denied_items", denied)
	
	_apply_logic_params(inst, data)
	# Apply defaults for IO if present in data, otherwise handled by script init using defaults
	if logic.has("io_config"):
		var io = logic["io_config"]
		var i_mask = _parse_io_mask(io.get("input", ["all"]))
		var o_mask = _parse_io_mask(io.get("output", ["all"]))
		_apply_param(inst, "default_input_mask", i_mask)
		_apply_param(inst, "default_output_mask", o_mask)

	_save_scene(inst, save_path)

func _generate_enemy_scene(data, save_path):
	var inst = CharacterBody3D.new()
	inst.name = str(data.get("name", "GeneratedEnemy"))
	inst.set_script(load(ENTITY_ENEMY_SCRIPT))
	
	var asset_path = data.get("scene_path", "")
	if asset_path != "" and ResourceLoader.exists(asset_path):
		var asset_scene = load(asset_path)
		var asset_inst = asset_scene.instantiate()
		asset_inst.name = "ModelContainer"
		inst.add_child(asset_inst)
	else:
		var mi = MeshInstance3D.new()
		mi.name = "ModelFallback"
		mi.mesh = CapsuleMesh.new()
		inst.add_child(mi)

	var col = CollisionShape3D.new()
	col.name = "CollisionShape3D"
	col.shape = CapsuleShape3D.new()
	col.position = Vector3(0, 1.0, 0)
	inst.add_child(col)
	
	_add_component(inst, COMP_HEALTH, "HealthComponent")
	var att = _add_component(inst, COMP_ATTACKER, "AttackerComponent")
	
	var t = Timer.new()
	t.name = "AttackTimer"
	att.add_child(t)
	
	_apply_logic_params(inst, data)
	_save_scene(inst, save_path)

# --- Helper Methods ---

func _add_visuals(parent, vdata):
	var visual_type = vdata.get("type", "sprite")
	
	if visual_type == "block":
		var mi = MeshInstance3D.new()
		mi.name = "BlockVisual"
		var dims = Vector3(1, 1, 1)
		if vdata.has("dimensions"):
			var d = vdata["dimensions"]
			dims = Vector3(d[0], d[1], d[2])
		
		mi.mesh = _create_advanced_block_mesh(vdata.get("texture", ""), dims, false, true)
		mi.position = Vector3.ZERO
		parent.add_child(mi)
	else:
		var spr = AnimatedSprite3D.new()
		spr.name = "AnimatedSprite3D"
		spr.axis = Vector3.AXIS_Y 
		spr.pixel_size = 0.03 
		spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		parent.add_child(spr)
		_process_3d_sprite_frames(spr, vdata)

func _add_component(parent, script_path, _name):
	var node = load(script_path).new()
	node.name = _name
	parent.add_child(node)
	return node

func _apply_logic_params(inst, data):
	var logic = data.get("logic", {})
	if logic.has("health") and inst.has_node("HealthComponent"): 
		_apply_param(inst, "HealthComponent:max_health", logic["health"])
	if logic.has("power_cost") and inst.has_node("PowerConsumerComponent"): 
		_apply_param(inst, "PowerConsumerComponent:power_consumption", logic["power_cost"])
	
	if data.has("params"):
		for k in data["params"]: _apply_param(inst, k, data["params"][k])

func _save_scene(root_node, path):
	_set_owner_recursive(root_node, root_node)
	var packed = PackedScene.new()
	packed.pack(root_node)
	ResourceSaver.save(packed, path)
	root_node.queue_free()

func _set_owner_recursive(node, root):
	if node != root: node.owner = root
	for c in node.get_children(): _set_owner_recursive(c, root)

func _apply_param(node, key, val):
	if ":" in key:
		var p = key.split(":")
		var child = node.get_node_or_null(p[0])
		if child: child.set(p[1], val)
	else:
		node.set(key, val)

func _create_mesh_item_in_library(lib: MeshLibrary, id: int, block_name: String, base_path: String, size: Vector3, is_on: bool):
	var mesh = _create_advanced_block_mesh(base_path, size, is_on, false)
	
	var target_id = id
	var exists = false
	
	for ex_id in lib.get_item_list():
		if lib.get_item_name(ex_id) == block_name:
			target_id = ex_id
			exists = true
			break
			
	if not exists:
		lib.create_item(target_id)
		
	lib.set_item_name(target_id, block_name)
	lib.set_item_mesh(target_id, mesh)
	
	var shape = BoxShape3D.new()
	shape.size = size
	lib.set_item_shapes(target_id, [shape, Transform3D.IDENTITY])

func _create_advanced_block_mesh(base_path: String, size: Vector3, is_on_state: bool, align_bottom: bool) -> ArrayMesh:
	var st = SurfaceTool.new()
	var mesh = ArrayMesh.new()
	
	var ext = base_path.get_extension()
	var base_no_ext = base_path.get_basename()
	
	var get_tex = func(face_suffix: String) -> String:
		var candidates = []
		if is_on_state: candidates.append(base_no_ext + "_" + face_suffix + "_on." + ext)
		candidates.append(base_no_ext + "_" + face_suffix + "." + ext)
		if is_on_state: candidates.append(base_no_ext + "_on." + ext)
		candidates.append(base_path)
		for p in candidates:
			if ResourceLoader.exists(p): return p
		return base_path 
	
	var faces = [
		{ "name": "Top", "normal": Vector3.UP, "suffix": "top" },
		{ "name": "Bottom", "normal": Vector3.DOWN, "suffix": "bottom" },
		{ "name": "Front", "normal": Vector3.FORWARD, "suffix": "front" },
		{ "name": "Back", "normal": Vector3.BACK, "suffix": "back" },
		{ "name": "Left", "normal": Vector3.LEFT, "suffix": "side" },
		{ "name": "Right", "normal": Vector3.RIGHT, "suffix": "side" }
	]
	
	var h = size * 0.5
	var vert_offset = Vector3(0, h.y, 0) if align_bottom else Vector3.ZERO
	
	for i in range(faces.size()):
		var face_info = faces[i]
		var tex_path = get_tex.call(face_info.suffix)
		var mat = StandardMaterial3D.new()
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		if ResourceLoader.exists(tex_path):
			mat.albedo_texture = load(tex_path)
			mat.uv1_triplanar = false 
		
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_material(mat)
		_add_face_geometry(st, face_info.normal, h, vert_offset)
		st.generate_normals()
		st.generate_tangents()
		st.commit(mesh)
	return mesh

func _add_face_geometry(st: SurfaceTool, normal: Vector3, h: Vector3, offset: Vector3):
	var u00 = Vector2(1, 0); var u10 = Vector2(0, 0); var u11 = Vector2(0, 1); var u01 = Vector2(1, 1)
	var v = []
	if normal == Vector3.UP: v = [Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)]
	elif normal == Vector3.DOWN: v = [Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, -h.y, -h.z), Vector3(-h.x, -h.y, -h.z)]
	elif normal == Vector3.FORWARD: v = [Vector3(-h.x, h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(-h.x, -h.y, h.z)]
	elif normal == Vector3.BACK: v = [Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z), Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z)]
	elif normal == Vector3.LEFT: v = [Vector3(-h.x, h.y, -h.z), Vector3(-h.x, h.y, h.z), Vector3(-h.x, -h.y, h.z), Vector3(-h.x, -h.y, -h.z)]
	elif normal == Vector3.RIGHT: v = [Vector3(h.x, h.y, h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, -h.y, h.z)]
	for i in range(v.size()): v[i] += offset
	st.set_uv(u00); st.add_vertex(v[0]); st.set_uv(u10); st.add_vertex(v[1]); st.set_uv(u11); st.add_vertex(v[2])
	st.set_uv(u00); st.add_vertex(v[0]); st.set_uv(u11); st.add_vertex(v[2]); st.set_uv(u01); st.add_vertex(v[3])

func _process_3d_sprite_frames(anim_sprite: AnimatedSprite3D, vdata):
	if not vdata.has("texture") or not ResourceLoader.exists(vdata["texture"]): return
	var tex = load(vdata["texture"])
	var w = vdata.get("width", 32)
	var h = vdata.get("height", 32)
	var frames = SpriteFrames.new()
	frames.remove_animation("default")
	var configs = vdata.get("animations", {})
	if not configs is Dictionary: configs = {}
	if configs.is_empty(): configs["default"] = { "row": 0, "count": 1 }
	for anim in configs:
		var c = configs[anim]
		if not frames.has_animation(anim): frames.add_animation(anim)
		frames.set_animation_loop(anim, c.get("loop", true))
		var row_idx = c.get("row", 0)
		var count = c.get("count", 1)
		for i in range(count):
			var at = AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(row_idx * h, i * w, w, h)
			frames.add_frame(anim, at)
	anim_sprite.sprite_frames = frames

func _check_texture_exists(base_path: String, suffix: String) -> bool:
	var ext = base_path.get_extension()
	var base_no_ext = base_path.get_basename()
	var p = base_no_ext + "_" + suffix + "." + ext
	return ResourceLoader.exists(p)

func _should_process(id: String, file_path: String, _target_filter: String) -> bool:
	if target_item_id != "All" and id != target_item_id: return false
	if not ResourceLoader.exists(file_path): return true
	return overwrite_existing

func _get_or_create_resource(path, script_class):
	if ResourceLoader.exists(path): return load(path)
	return script_class.new()
