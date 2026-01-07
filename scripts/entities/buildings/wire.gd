@tool
class_name Wire
extends BaseWiring

# Neon Blue for Powered, Dark Blue (made brighter) for Unpowered to increase visibility
const COLOR_OFF = Color(0.1, 0.1, 0.7) 
const COLOR_ON = Color(0.2, 0.9, 1.0) 

# Textures
const TEX_DOT = preload("res://assets/wires/wire_dot.png")
const TEX_LINE = preload("res://assets/wires/wire_line.png")

var is_powered: bool = false
# Connections: 1:left, 2:down, 3:right, 4:up (Matches Godot Grid directions)
var connections: Array[int] = []

var _meshes: Dictionary = {} 

func _ready() -> void:
	# Cleanup any old nodes
	for child in get_children():
		if child is MeshInstance3D or child is Sprite3D:
			child.queue_free()
	
	_setup_meshes()
	super._ready()
	
	# Force an initial update
	is_powered = false 
	update_visuals()

func _setup_meshes() -> void:
	# 1. Dot (Center Hub)
	# Full grid size (1.0) as requested
	var dot = _create_mesh_instance(TEX_DOT, Vector2(1.0, 1.0), false)
	dot.name = "Dot_Mesh"
	dot.position.y = 0.01 
	add_child(dot)
	_meshes["dot"] = dot
	
	# 2. Lines (Directional Arms)
	var configs = {
		1: -PI * 0.5,
		2: 0.0,
		3: PI * 0.5,
		4: PI
	}
	
	for dir in configs:
		# Width 1.0 to span full tile width, Length 0.5 to span center to edge
		var line = _create_mesh_instance(TEX_LINE, Vector2(1.0, 0.5), true)
		line.name = "Line_%d" % dir
		line.rotation.y = configs[dir]
		
		# Move forward 0.25 (half length) so it spans from 0 to 0.5
		var forward_vec = Vector3(0, 0, 0.25).rotated(Vector3.UP, configs[dir])
		line.position = Vector3(0, 0.01, 0) + forward_vec
		
		add_child(line)
		_meshes[dir] = line

func _create_mesh_instance(tex: Texture2D, size: Vector2, is_half_crop: bool) -> MeshInstance3D:
	var mesh_inst = MeshInstance3D.new()
	var mesh = ArrayMesh.new()
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var w = size.x * 0.5
	var l = size.y * 0.5
	
	var uv_min_y = 0.0
	var uv_max_y = 1.0
	if is_half_crop: uv_max_y = 0.5
	
	var p1 = Vector3(-w, 0, -l) # Top Left
	var p2 = Vector3(w, 0, -l)  # Top Right
	var p3 = Vector3(-w, 0, l)  # Bottom Left
	var p4 = Vector3(w, 0, l)   # Bottom Right
	
	var uv1 = Vector2(0, uv_min_y)
	var uv2 = Vector2(1, uv_min_y)
	var uv3 = Vector2(0, uv_max_y)
	var uv4 = Vector2(1, uv_max_y)

	st.set_normal(Vector3.UP); st.set_uv(uv1); st.add_vertex(p1)
	st.set_normal(Vector3.UP); st.set_uv(uv2); st.add_vertex(p2)
	st.set_normal(Vector3.UP); st.set_uv(uv3); st.add_vertex(p3)
	
	st.set_normal(Vector3.UP); st.set_uv(uv2); st.add_vertex(p2)
	st.set_normal(Vector3.UP); st.set_uv(uv4); st.add_vertex(p4)
	st.set_normal(Vector3.UP); st.set_uv(uv3); st.add_vertex(p3)
	
	st.commit(mesh)
	mesh_inst.mesh = mesh
	
	var mat = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_texture = tex
	mat.albedo_color = COLOR_OFF
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	
	mesh_inst.material_override = mat
	
	if visual_offset != Vector3.ZERO:
		mesh_inst.position += visual_offset
		
	return mesh_inst

func set_powered(p_is_powered: bool) -> void:
	if is_powered != p_is_powered:
		is_powered = p_is_powered
		update_visuals()

func set_connections(p_connections: Array[int]) -> void:
	p_connections.sort()
	if connections != p_connections:
		connections = p_connections
		update_visuals()

func update_visuals() -> void:
	var col = COLOR_ON if is_powered else COLOR_OFF
	
	# If we have any connections, hide the central dot (lines handle the visual flow)
	# If no connections (isolated wire), show dot so it's visible.
	if _meshes.has("dot"):
		var m = _meshes["dot"]
		m.visible = connections.is_empty()
		if m.material_override:
			m.material_override.albedo_color = col
	
	for dir in [1, 2, 3, 4]:
		if _meshes.has(dir):
			var m = _meshes[dir]
			m.visible = (dir in connections)
			if m.material_override:
				m.material_override.albedo_color = col
