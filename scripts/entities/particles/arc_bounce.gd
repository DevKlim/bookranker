extends Node3D

@onready var mesh_inst = $MeshInstance3D
@onready var light = $OmniLight3D

func setup(start_pos: Vector3, end_pos: Vector3) -> void:
	# Center the arc exactly between the two targets
	var mid = start_pos.lerp(end_pos, 0.5)
	global_position = mid
	
	# look_at inherently aligns the node's -Z axis to the target.
	# We compute a safe UP vector to avoid gimbal lock if paths are strictly vertical.
	var dir = start_pos.direction_to(end_pos)
	var up_vec = Vector3.UP
	if abs(dir.y) > 0.99:
		up_vec = Vector3.RIGHT
		
	look_at(end_pos, up_vec)
	
	# Scale the BoxMesh Z-axis to the exact distance, bridging the gap entirely
	var dist = start_pos.distance_to(end_pos)
	mesh_inst.mesh.size = Vector3(0.3, 0.3, dist)
	
	var mat = mesh_inst.get_active_material(0)
	if not mat:
		mat = ShaderMaterial.new()
		mesh_inst.set_surface_override_material(0, mat)
	else:
		mat = mat.duplicate()
		mesh_inst.set_surface_override_material(0, mat)
		
	if mat is ShaderMaterial:
		mat.set_shader_parameter("uv_scale", Vector2(1.0, dist * 0.5))

	var tween = create_tween()
	tween.tween_method(func(v): if mat is ShaderMaterial: mat.set_shader_parameter("alpha_mult", v), 1.0, 0.0, 0.35).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(light, "light_energy", 0.0, 0.35)
	tween.tween_callback(queue_free)
