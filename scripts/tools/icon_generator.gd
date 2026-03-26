@tool
extends Node

## Helper script that instantiates a building in a SubViewport, sets up an 
## isometric camera view based on its grid size, and renders an icon automatically.

@export var generate_icon: bool = false:
	set(value):
		if value:
			_run_generation()
		generate_icon = false

@export_enum("All") var target_building_id: String = "All":
	set(value):
		if target_building_id != value:
			target_building_id = value
			notify_property_list_changed()

func _get_property_list() -> Array:
	var properties =[]
	var options = ["All"]
	
	var path = "res://data/content/buildings.json"
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		if file:
			var json = JSON.new()
			if json.parse(file.get_as_text()) == OK and json.data is Array:
				for b in json.data:
					options.append(str(b.get("id")))

	properties.append({
		"name": "target_building_id",
		"type": TYPE_STRING,
		"usage": PROPERTY_USAGE_DEFAULT,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(options)
	})
	
	return properties

func _run_generation() -> void:
	print("--- Starting Icon Generation ---")
	DirAccess.make_dir_recursive_absolute("res://assets/icons/")
	
	var path = "res://data/content/buildings.json"
	if not FileAccess.file_exists(path): 
		printerr("Buildings config not found!")
		return
		
	var file = FileAccess.open(path, FileAccess.READ)
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK: 
		printerr("Failed to parse buildings.json")
		return
	
	var targets =[]
	if target_building_id == "All":
		targets = json.data
	else:
		for b in json.data:
			if str(b.get("id")) == target_building_id:
				targets.append(b)
	
	_generate_next(targets, 0)

func _generate_next(targets: Array, index: int) -> void:
	if index >= targets.size():
		print("--- Generation Complete ---")
		if Engine.is_editor_hint():
			EditorInterface.get_resource_filesystem().scan()
		return
		
	var b = targets[index]
	var id = b.get("id")
	print("Generating icon for: " + id)
	
	var scene_path = "res://scenes/buildables/" + id + ".tscn"
	if not ResourceLoader.exists(scene_path):
		print("Scene not found: " + scene_path + ", skipping...")
		_generate_next(targets, index + 1)
		return
		
	var scene = load(scene_path)
	var inst = scene.instantiate()
	
	# Create SubViewport
	var vp = SubViewport.new()
	vp.size = Vector2i(256, 256)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	
	# Setup Lighting
	var light = DirectionalLight3D.new()
	# Standard Isometric Light Angle
	light.transform.basis = Basis().rotated(Vector3.RIGHT, deg_to_rad(-45)).rotated(Vector3.UP, deg_to_rad(45))
	light.light_energy = 1.2
	vp.add_child(light)
	
	# Explicitly enforce transparent background in the environment
	var env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0, 0, 0, 0)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.6, 0.6)
	var we = WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	
	vp.add_child(inst)
	
	# Setup Camera
	var cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	
	# Compute dimensions from grid size in building JSON
	var w = 1.0
	var h = 1.0
	if b.has("grid"):
		w = float(b["grid"].get("width", 1))
		h = float(b["grid"].get("height", 1))
	elif b.has("visuals") and b["visuals"].has("width"):
		var w_px = float(b["visuals"].get("width", 32))
		var h_px = float(b["visuals"].get("height", 32))
		w = max(1.0, w_px / 32.0)
		h = max(1.0, h_px / 32.0)
	
	# Isometric projection math to perfectly frame the bounding box
	var horizontal_fit = (w + h) * 0.354 + 1.2
	var vertical_fit = (w + h) * 0.204 + 1.2 # Includes padding for building height
	cam.size = max(horizontal_fit, vertical_fit) * 1.15 # 15% overall padding
	
	vp.add_child(cam)
	
	# Position ISO camera
	# Center Y bumped to 0.8 to better frame the taller portions of structures
	var center = Vector3((w - 1) * 0.7, 0.8, (h - 1) * 0.7)
	var offset = Vector3(10, 10, 10) # Diagonal ISO
	cam.global_position = center + offset
	cam.look_at(center, Vector3.UP)
	
	# Wait for the viewport to render internally
	await get_tree().process_frame
	await get_tree().process_frame
	
	var img = vp.get_texture().get_image()
	if img:
		var save_path = "res://assets/icons/" + id + ".png"
		var err = img.save_png(save_path)
		if err == OK:
			print("Saved icon to " + save_path)
		else:
			printerr("Failed to save " + save_path)
		
	vp.queue_free()
	
	# Process next target
	call_deferred("_generate_next", targets, index + 1)
