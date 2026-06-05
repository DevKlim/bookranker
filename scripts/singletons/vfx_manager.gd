extends Node
class_name VFXManager

var particle_cache: Dictionary = {}

func play_vfx(vfx_name: String, pos: Vector3, target_pos: Vector3 = Vector3.INF) -> void:
	if vfx_name == "y2k_reaction":
		_play_y2k_reaction(pos)
		return
	elif vfx_name == "fold_craft":
		_play_fold_craft(pos)
		return
	elif vfx_name == "mod_install":
		_play_mod_install(pos)
		return
	elif vfx_name == "mod_install_cursed":
		_play_mod_install_cursed(pos)
		return
	elif vfx_name == "y2k_glitch":
		_play_y2k_glitch(pos)
		return

	var scene: PackedScene = null
	
	if particle_cache.has(vfx_name):
		scene = particle_cache[vfx_name]
	else:
		var path = "res://scenes/particles/" + vfx_name + ".tscn"
		if ResourceLoader.exists(path):
			scene = load(path)
			particle_cache[vfx_name] = scene
			
	if scene:
		var inst = scene.instantiate()
		get_tree().current_scene.add_child(inst)
		inst.global_position = pos + Vector3(0, 0.5, 0)
		
		# Execute the base effect parameters initialized by our JSON config
		if inst.has_method("initialize"):
			inst.initialize(target_pos)
	else:
		# MODDING/ECS GRACEFUL FALLBACK
		# If an element/reaction has no physical scene, generate procedural Y2K VFX
		var color_map = {
			"igni": Color(1.0, 0.3, 0.0),
			"aqua": Color(0.0, 0.7, 1.0),
			"volt": Color(1.0, 1.0, 0.0),
			"abyss": Color(0.6, 0.0, 1.0),
			"light": Color(1.0, 1.0, 0.8),
			"plasma": Color(1.0, 0.0, 1.0),
			"hurt": Color(1.0, 0.2, 0.2),
			"shield_break": Color(0.3, 0.6, 1.0)
		}
		
		var fallback_color = color_map.get(vfx_name, Color(0.8, 1.0, 0.8))
		_play_dynamic_y2k_particle(pos, fallback_color)

