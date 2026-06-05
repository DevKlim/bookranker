extends Area3D

var speed: float = 15.0
var damage: float = 10.0
var is_plane: bool = false
var leave_trail: bool = false
var boss_ref: Node = null
var attack_res: Resource = null
var last_tile: Vector2i = Vector2i(-9999, -9999)

func _ready() -> void:
	body_entered.connect(_on_hit)
	area_entered.connect(_on_hit)
	if has_node("HealthComponent"):
		get_node("HealthComponent").died.connect(func(_n): queue_free())
		
	# Apply Y2K Dark Aura Shader to physical projectile mesh
	var mesh_node = get_node_or_null("MeshInstance3D")
	if mesh_node:
		var aura_mat = ShaderMaterial.new()
		var shader = load("res://shaders/dark_arc.gdshader")
		if shader: aura_mat.shader = shader
		mesh_node.material_overlay = aura_mat

	# Attach trailing Dark Sparks (No smoke, only high-intensity slash/spark traces)
	var p = GPUParticles3D.new()
	p.name = "DarkSparksVFX"
	
	var mat = ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	mat.emission_sphere_radius = 0.4
	mat.direction = Vector3(-1, 0, 0) # Emit backwards against travel
	mat.spread = 30.0
	mat.initial_velocity_min = 3.0
	mat.initial_velocity_max = 6.0
	mat.gravity = Vector3(0, -1.0, 0)
	
	var ramp = GradientTexture1D.new()
	var grad = Gradient.new()
	# Vibrant Y2K purple/pink trailing off to dark
	grad.colors = [Color(0.8, 0.1, 1.0, 1.0), Color(0.4, 0.0, 0.6, 0.8), Color(0.0, 0.0, 0.0, 0.0)]
	grad.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	ramp.gradient = grad
	mat.color_ramp = ramp
	
	# Shrink as they fade
	var curve = Curve.new()
	curve.add_point(Vector2(0, 1.0))
	curve.add_point(Vector2(1, 0.0))
	var c_tex = CurveTexture.new()
	c_tex.curve = curve
	mat.scale_curve = c_tex
	
	p.process_material = mat
	
	var pass1 = QuadMesh.new()
	var smat = StandardMaterial3D.new()
	smat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	smat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	smat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	# Uses the slash texture as a fast-moving spark trace
	var tex = load("res://assets/textures/particles/slash/slash_01_a.png")
	if tex: smat.albedo_texture = tex
	pass1.material = smat
	p.draw_pass_1 = pass1
	
	add_child(p)

func _physics_process(delta: float) -> void:
	var step = speed * delta
	global_position.x -= step
	
	if leave_trail and is_instance_valid(boss_ref):
		var lm = get_node_or_null("/root/LaneManager")
		if lm:
			var current_tile = lm.world_to_tile(global_position)
			if current_tile != last_tile:
				last_tile = current_tile
				if boss_ref.has_method("_spawn_red_tarstream"):
					boss_ref.call_deferred("_spawn_red_tarstream", current_tile, 10.0, false)

	if global_position.x < -10: queue_free()

func _on_hit(body: Node) -> void:
	if body.is_in_group("buildings") or body.is_in_group("core") or body.is_in_group("player") or body.is_in_group("allies"):
		if body.is_in_group("loot_buildings"): return
		if is_instance_valid(boss_ref) and attack_res and boss_ref.has_node("AttackerComponent"):
			boss_ref.get_node("AttackerComponent").processor.apply_hit(boss_ref, body, global_position, damage, attack_res, false)
		else:
			if body.has_method("take_damage"):
				var elem = null
				var em = get_node_or_null("/root/ElementManager")
				if em: elem = em.get_element("dark")
				body.take_damage(damage, elem, boss_ref)
		queue_free()
