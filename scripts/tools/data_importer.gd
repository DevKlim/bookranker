@tool
extends Node

## Click this bool in the inspector to run the import process.
@export var import_data: bool = false:
	set(value):
		if value:
			_run_import()
		import_data = false

@export var overwrite_existing: bool = false
var target_item_select: String = "All"

const JSON_PATH = "res://data/content_manifest.json"
const RESOURCE_BASE_PATH = "res://resources/"
const SCENE_BASE_PATH = "res://scenes/generated/"

# Script paths
const ELEMENT_SCRIPT = "res://scripts/resources/element_resource.gd"
const ITEM_SCRIPT = "res://scripts/resources/item_resource.gd"
const RECIPE_SCRIPT = "res://scripts/resources/recipe_resource.gd"
const ENEMY_SCRIPT = "res://scripts/resources/enemy_resource.gd"
const BUILDABLE_SCRIPT = "res://scripts/resources/buildable_resource.gd"

func _get_property_list() -> Array:
	var properties = []
	var ids = ["All"]
	var data = _load_json_safe()
	if data and data is Dictionary:
		var categories = ["elements", "items", "buildings", "wires", "recipes", "enemies"]
		for cat in categories:
			if data.has(cat) and data[cat] is Array:
				for entry in data[cat]:
					if entry is Dictionary and entry.has("id"):
						ids.append(entry["id"])
	properties.append({
		"name": "target_item_select",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(ids)
	})
	return properties

func _load_json_safe():
	if not FileAccess.file_exists(JSON_PATH): return null
	var file = FileAccess.open(JSON_PATH, FileAccess.READ)
	if not file: return null
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK: return json.data
	return null

func _run_import() -> void:
	print("--- Starting Data Import ---")
	var data = _load_json_safe()
	if not data or not (data is Dictionary):
		printerr("Failed to load JSON manifest.")
		return
	
	for d in ["elements/", "items/", "buildables/", "recipes/", "enemies/"]:
		DirAccess.make_dir_recursive_absolute(RESOURCE_BASE_PATH + d)
	DirAccess.make_dir_recursive_absolute(SCENE_BASE_PATH)

	var target = target_item_select
	if data.has("elements") and data["elements"] is Array: _import_elements(data["elements"], target)
	if data.has("items") and data["items"] is Array: _import_items(data["items"], target)
	if data.has("buildings") and data["buildings"] is Array: _import_buildables(data["buildings"], "building", target)
	if data.has("wires") and data["wires"] is Array: _import_buildables(data["wires"], "wire", target)
	if data.has("recipes") and data["recipes"] is Array: _import_recipes(data["recipes"], target)
	if data.has("enemies") and data["enemies"] is Array: _import_enemies(data["enemies"], target)
	
	print("--- Data Import Complete ---")
	if Engine.is_editor_hint():
		EditorInterface.get_resource_filesystem().scan()

func _should_process(id: String, file_path: String, target_filter: String) -> bool:
	if target_filter != "All": return id == target_filter
	if not ResourceLoader.exists(file_path): return true
	return overwrite_existing

# --- Handlers ---
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
		print("Imported Element: " + str(entry.get("id")))

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
				
		if entry.has("ore_data") and entry["ore_data"] is Dictionary:
			res.is_ore = true
			var od = entry["ore_data"]
			# Safe check for array access
			if od.has("coords") and od["coords"] is Array and od["coords"].size() >= 2:
				res.ore_atlas_coords = Vector2i(od["coords"][0], od["coords"][1])
			
		ResourceSaver.save(res, path)
		print("Imported Item: " + str(entry.get("id")))