func _play_dynamic_y2k_particle(pos: Vector3, color: Color) -> void:
	# Build a complex, multi-layered Dreamcast-esque particle system programmatically
	var root = Node3D.new()
	get_tree().current_scene.add_child(root)
	root.global_position = pos + Vector3(0, 0.5, 0)
	
	# 1. Burst Particles
	var parts = GPUParticles3D.new()
	var p_mat = ParticleProcessMaterial.new()
	p_mat.direction = Vector3(0, 1, 0)
	p_mat.spread = 180.0
	p_mat.initial_velocity_min = 4.0
	p_mat.initial_velocity_max = 8.0
	p_mat.gravity = Vector3(0, 2.0, 0)
	p_mat.scale_min = 0.8
	p_mat.scale_max = 2.0
	p_mat.color = color
	
	var gradient = GradientTexture1D.new()
	gradient.gradient = Gradient.new()
	gradient.gradient.colors = PackedColorArray([Color(1,1,1,1), Color(1,1,1,0)])
	p_mat.color_ramp = gradient
	
	parts.process_material = p_mat
	
	var mesh = QuadMesh.new()
	mesh.size = Vector2(0.6, 0.6)
	
	var s_mat = ShaderMaterial.new()
	s_mat.shader = load("res://shaders/y2k_particle_reaction.gdshader")
	if s_mat.shader:
		var noise_tex = load("res://assets/textures/noise/Techno/Techno_01-256x256.png")
		if noise_tex: s_mat.set_shader_parameter("noise_tex", noise_tex)
		var tex_names = ["effect/effect_01_a.png", "effect/effect_03_a.png", "stars/star_02_a.png", "twirl/twirl_02_a.png"]
		var tex_path = "res://assets/textures/particles/" + tex_names.pick_random()
		if ResourceLoader.exists(tex_path):
			s_mat.set_shader_parameter("texture_albedo", load(tex_path))
		s_mat.set_shader_parameter("erosion_speed", 2.0)
	else:
		s_mat = StandardMaterial3D.new()
		s_mat.albedo_color = color
		s_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		s_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		s_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		s_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		
	mesh.material = s_mat
	parts.draw_pass_1 = mesh
	
	parts.emitting = true
	parts.one_shot = true
	parts.explosiveness = 0.95
	parts.amount = 25
	parts.lifetime = 0.8
	root.add_child(parts)

	# 2. Geometric Y2K Shockwave
	var ring = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 0.8
	torus.outer_radius = 1.0
	torus.rings = 32
	torus.radial_segments = 16
	ring.mesh = torus
	var r_mat = StandardMaterial3D.new()
	r_mat.albedo_color = color
	r_mat.emission_enabled = true
	r_mat.emission = color
	r_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	r_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	r_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = r_mat
	root.add_child(ring)
	
	ring.scale = Vector3(0.1, 0.1, 0.1)
	
	var tween = root.create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(4.0, 0.1, 4.0), 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "rotation_degrees", Vector3(randf_range(-15, 15), randf_range(0, 360), randf_range(-15, 15)), 0.6)
	tween.tween_property(r_mat, "albedo_color:a", 0.0, 0.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	
	# 3. Y2K Elemental Burst Shader Sphere
	var sphere = MeshInstance3D.new()
	var s_mesh = SphereMesh.new()
	s_mesh.radial_segments = 16
	s_mesh.rings = 16
	sphere.mesh = s_mesh
	var sphere_mat = ShaderMaterial.new()
	
	var burst_shader_path = "res://shaders/y2k_elemental_burst.gdshader"
	if ResourceLoader.exists(burst_shader_path):
		sphere_mat.shader = load(burst_shader_path)
		sphere_mat.set_shader_parameter("burst_color", color)
		var noise_tex = load("res://assets/textures/noise/Swirl/Swirl_01-256x256.png")
		if noise_tex: sphere_mat.set_shader_parameter("noise_tex", noise_tex)
		sphere_mat.set_shader_parameter("erosion", 0.0)
	else:
		sphere_mat = StandardMaterial3D.new()
		sphere_mat.albedo_color = color
		sphere_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		sphere_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		sphere_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		
	sphere.material_override = sphere_mat
	root.add_child(sphere)
	
	sphere.scale = Vector3(0.1, 0.1, 0.1)
	tween.tween_property(sphere, "scale", Vector3(3.0, 3.0, 3.0), 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if sphere_mat is ShaderMaterial:
		tween.tween_property(sphere_mat, "shader_parameter/erosion", 1.0, 0.7).set_delay(0.1)
	else:
		tween.tween_property(sphere_mat, "albedo_color:a", 0.0, 0.5).set_delay(0.2)

	tween.chain().tween_callback(root.queue_free)

func _play_y2k_reaction(pos: Vector3) -> void:
	# Spawns a multi-layered retro explosion (Gamecube / Y2K style)
	var root = Node3D.new()
	get_tree().current_scene.add_child(root)
	root.global_position = pos + Vector3(0, 0.5, 0)
	
	# 1. Inner core flash (Spinning shrinking cube)
	var core = MeshInstance3D.new()
	var box = BoxMesh.new()
	core.mesh = box
	var c_mat = StandardMaterial3D.new()
	c_mat.albedo_color = Color(0.9, 0.1, 0.5, 1.0)
	c_mat.emission_enabled = true
	c_mat.emission = Color(0.9, 0.1, 0.5, 1.0)
	c_mat.emission_energy_multiplier = 2.0
	c_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	core.material_override = c_mat
	root.add_child(core)
	
	# 2. Outer Complex Shader Sphere (Dissolving Energy)
	var outer = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radial_segments = 16
	sphere.rings = 16
	outer.mesh = sphere
	
	var o_mat = ShaderMaterial.new()
	o_mat.shader = load("res://shaders/y2k_reaction.gdshader")
	if o_mat.shader:
		var noise_tex = load("res://assets/textures/noise/Techno/Techno_01-256x256.png")
		if noise_tex: o_mat.set_shader_parameter("noise_tex", noise_tex)
		o_mat.set_shader_parameter("emission_color", Color(0.2, 0.9, 1.0, 0.8))
		o_mat.set_shader_parameter("erosion", 0.0)
		o_mat.set_shader_parameter("distortion_strength", 0.3)
	else:
		o_mat = StandardMaterial3D.new()
		o_mat.albedo_color = Color(0.1, 0.8, 0.9, 0.5)
		o_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		
	outer.material_override = o_mat
	root.add_child(outer)
	
	# 3. Y2K Tech Rings (Expanding outward quickly)
	var ring = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 0.8
	torus.outer_radius = 1.0
	ring.mesh = torus
	var r_mat = StandardMaterial3D.new()
	r_mat.albedo_color = Color(1.0, 1.0, 0.2, 1.0)
	r_mat.emission_enabled = true
	r_mat.emission = Color(1.0, 1.0, 0.2, 1.0)
	r_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = r_mat
	root.add_child(ring)
	
	ring.rotation_degrees = Vector3(randf_range(-45, 45), randf_range(0, 360), randf_range(-45, 45))

	var tween = root.create_tween().set_parallel(true)
	
	tween.tween_property(core, "scale", Vector3(0.1, 0.1, 0.1), 0.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(core, "rotation", Vector3(PI, PI, 0), 0.5)
	tween.tween_property(c_mat, "albedo_color:a", 0.0, 0.5)
	
	tween.tween_property(outer, "scale", Vector3(4.5, 4.5, 4.5), 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if o_mat is ShaderMaterial:
		tween.tween_property(o_mat, "shader_parameter/erosion", 1.0, 0.7)
	else:
		tween.tween_property(o_mat, "albedo_color:a", 0.0, 0.7)
	
	tween.tween_property(ring, "scale", Vector3(5.0, 0.1, 5.0), 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(r_mat, "albedo_color:a", 0.0, 0.8)
	
	tween.chain().tween_callback(root.queue_free)

func _play_fold_craft(pos: Vector3) -> void:
	var parts = GPUParticles3D.new()
	var p_mat = ParticleProcessMaterial.new()
	p_mat.direction = Vector3(0, 1, 0)
	p_mat.initial_velocity_min = 2.0
	p_mat.initial_velocity_max = 4.0
	p_mat.gravity = Vector3(0, -2, 0)
	p_mat.color = Color(1.0, 1.0, 1.0, 0.8)
	
	var gradient = GradientTexture1D.new()
	gradient.gradient = Gradient.new()
	gradient.gradient.colors = PackedColorArray([Color(1,1,1,1), Color(1,1,1,0)])
	p_mat.color_ramp = gradient
	parts.process_material = p_mat
	
	var mesh = QuadMesh.new()
	mesh.size = Vector2(0.3, 0.3)
	var s_mat = StandardMaterial3D.new()
	s_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	s_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	s_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	s_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mesh.material = s_mat
	parts.draw_pass_1 = mesh
	
	parts.emitting = true
	parts.one_shot = true
	parts.explosiveness = 0.8
	parts.amount = 15
	parts.lifetime = 0.6
	
	get_tree().current_scene.add_child(parts)
	parts.global_position = pos + Vector3(0, 0.5, 0)
	
	get_tree().create_timer(1.0).timeout.connect(parts.queue_free)

func _play_mod_install(pos: Vector3) -> void:
	# A holographic burst of data
	var root = Node3D.new()
	get_tree().current_scene.add_child(root)
	root.global_position = pos + Vector3(0, 1.0, 0)
	
	var ring = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 0.8
	torus.outer_radius = 1.0
	ring.mesh = torus
	var r_mat = StandardMaterial3D.new()
	r_mat.albedo_color = Color(0.2, 1.0, 0.5, 1.0)
	r_mat.emission_enabled = true
	r_mat.emission = Color(0.2, 1.0, 0.5, 1.0)
	r_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = r_mat
	root.add_child(ring)
	
	ring.scale = Vector3(0.1, 0.1, 0.1)
	
	var parts = GPUParticles3D.new()
	var p_mat = ParticleProcessMaterial.new()
	p_mat.direction = Vector3(0, 1, 0)
	p_mat.spread = 90.0
	p_mat.initial_velocity_min = 2.0
	p_mat.initial_velocity_max = 5.0
	p_mat.gravity = Vector3(0, -1.0, 0)
	p_mat.color = Color(0.2, 1.0, 0.5, 0.8)
	parts.process_material = p_mat
	
	var mesh = QuadMesh.new()
	mesh.size = Vector2(0.2, 0.2)
	var s_mat = StandardMaterial3D.new()
	s_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	s_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	s_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	s_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mesh.material = s_mat
	parts.draw_pass_1 = mesh
	
	parts.emitting = true
	parts.one_shot = true
	parts.explosiveness = 0.9
	parts.amount = 30
	parts.lifetime = 1.0
	root.add_child(parts)

	var tween = root.create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(3.0, 3.0, 3.0), 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "rotation_degrees:y", 180.0, 0.6)
	tween.tween_property(r_mat, "albedo_color:a", 0.0, 0.6)
	
	tween.chain().tween_callback(root.queue_free)

func _play_mod_install_cursed(pos: Vector3) -> void:
	var root = Node3D.new()
	get_tree().current_scene.add_child(root)
	root.global_position = pos + Vector3(0, 1.0, 0)
	
	# Hexagonal cylinder glitch wall for aggressive visual
	var cyl = MeshInstance3D.new()
	var c_mesh = CylinderMesh.new()
	c_mesh.radial_segments = 6
	c_mesh.top_radius = 2.0
	c_mesh.bottom_radius = 2.0
	c_mesh.height = 4.0
	cyl.mesh = c_mesh
	
	var c_mat = StandardMaterial3D.new()
	c_mat.albedo_color = Color(1.0, 0.0, 0.2, 0.5)
	c_mat.emission_enabled = true
	c_mat.emission = Color(1.0, 0.0, 0.2, 1.0)
	c_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	c_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	c_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cyl.material_override = c_mat
	root.add_child(cyl)
	
	var ring = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 1.8
	torus.outer_radius = 2.0
	torus.radial_segments = 6
	ring.mesh = torus
	var r_mat = StandardMaterial3D.new()
	r_mat.albedo_color = Color(1.0, 0.0, 0.2, 1.0)
	r_mat.emission_enabled = true
	r_mat.emission = Color(1.0, 0.0, 0.2, 1.0)
	r_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	r_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ring.material_override = r_mat
	root.add_child(ring)
	
	cyl.scale = Vector3(1.0, 0.0, 1.0)
	ring.scale = Vector3(1.0, 1.0, 1.0)
	ring.position.y = -2.0
	
	var parts = GPUParticles3D.new()
	var p_mat = ParticleProcessMaterial.new()
	p_mat.direction = Vector3(0, 1, 0)
	p_mat.spread = 0.0
	p_mat.initial_velocity_min = 5.0
	p_mat.initial_velocity_max = 10.0
	p_mat.gravity = Vector3(0, 0, 0)
	p_mat.color = Color(1.0, 0.0, 0.2, 0.8)
	p_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	p_mat.emission_ring_radius = 2.0
	p_mat.emission_ring_inner_radius = 1.8
	p_mat.emission_ring_height = 0.0
	p_mat.emission_ring_axis = Vector3(0, 1, 0)
	
	var gradient = GradientTexture1D.new()
	gradient.gradient = Gradient.new()
	gradient.gradient.colors = PackedColorArray([Color(1,1,1,1), Color(1,1,1,0)])
	p_mat.color_ramp = gradient
	parts.process_material = p_mat
	
	var mesh = QuadMesh.new()
	mesh.size = Vector2(0.1, 0.8)
	var s_mat = StandardMaterial3D.new()
	s_mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	s_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	s_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	s_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mesh.material = s_mat
	parts.draw_pass_1 = mesh
	
	parts.emitting = true
	parts.one_shot = true
	parts.explosiveness = 0.5
	parts.amount = 60
	parts.lifetime = 1.0
	root.add_child(parts)

	var tween = root.create_tween().set_parallel(true)
	tween.tween_property(cyl, "scale", Vector3(1.0, 1.0, 1.0), 0.3).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "position:y", 2.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(cyl, "rotation_degrees:y", 90.0, 0.8)
	tween.tween_property(ring, "rotation_degrees:y", -90.0, 0.8)
	
	tween.tween_property(c_mat, "albedo_color:a", 0.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_property(r_mat, "albedo_color:a", 0.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	
	tween.chain().tween_callback(root.queue_free)

func _play_y2k_glitch(pos: Vector3) -> void:
	var root = Node3D.new()
	get_tree().current_scene.add_child(root)
	root.global_position = pos + Vector3(0, 1.0, 0)
	
	# Glitchy cubes
	for i in range(5):
		var mesh = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(0.2, 0.2, 0.2) * randf_range(1.0, 3.0)
		mesh.mesh = box
		
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(randf(), randf(), randf(), 0.8)
		mat.emission_enabled = true
		mat.emission = mat.albedo_color
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh.material_override = mat
		
		mesh.position = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1))
		root.add_child(mesh)
		
		var t = root.create_tween()
		t.tween_property(mesh, "position", mesh.position + Vector3(randf_range(-2, 2), randf_range(-2, 2), randf_range(-2, 2)), 0.3)
		t.parallel().tween_property(mesh, "scale", Vector3.ZERO, 0.3)
		t.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.3)
		
	var parts = GPUParticles3D.new()
	var p_mat = ParticleProcessMaterial.new()
	p_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	p_mat.emission_box_extents = Vector3(1, 1, 1)
	p_mat.gravity = Vector3(0, 0, 0)
	p_mat.color = Color(0.2, 1.0, 0.2, 1.0)
	
	var gradient = GradientTexture1D.new()
	gradient.gradient = Gradient.new()
	gradient.gradient.colors = PackedColorArray([Color(1,1,1,1), Color(1,1,1,0)])
	p_mat.color_ramp = gradient
	parts.process_material = p_mat
	
	var p_mesh = QuadMesh.new()
	p_mesh.size = Vector2(0.1, 0.8)
	var s_mat = StandardMaterial3D.new()
	s_mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	s_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	s_mat.albedo_color = Color(0.0, 1.0, 0.2, 1.0)
	s_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	s_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	p_mesh.material = s_mat
	parts.draw_pass_1 = p_mesh
	
	parts.emitting = true
	parts.one_shot = true
	parts.explosiveness = 1.0
	parts.amount = 25
	parts.lifetime = 0.4
	root.add_child(parts)
	
	get_tree().create_timer(0.5).timeout.connect(root.queue_free)
