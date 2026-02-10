class_name WorldProgressBar
extends Node3D

## A modular, modern 3D progress bar that billboards to the camera.

@export var width: float = 1.0
@export var height: float = 0.15
@export var border_size: float = 0.02

var _bar_container: Node3D
var _fill_mesh: MeshInstance3D

var progress: float = 0.0:
	set(value):
		progress = clamp(value, 0.0, 1.0)
		_update_fill()

var fill_color: Color = Color(0.2, 0.9, 0.3):
	set(value):
		fill_color = value
		if _fill_mesh and _fill_mesh.material_override:
			_fill_mesh.material_override.albedo_color = fill_color

func _ready() -> void:
	_setup_visuals()

func _setup_visuals() -> void:
	for c in get_children(): c.queue_free()
	
	_bar_container = Node3D.new()
	add_child(_bar_container)
	
	# Common material settings
	var mat_base = StandardMaterial3D.new()
	mat_base.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_base.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat_base.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED # rely on render priority
	mat_base.cull_mode = BaseMaterial3D.CULL_DISABLED
	
	# 1. Border (Black)
	var mat_border = mat_base.duplicate()
	mat_border.albedo_color = Color(0.0, 0.0, 0.0, 0.8)
	mat_border.render_priority = 10
	
	var border = MeshInstance3D.new()
	border.mesh = QuadMesh.new()
	border.mesh.size = Vector2(width + border_size*2, height + border_size*2)
	border.material_override = mat_border
	_bar_container.add_child(border)
	
	# 2. Background (Dark)
	var mat_bg = mat_base.duplicate()
	mat_bg.albedo_color = Color(0.1, 0.1, 0.1, 0.6)
	mat_bg.render_priority = 11
	
	var bg = MeshInstance3D.new()
	bg.mesh = QuadMesh.new()
	bg.mesh.size = Vector2(width, height)
	bg.material_override = mat_bg
	_bar_container.add_child(bg)
	
	# 3. Fill Pivot (Left aligned)
	var pivot = Node3D.new()
	# Move pivot to left edge. Z-offset ensures it sits in front of BG
	pivot.position = Vector3(-width / 2.0, 0, 0.005) 
	_bar_container.add_child(pivot)
	
	# 4. Fill Mesh
	var mat_fill = mat_base.duplicate()
	mat_fill.albedo_color = fill_color
	mat_fill.render_priority = 12
	
	_fill_mesh = MeshInstance3D.new()
	_fill_mesh.mesh = QuadMesh.new()
	_fill_mesh.mesh.size = Vector2(width, height)
	# Shift mesh right so its left edge is at (0,0,0) of the pivot
	_fill_mesh.position = Vector3(width / 2.0, 0, 0)
	_fill_mesh.material_override = mat_fill
	
	# Store pivot on mesh meta to access it later easily
	_fill_mesh.set_meta("pivot", pivot)
	pivot.add_child(_fill_mesh)
	
	_update_fill()

func _update_fill() -> void:
	if not _fill_mesh: return
	var pivot = _fill_mesh.get_meta("pivot") as Node3D
	if pivot:
		pivot.scale.x = max(progress, 0.001)
	
	visible = progress > 0.0 and progress < 1.0

func _process(_delta: float) -> void:
	if visible:
		var cam = get_viewport().get_camera_3d()
		if cam:
			# Billboard to camera
			# look_at points the -Z axis towards the target.
			# QuadMesh faces +Z. So we want +Z to point AT the camera.
			# Therefore, we want -Z to point AWAY from the camera.
			# Target = Pos + (Pos - CamPos)
			var look_target = global_position + (global_position - cam.global_position)
			look_at(look_target, Vector3.UP)

func set_label_visible(_state: bool) -> void: pass