func _import_buildables(list, category, target):
	var script = load(BUILDABLE_SCRIPT)
	for entry in list:
		if not entry is Dictionary: continue
		var path = RESOURCE_BASE_PATH + "buildables/" + str(entry.get("id", "unknown")) + ".tres"
		if not _should_process(str(entry.get("id")), path, target): continue
		
		var frame_w = 32
		var frame_h = 32
		var calc_offset = Vector2.ZERO
		
		var new_scene_path = ""
		if entry.has("template"):
			new_scene_path = SCENE_BASE_PATH + str(entry.get("id")) + ".tscn"
			print("Generating Scene: " + str(entry.get("id")))
			_generate_scene_from_template(entry, new_scene_path)
			
		var res = _get_or_create_resource(path, script)
		res.buildable_name = str(entry.get("name", "Unnamed"))
		res.description = str(entry.get("description", ""))
		
		if entry.has("visuals") and entry["visuals"] is Dictionary and entry["visuals"].has("texture"):
			var tp = entry["visuals"]["texture"]
			if ResourceLoader.exists(tp):
				var tex = load(tp)
				frame_w = entry["visuals"].get("width", 32)
				frame_h = entry["visuals"].get("height", 32)
				
				var atlas = AtlasTexture.new()
				atlas.atlas = tex
				atlas.region = Rect2(0, 0, frame_w, frame_h)
				res.icon = atlas
		elif entry.has("texture") and ResourceLoader.exists(entry["texture"]):
			var tex = load(entry["texture"])
			res.icon = tex
			# If simple texture, width/height is derived from texture
			frame_w = tex.get_width()
			frame_h = tex.get_height()
			
		# Calculate offset to align bottom 1:1 portion
		# Apply -8.0 correction to match BaseBuilding default (0, -8) logic
		var offset_y = ((float(frame_w) - float(frame_h)) / 2.0) - 8.0
		calc_offset = Vector2(0, offset_y)
			
		if entry.has("grid") and entry["grid"] is Dictionary:
			res.width = entry["grid"].get("width", 1)
			res.height = entry["grid"].get("height", 1)
			res.layer = 0 if entry["grid"].get("layer") == "wire" else 1
			
		if entry.has("logic") and entry["logic"] is Dictionary:
			res.has_input = entry["logic"].get("has_input", false)
			res.has_output = entry["logic"].get("has_output", false)
			
		# HANDLE DISPLAY OFFSET
		# Use calculated offset unless explicitly overridden
		if entry.has("display_offset") and entry["display_offset"] is Array:
			res.display_offset = Vector2(entry["display_offset"][0], entry["display_offset"][1])
		else:
			res.display_offset = calc_offset
			
		if new_scene_path != "":
			res.scene = ResourceLoader.load(new_scene_path, "", ResourceLoader.CACHE_MODE_REPLACE)
			
		ResourceSaver.save(res, path)
		print("Imported Buildable: " + str(entry.get("id")))

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
		print("Imported Recipe: " + str(entry.get("id")))

func _import_enemies(list, target):
	var script = load(ENEMY_SCRIPT)
	for entry in list:
		if not entry is Dictionary: continue
		var path = RESOURCE_BASE_PATH + "enemies/" + str(entry.get("id", "unknown")) + ".tres"
		if not _should_process(str(entry.get("id")), path, target): continue
		
		var res = _get_or_create_resource(path, script)
		res.enemy_name = str(entry.get("name", "Enemy"))
		if entry.has("template") and ResourceLoader.exists(entry["template"]):
			res.scene = load(entry["template"])
		if entry.has("logic") and entry["logic"] is Dictionary:
			res.health = entry["logic"].get("health", 50.0)
			res.speed = entry["logic"].get("speed", 50.0)
		if entry.has("params") and entry["params"] is Dictionary:
			res.attack_damage = entry["params"].get("attack_damage", 10.0)
		ResourceSaver.save(res, path)
		print("Imported Enemy: " + str(entry.get("id")))

# --- Helpers ---

func _get_or_create_resource(path, script_class):
	if ResourceLoader.exists(path):
		var r = load(path)
		if is_instance_of(r, script_class): return r
	return script_class.new()

