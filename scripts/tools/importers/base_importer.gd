@tool
class_name BaseImporter
extends RefCounted

## Base class for specific content importers. 
## Provides shared constants, paths, and utility functions for resource/scene generation.

const CONTENT_DIR = "res://data/content/"
const RESOURCE_BASE_PATH = "res://resources/"

const SCENE_BUILDABLES_PATH = "res://scenes/buildables/"
const SCENE_ENEMIES_PATH = "res://scenes/enemies/"
const SCENE_ALLIES_PATH = "res://scenes/allies/"
const SCENE_CLUTTER_PATH = "res://scenes/clutter/"

const ELEMENT_SCRIPT = "res://scripts/resources/element_resource.gd"
const ITEM_SCRIPT = "res://scripts/resources/item_resource.gd"
const RECIPE_SCRIPT = "res://scripts/resources/recipe_resource.gd"
const ENEMY_SCRIPT = "res://scripts/resources/enemy_resource.gd"
const ALLY_SCRIPT = "res://scripts/resources/ally_resource.gd"
const BUILDABLE_SCRIPT = "res://scripts/resources/buildable_resource.gd"
const CLUTTER_SCRIPT = "res://scripts/resources/clutter_resource.gd"

# Component Script Paths
const COMP_SHOOTER = "res://scripts/components/shooter_component.gd"
const COMP_TARGET = "res://scripts/components/target_acquirer_component.gd"
const COMP_HEALTH = "res://scripts/components/health_component.gd"
const COMP_ATTACKER = "res://scripts/components/attacker_component.gd"
const COMP_MOVE = "res://scripts/components/move_component.gd"
const COMP_INVENTORY = "res://scripts/components/inventory_component.gd"
const COMP_CRAFTER = "res://scripts/components/crafter_component.gd"
const COMP_ELEMENTAL = "res://scripts/components/elemental_component.gd"
const COMP_GRID = "res://scripts/components/grid_component.gd"

const ENTITY_ENEMY_SCRIPT = "res://scripts/entities/enemy.gd"
const ENTITY_ALLY_SCRIPT = "res://scripts/entities/ally.gd"
const ENTITY_CLUTTER_SCRIPT = "res://scripts/entities/clutter_object.gd"

var target_item_id: String = "All"
var overwrite_existing: bool = false

func _init(p_target_id: String = "All", p_overwrite: bool = false) -> void:
	target_item_id = p_target_id
	overwrite_existing = p_overwrite

func _get_or_create_resource(path: String, script_class: Object) -> Resource:
	if ResourceLoader.exists(path):
		var res = load(path)
		if res: return res
		else: print("Importer: Found corrupted resource at %s, recreating..." % path)
	return script_class.new()

func _should_process(id: String, file_path: String) -> bool:
	if target_item_id != "All" and id != target_item_id: return false
	if not ResourceLoader.exists(file_path): return true
	return overwrite_existing

func _resolve_resource_id(id_str: String) -> Resource:
	# Check Item
	var item_path = RESOURCE_BASE_PATH + "items/" + id_str + ".tres"
	if ResourceLoader.exists(item_path): return load(item_path)
	# Check Buildable
	var build_path = RESOURCE_BASE_PATH + "buildables/" + id_str + ".tres"
	if ResourceLoader.exists(build_path): return load(build_path)
	return null

func _add_component(parent: Node, script_path: String, _name: String) -> Node:
	var script = load(script_path)
	if not script or not script.has_method("new"): return null
	var node = script.new()
	node.name = _name
	parent.add_child(node)
	return node

func _apply_param(node: Node, key: String, val: Variant) -> void:
	if ":" in key:
		var p = key.split(":")
		var child = node.get_node_or_null(p[0])
		if child: child.set(p[1], val)
	else:
		node.set(key, val)

func _apply_logic_params(inst: Node, data: Dictionary) -> void:
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

func _save_scene(root_node: Node, path: String) -> void:
	_set_owner_recursive(root_node, root_node)
	var packed = PackedScene.new()
	packed.pack(root_node)
	ResourceSaver.save(packed, path)
	root_node.queue_free()

func _set_owner_recursive(node: Node, root: Node) -> void:
	if node != root: node.owner = root
	for c in node.get_children(): _set_owner_recursive(c, root)

# --- VISUAL HELPERS ---

func _add_visuals(parent: Node, vdata: Dictionary) -> void:
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

func _create_advanced_block_mesh(base_path: String, size: Vector3, is_on_state: bool, align_bottom: bool) -> ArrayMesh:
	var st = SurfaceTool.new()
	var mesh = ArrayMesh.new()
	var ext = base_path.get_extension()
	var base_no_ext = base_path.get_basename()
	
	var get_tex = func(face_suffix: String) -> String:
		var candidates =[]
		if is_on_state: candidates.append(base_no_ext + "_" + face_suffix + "_on." + ext)
		candidates.append(base_no_ext + "_" + face_suffix + "." + ext)
		if is_on_state: candidates.append(base_no_ext + "_on." + ext)
		candidates.append(base_path)
		for p in candidates:
			if ResourceLoader.exists(p): return p
		return base_path 
		
	var faces =[
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

func _add_face_geometry(st: SurfaceTool, normal: Vector3, h: Vector3, offset: Vector3) -> void:
	var u00 = Vector2(1, 0); var u10 = Vector2(0, 0); var u11 = Vector2(0, 1); var u01 = Vector2(1, 1)
	var v =[]
	if normal == Vector3.UP: v =[Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)]
	elif normal == Vector3.DOWN: v =[Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, -h.y, -h.z), Vector3(-h.x, -h.y, -h.z)]
	elif normal == Vector3.FORWARD: v =[Vector3(-h.x, h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(-h.x, -h.y, h.z)]
	elif normal == Vector3.BACK: v =[Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z), Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z)]
	elif normal == Vector3.LEFT: v =[Vector3(-h.x, h.y, -h.z), Vector3(-h.x, h.y, h.z), Vector3(-h.x, -h.y, h.z), Vector3(-h.x, -h.y, -h.z)]
	elif normal == Vector3.RIGHT: v =[Vector3(h.x, h.y, h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, -h.y, h.z)]
	for i in range(v.size()): v[i] += offset
	st.set_uv(u00); st.add_vertex(v[0]); st.set_uv(u10); st.add_vertex(v[1]); st.set_uv(u11); st.add_vertex(v[2])
	st.set_uv(u00); st.add_vertex(v[0]); st.set_uv(u11); st.add_vertex(v[2]); st.set_uv(u01); st.add_vertex(v[3])

func _process_3d_sprite_frames(anim_sprite: AnimatedSprite3D, vdata: Dictionary) -> void:
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
	
	# Fix: Actually assign the created frames to the sprite
	anim_sprite.sprite_frames = frames

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

