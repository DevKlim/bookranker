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
			target_item_id = "All"
			notify_property_list_changed()

var target_item_id: String = "All"

@export var overwrite_existing: bool = false
@export var mesh_library_path: String = "res://resources/mesh_library.tres"

const DEBUG_MESH_LIBRARY_PATH = "res://resources/debug_mesh_library.tres"
const JSON_PATH = "res://data/content_manifest.json"
const RESOURCE_BASE_PATH = "res://resources/"

const SCENE_BUILDABLES_PATH = "res://scenes/buildables/"
const SCENE_ENEMIES_PATH = "res://scenes/enemies/"
const SCENE_GEN_BASE = "res://scenes/generated/"

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
const COMP_CRAFTER = "res://scripts/components/crafter_component.gd"
const COMP_ELEMENTAL = "res://scripts/components/elemental_component.gd"

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
	
	DirAccess.make_dir_recursive_absolute("res://assets/items/")
	DirAccess.make_dir_recursive_absolute("res://assets/ores/")
	DirAccess.make_dir_recursive_absolute("res://assets/buildables/")
	
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
	# Import recipes AFTER items/buildables so references exist
	if (target_category == "All" or target_category == "Recipes") and data.has("recipes"):
		_import_recipes(data["recipes"], target_category)
	if (target_category == "All" or target_category == "Enemies") and data.has("enemies"):
		_import_enemies(data["enemies"], target_category)
	
	print("--- Data Import Complete ---")
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()

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
		
	print("--- Cleanup Complete ---")
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()

func _get_or_create_resource(path, script_class):
	if ResourceLoader.exists(path):
		var res = load(path)
		if res: return res
		else: print("DataImporter: Found corrupted resource at %s, recreating..." % path)
	return script_class.new()

# Helper to find a resource whether it's an Item OR a Buildable
func _resolve_resource_id(id_str: String) -> Resource:
	# Check Item
	var item_path = RESOURCE_BASE_PATH + "items/" + id_str + ".tres"
	if ResourceLoader.exists(item_path): return load(item_path)
	
	# Check Buildable
	var build_path = RESOURCE_BASE_PATH + "buildables/" + id_str + ".tres"
	if ResourceLoader.exists(build_path): return load(build_path)
	
	return null

func _import_recipes(list, target):
	var script = load(RECIPE_SCRIPT)
	for entry in list:
		if not entry is Dictionary: continue
		var path = RESOURCE_BASE_PATH + "recipes/" + str(entry.get("id", "unknown")) + ".tres"
		if not _should_process(str(entry.get("id")), path, target): continue
		
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
			res.element_units = int(d.get("element_units", 1))
			res.ignore_element_cooldown = bool(d.get("ignore_element_cd", false))
			if d.has("element"):
				var ep = RESOURCE_BASE_PATH + "elements/" + str(d["element"]) + ".tres"
				if ResourceLoader.exists(ep): res.element = load(ep)
				else: res.element = null
		
		# Tool Data
		if entry.has("tool_data") and entry["tool_data"] is Dictionary:
			var td = entry["tool_data"]
			res.is_tool = true
			res.tool_type = td.get("type", "none")
			res.action_time = float(td.get("time", 1.0))
			var off = td.get("offset", [0, 0, 0])
			if off.size() >= 3:
				res.highlight_offset = Vector3(off[0], off[1], off[2])
			else:
				res.highlight_offset = Vector3.ZERO
		else:
			res.is_tool = false
		
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

func _generate_building_scene(data, save_path):
	var inst = StaticBody3D.new()
	inst.name = str(data.get("name", "GeneratedBuilding"))
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
	
	var layout_config: Array[Vector2i] = []
	if data.has("structure"):
		var structure_list = data["structure"]
		var pivot_shift = Vector2i.ZERO
		for part in structure_list:
			if part.get("is_center", false):
				var off = part.get("offset", [0, 0])
				pivot_shift = Vector2i(off[0], off[1])
				break
		var idx = 0
		for part in structure_list:
			var raw_offset = part.get("offset", [0, 0])
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
			col.position = pos_offset + Vector3(0, 0.5, 0)
			col.shape = shape
			inst.add_child(col)
			idx += 1
	else:
		_add_visuals(visual_parent, data.get("visuals", {}))
		layout_config.append(Vector2i.ZERO)
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

	if logic.get("emit_projectile", false) or logic.get("shooting", false):
		_add_component(inst, COMP_SHOOTER, "ShooterComponent")
		var shoot = inst.get_node("ShooterComponent")
		shoot.fire_point_path = NodePath("../Rotatable/ProjectileOrigin") 
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
			var allowed: Array[Resource] = []
			for item_id in inv_data["whitelist"]:
				var p = RESOURCE_BASE_PATH + "items/" + str(item_id) + ".tres"
				if ResourceLoader.exists(p): allowed.append(load(p))
			if not allowed.is_empty(): inv.set("allowed_items", allowed)
		if inv_data.has("blacklist") and inv_data["blacklist"] is Array:
			var denied: Array[Resource] = []
			for item_id in inv_data["blacklist"]:
				var p = RESOURCE_BASE_PATH + "items/" + str(item_id) + ".tres"
				if ResourceLoader.exists(p): denied.append(load(p))
			if not denied.is_empty(): inv.set("denied_items", denied)
	
	_add_component(inst, COMP_ELEMENTAL, "ElementalComponent")
	
	_apply_logic_params(inst, data)
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
	# Avoid trying to load itself if we are regenerating the very scene path we are saving to
	# We rely on new generation here, so we skip loading asset_path if it equals save_path
	if asset_path != "" and asset_path != save_path and ResourceLoader.exists(asset_path):
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
	
	_add_component(inst, COMP_ELEMENTAL, "ElementalComponent")
	
	_apply_logic_params(inst, data)
	_save_scene(inst, save_path)

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
	var script = load(script_path)
	if not script:
		return null
	if not script.has_method("new"):
		return null
	var node = script.new()
	node.name = _name
	parent.add_child(node)
	return node