func _generate_scene_from_template(data, save_path):
	var template = ResourceLoader.load(data["template"], "", ResourceLoader.CACHE_MODE_REPLACE)
	if not template:
		printerr("Template missing: " + str(data.get("template")))
		return
		
	var inst = template.instantiate()
	inst.name = str(data.get("name", "Generated"))
	
	if data.has("visuals") and data["visuals"] is Dictionary: 
		_process_visuals(inst, data["visuals"])
	elif data.has("texture"): 
		_apply_simple_texture(inst, data["texture"])
	
	if data.has("params") and data["params"] is Dictionary:
		for k in data["params"]: 
			_apply_param(inst, k, data["params"][k])
		
	if data.has("logic") and data["logic"] is Dictionary:
		var l = data["logic"]
		if l.has("health"): _apply_param(inst, "HealthComponent:max_health", l["health"])
		if l.has("power_cost"): _apply_param(inst, "PowerConsumerComponent:power_consumption", l["power_cost"])
		if l.has("power_gen"): _apply_param(inst, "PowerProviderComponent:power_generation", l["power_gen"])
		if l.has("input_dir"): _apply_param(inst, "input_direction", l["input_dir"])
		if l.has("output_dir"): _apply_param(inst, "output_direction", l["output_dir"])
		
	_set_owner_recursive(inst, inst)
	
	var packed = PackedScene.new()
	if packed.pack(inst) == OK:
		ResourceSaver.save(packed, save_path)
		print("  -> Saved PackedScene: %s" % save_path)
	else:
		printerr("Failed to pack scene: " + save_path)
	inst.queue_free()

func _set_owner_recursive(node, root):
	if node != root: node.owner = root
	for c in node.get_children(): _set_owner_recursive(c, root)

func _process_visuals(inst, vdata):
	if not vdata.has("texture") or not ResourceLoader.exists(vdata["texture"]): return
	var tex = load(vdata["texture"])
	var w = vdata.get("width", 32)
	var h = vdata.get("height", 32)
	
	var anim_sprite = inst.get_node_or_null("AnimatedSprite2D")
	if not anim_sprite:
		for child in inst.get_children():
			if child is AnimatedSprite2D:
				anim_sprite = child
				break
			if child.name == "Rotatable":
				for sub in child.get_children():
					if sub is AnimatedSprite2D:
						anim_sprite = sub
						break
	
	if not anim_sprite:
		printerr("    [Importer] WARNING: Could not find AnimatedSprite2D in scene %s." % inst.name)
		return
		
	# FORCE ALIGNMENT
	# Reset position and offset in the scene, rely on Resource.display_offset + BaseBuilding logic
	anim_sprite.position = Vector2.ZERO
	anim_sprite.centered = true
	anim_sprite.offset = Vector2.ZERO
	
	# Apply Scale from Visuals if present
	if vdata.has("scale") and vdata["scale"] is Array and vdata["scale"].size() == 2:
		anim_sprite.scale = Vector2(vdata["scale"][0], vdata["scale"][1])
	elif vdata.has("scale") and (typeof(vdata["scale"]) == TYPE_FLOAT or typeof(vdata["scale"]) == TYPE_INT):
		var s = float(vdata["scale"])
		anim_sprite.scale = Vector2(s, s)
	
	var frames = SpriteFrames.new()
	frames.remove_animation("default")
	
	var configs = vdata.get("animations", {})
	if not configs is Dictionary: configs = {}
	
	# Fallback if config is empty
	if configs.is_empty():
		configs["default"] = { "row": 0, "count": 1, "speed": 5, "loop": true }
	
	for anim in configs:
		var c = configs[anim]
		if not c is Dictionary: continue
		
		# Ensure animation exists
		if not frames.has_animation(anim):
			frames.add_animation(anim)
			
		frames.set_animation_speed(anim, c.get("speed", 5.0))
		frames.set_animation_loop(anim, c.get("loop", true))
		
		var row_idx = c.get("row", 0)
		var count = c.get("count", 1)
		
		for i in range(count):
			var at = AtlasTexture.new()
			at.atlas = tex
			
			var reg_y = i * w
			var reg_x = row_idx * h
			at.region = Rect2(reg_x, reg_y, w, h)
			frames.add_frame(anim, at)
	
	anim_sprite.sprite_frames = frames
	
	# Ensure default animation exists
	if not frames.has_animation("default"):
		if frames.has_animation("idle_down"):
			frames.add_animation("default")
			for i in range(frames.get_frame_count("idle_down")):
				frames.add_frame("default", frames.get_frame_texture("idle_down", i))
		else:
			# Absolute fallback if idle_down is missing too
			frames.add_animation("default")
			var at = AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(0, 0, w, h)
			frames.add_frame("default", at)
			
	# Fill missing directional animations with fallback (idle_down or default)
	var fallback_src = ""
	if frames.has_animation("idle_down"):
		fallback_src = "idle_down"
	elif frames.has_animation("default"):
		fallback_src = "default"
	
	if fallback_src != "":
		for dir in ["idle_right", "idle_up", "idle_left", "idle_down"]:
			if not frames.has_animation(dir):
				_copy_animation(frames, fallback_src, dir)

