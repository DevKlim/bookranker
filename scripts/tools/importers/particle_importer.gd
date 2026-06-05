@tool
class_name ParticleImporter
extends BaseImporter

## Generates functional GPU Particle Scenes & Resources dynamically from JSON.

func import_particles(list: Array) -> void:
	var script = load("res://scripts/entities/particles/particle_effect.gd")
	var out_dir = "res://scenes/particles/"
	var res_dir = "res://resources/particles/"
	
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("scenes/particles"):
		dir.make_dir_recursive("scenes/particles")
	if not dir.dir_exists("resources/particles"):
		dir.make_dir_recursive("resources/particles")
		
	for entry in list:
		if not entry is Dictionary: continue
		var id = str(entry.get("id", "unknown"))
		var path = out_dir + id + ".tscn"
		var res_path = res_dir + id + ".tres"
		
		if not _should_process(id, path): continue
		
		# 1. Build the Node3D Root
		var root = Node3D.new()
		root.name = id.capitalize().replace("_", "")
		root.set_script(script)
		
		# 2. Attach Custom Script Variables to Root
		root.set("dynamic_direction", entry.get("dynamic_direction", false))
		root.set("base_speed_min", float(entry.get("velocity_min", 1.0)))
		root.set("base_speed_max", float(entry.get("velocity_max", 3.0)))
		
		# 3. Create the Main GPUParticles3D Child
		var node = GPUParticles3D.new()
		node.name = "MainEmitter"
		node.amount = int(entry.get("amount", 10))
		node.lifetime = float(entry.get("lifetime", 1.0))
		node.explosiveness = float(entry.get("explosiveness", 0.0))
		node.one_shot = true
		node.emitting = false
		root.add_child(node)
		node.owner = root
		
		if entry.get("omnilight", false):
			var light = OmniLight3D.new()
			light.name = "OmniLight"
			light.light_color = Color(entry.get("light_color", entry.get("color", "#ffffff")))
			light.light_energy = float(entry.get("light_energy", 1.0))
			light.omni_range = float(entry.get("light_range", 5.0))
			root.add_child(light)
			light.owner = root
		
		# 4. Compile Material 3D
		var pass_mesh = QuadMesh.new()
		pass_mesh.size = Vector2(1.0, 1.0)
		
		if entry.has("shader"):
			var smat = ShaderMaterial.new()
			var shader = load("res://shaders/" + entry["shader"])
			if shader:
				smat.shader = shader
				if entry.has("shader_params"):
					for k in entry["shader_params"].keys():
						var val = entry["shader_params"][k]
						if typeof(val) == TYPE_STRING and val.begins_with("#"):
							smat.set_shader_parameter(k, Color(val))
						else:
							smat.set_shader_parameter(k, val)
			pass_mesh.material = smat
		else:
			var mat = StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
			mat.vertex_color_use_as_albedo = true
			
			if entry.has("color"): mat.albedo_color = Color(entry["color"])
			if entry.get("blend_add", false): mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			if entry.has("texture"):
				var tex = load("res://assets/textures/particles/" + entry["texture"])
				if tex: mat.albedo_texture = tex
			pass_mesh.material = mat
			
		node.draw_pass_1 = pass_mesh
		
		# 5. Compile GPU Process Material
		var p_mat = ParticleProcessMaterial.new()
		
		if entry.get("collision", false):
			p_mat.collision_mode = ParticleProcessMaterial.COLLISION_RIGID
			p_mat.collision_friction = 0.5
			p_mat.collision_bounce = 0.5
		
		var grav = entry.get("gravity", [0, 1, 0])
		p_mat.gravity = Vector3(grav[0], grav[1], grav[2])
		
		if entry.has("direction"):
			var dir_val = entry["direction"]
			p_mat.direction = Vector3(dir_val[0], dir_val[1], dir_val[2])
			
		p_mat.spread = float(entry.get("spread", 45.0))
		p_mat.initial_velocity_min = float(entry.get("velocity_min", 1.0))
		p_mat.initial_velocity_max = float(entry.get("velocity_max", 3.0))
		
		if entry.has("angle_min"): p_mat.angle_min = float(entry["angle_min"])
		if entry.has("angle_max"): p_mat.angle_max = float(entry["angle_max"])
		if entry.has("radial_accel_min"): p_mat.radial_accel_min = float(entry["radial_accel_min"])
		if entry.has("radial_accel_max"): p_mat.radial_accel_max = float(entry["radial_accel_max"])
		
		if entry.get("emission_sphere", false):
			p_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
			p_mat.emission_sphere_radius = float(entry.get("emission_radius", 1.0))
			
		if entry.get("use_scale_curve", true):
			var sc = Curve.new()
			sc.add_point(Vector2(0, 0.1))
			sc.add_point(Vector2(0.3, 1.0))
			sc.add_point(Vector2(1.0, 0.0))
			var st = CurveTexture.new()
			st.curve = sc
			p_mat.scale_curve = st
			
		if entry.get("use_color_ramp", true):
			var grad = Gradient.new()
			grad.add_point(0.0, Color(1, 1, 1, 1))
			grad.add_point(0.7, Color(1, 1, 1, 0.8))
			grad.add_point(1.0, Color(1, 1, 1, 0.0))
			var gt = GradientTexture1D.new()
			gt.gradient = grad
			p_mat.color_ramp = gt
			
		node.process_material = p_mat
		
		# 6. Pack Scene
		var packed = PackedScene.new()
		packed.pack(root)
		ResourceSaver.save(packed, path)
		root.queue_free()
		
		# 7. Build the ECS Component Meta Resource
		var res = Resource.new()
		res.set_script(load("res://scripts/resources/particle_resource.gd"))
		res.set("id", id)
		res.set("scene", load(path))
		ResourceSaver.save(res, res_path)