func _apply_logic_params(inst, data):
	var logic = data.get("logic", {})
	if logic.has("health"):
		if "max_health" in inst: _apply_param(inst, "max_health", logic["health"])
		elif inst.has_node("HealthComponent"): _apply_param(inst, "HealthComponent:max_health", logic["health"])
	if logic.has("defense"):
		if inst.has_node("HealthComponent"): _apply_param(inst, "HealthComponent:defense", logic["defense"])
	if logic.has("magical_defense"):
		if inst.has_node("HealthComponent"): _apply_param(inst, "HealthComponent:magical_defense", logic["magical_defense"])
	if logic.has("elemental_cd"):
		if inst.has_node("ElementalComponent"): _apply_param(inst, "ElementalComponent:elemental_cd", logic["elemental_cd"])
	if logic.has("power_cost"):
		if "power_consumption" in inst: _apply_param(inst, "power_consumption", logic["power_cost"])
		elif inst.has_node("PowerConsumerComponent"): _apply_param(inst, "PowerConsumerComponent:power_consumption", logic["power_cost"])
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
	if not exists: lib.create_item(target_id)
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

func _import_buildables(list, _category, target):
	var script = load(BUILDABLE_SCRIPT)
	for entry in list:
		if not entry is Dictionary: continue
		var path = RESOURCE_BASE_PATH + "buildables/" + str(entry.get("id", "unknown")) + ".tres"
		if not _should_process(str(entry.get("id")), path, target): continue
		
		var res = _get_or_create_resource(path, script)
		if "scene" in res: res.scene = null 

		var new_scene_path = ""
		if entry.has("template") and (entry.has("visuals") or entry.has("structure")):
			new_scene_path = SCENE_BUILDABLES_PATH + str(entry.get("id")) + ".tscn"
			_generate_building_scene(entry, new_scene_path)
			
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
			var io_config = entry["logic"].get("io_config", {})
			res.default_input_mask = _parse_io_mask(io_config.get("input", ["all"]))
			res.default_output_mask = _parse_io_mask(io_config.get("output", ["all"]))
		
		res.display_offset = Vector2.ZERO 
		if new_scene_path != "":
			res.scene = ResourceLoader.load(new_scene_path, "", ResourceLoader.CACHE_MODE_REPLACE)
		ResourceSaver.save(res, path)

func _parse_io_mask(directions_array: Array) -> int:
	var mask = 0
	if "all" in directions_array: return 15
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
		
		var res = _get_or_create_resource(path, script)
		if "scene" in res: res.scene = null
		
		var new_scene_path = ""
		if entry.has("scene_path"):
			var raw_path = entry["scene_path"]
			if raw_path.begins_with("res://"):
				new_scene_path = raw_path
			else:
				new_scene_path = SCENE_ENEMIES_PATH + str(entry.get("id")) + ".tscn"
			_generate_enemy_scene(entry, new_scene_path)
		
		res.enemy_name = str(entry.get("name", "Enemy"))
		
		if new_scene_path != "":
			res.scene = ResourceLoader.load(new_scene_path, "", ResourceLoader.CACHE_MODE_REPLACE)
		elif entry.has("template") and ResourceLoader.exists(entry["template"]):
			res.scene = load(entry["template"])
			
		if entry.has("logic") and entry["logic"] is Dictionary:
			res.health = entry["logic"].get("health", 50.0)
			res.speed = entry["logic"].get("speed", 50.0)
			res.defense = entry["logic"].get("defense", 0.0)
			res.magical_defense = entry["logic"].get("magical_defense", 0.0)
			res.elemental_cd = entry["logic"].get("elemental_cd", 0.0)
			res.elemental_resistances = entry["logic"].get("resistances", {})
		if entry.has("params") and entry["params"] is Dictionary:
			res.attack_damage = entry["params"].get("attack_damage", 10.0)
			res.attack_speed = entry["params"].get("attack_speed", 1.0)
		if entry.has("drops") and entry["drops"] is Array:
			res.drops = entry["drops"]
		ResourceSaver.save(res, path)

func _import_blocks(list, _target):
	var lib: MeshLibrary
	if ResourceLoader.exists(mesh_library_path): lib = load(mesh_library_path)
	else: lib = MeshLibrary.new()
	_populate_library_from_list(lib, list, _target)
	ResourceSaver.save(lib, mesh_library_path)

func _import_debug_blocks(list, _target):
	var lib: MeshLibrary
	if ResourceLoader.exists(DEBUG_MESH_LIBRARY_PATH): lib = load(DEBUG_MESH_LIBRARY_PATH)
	else: lib = MeshLibrary.new()
	_populate_library_from_list(lib, list, _target)
	ResourceSaver.save(lib, DEBUG_MESH_LIBRARY_PATH)

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
		var size = Vector3(1, 1, 1)
		if entry.has("dimensions") and entry["dimensions"] is Array:
			var d = entry["dimensions"]
			if d.size() >= 3: size = Vector3(d[0], d[1], d[2])
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
		if entry.has("duration"): res.duration = float(entry["duration"])
		
		if entry.has("reactions") and entry["reactions"] is Dictionary: 
			res.reaction_rules = entry["reactions"]
		
		if entry.has("effects") and entry["effects"] is Dictionary: 
			res.stat_modifiers = entry["effects"]
			
		# Import Cooldown
		res.application_cooldown = float(entry.get("cooldown", 0.0))
			
		ResourceSaver.save(res, path)