func _copy_animation(frames: SpriteFrames, src: StringName, dest: StringName) -> void:
	if not frames.has_animation(src): return
	if frames.has_animation(dest): return
	
	frames.add_animation(dest)
	frames.set_animation_loop(dest, frames.get_animation_loop(src))
	frames.set_animation_speed(dest, frames.get_animation_speed(src))
	
	var count = frames.get_frame_count(src)
	for i in range(count):
		frames.add_frame(dest, frames.get_frame_texture(src, i), frames.get_frame_duration(src, i))

func _apply_simple_texture(inst, path):
	if not ResourceLoader.exists(path): return
	var tex = load(path)
	var asprite = inst.get_node_or_null("AnimatedSprite2D")
	if asprite:
		asprite.position = Vector2.ZERO
		asprite.offset = Vector2.ZERO
		asprite.centered = true
		if asprite.sprite_frames:
			var frames = asprite.sprite_frames.duplicate()
			for anim in ["default", "idle_down"]:
				if frames.has_animation(anim): frames.set_frame(anim, 0, tex)
			asprite.sprite_frames = frames
			
	var spr = inst.get_node_or_null("Sprite2D")
	if spr: 
		spr.texture = tex
		spr.position = Vector2.ZERO
		spr.offset = Vector2.ZERO
		spr.centered = true

func _apply_param(root, key, value):
	var node = root
	var prop = key
	if ":" in key:
		var p = key.split(":")
		node = root.get_node_or_null(p[0])
		prop = p[1]
	
	if not node:
		printerr("Node not found for param '%s' on '%s'" % [key, root.name])
		return
		
	var val = value
	
	# Support for JSON Array to Vector2 conversion [x, y]
	if typeof(val) == TYPE_ARRAY and val.size() == 2:
		if (typeof(val[0]) == TYPE_FLOAT or typeof(val[0]) == TYPE_INT) and \
		   (typeof(val[1]) == TYPE_FLOAT or typeof(val[1]) == TYPE_INT):
			val = Vector2(val[0], val[1])
	
	if typeof(val) == TYPE_STRING and val.begins_with("res://"):
		if ResourceLoader.exists(val):
			val = ResourceLoader.load(val, "", ResourceLoader.CACHE_MODE_REPLACE)
		else:
			return

	if prop in node:
		if "scene" in prop.to_lower() and not "script" in prop.to_lower():
			if val is Resource and not val is PackedScene:
				return
		node.set(prop, val)
	elif node.get(prop) is Dictionary and val is Dictionary:
		var d = node.get(prop)
		d.merge(val, true)
		node.set(prop, d)
