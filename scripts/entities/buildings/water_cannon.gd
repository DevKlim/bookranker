extends BaseBuilding

var chalk_consume_timer: float = 0.0
var attack_timer: float = 0.0
var cannon_barrel: Node3D
var beam_mesh: MeshInstance3D
var impact_particles: GPUParticles3D

var is_firing: bool = false
var target_enemy: Node3D = null

func _ready():
	super._ready()
	cannon_barrel = get_node_or_null("blockbench_export")
	if not cannon_barrel:
		_setup_visuals_code()
	else:
		_setup_emitter()
	
func _setup_visuals_code():
	var base = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(0.8, 0.4, 0.8)
	base.mesh = box
	base.position = Vector3(0, 0.2, 0)
	add_child(base)
	
	cannon_barrel = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.2
	cyl.bottom_radius = 0.3
	cyl.height = 1.0
	cannon_barrel.mesh = cyl
	cannon_barrel.position = Vector3(0, 0.6, 0.3)
	cannon_barrel.rotation.x = deg_to_rad(90)
	add_child(cannon_barrel)
	 
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.5, 0.9)
	cannon_barrel.material_override = mat
	
	_setup_emitter()

func _setup_emitter():
	# Continuous energy-water beam stretching to the target
	beam_mesh = MeshInstance3D.new()
	var cyl = CylinderMesh.new()
	cyl.top_radius = 0.2
	cyl.bottom_radius = 0.25
	cyl.height = 1.0
	cyl.radial_segments = 8
	cyl.cap_top = false
	cyl.cap_bottom = false
	beam_mesh.mesh = cyl
	
	var bmat = ShaderMaterial.new()
	var shader = load("res://shaders/water_beam.gdshader")
	if shader:
		bmat.shader = shader
		var ntex = load("res://assets/textures/particles/smokes/smoke_04_a.png")
		bmat.set_shader_parameter("noise_tex", ntex)
	else:
		bmat = StandardMaterial3D.new()
		bmat.albedo_color = Color(0.2, 0.8, 1.0, 0.8)
		bmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mesh.material_override = bmat
	add_child(beam_mesh)
	beam_mesh.visible = false

	# Stacked 2D Impact rings splash effect
	impact_particles = GPUParticles3D.new()
	var imat_p = ParticleProcessMaterial.new()
	imat_p.gravity = Vector3.ZERO
	var curve = CurveTexture.new()
	var c = Curve.new()
	c.add_point(Vector2(0, 0.2))
	c.add_point(Vector2(0.5, 1.5))
	c.add_point(Vector2(1.0, 2.0))
	curve.curve = c
	imat_p.scale_curve = curve
	
	var col_ramp = GradientTexture1D.new()
	var grad = Gradient.new()
	grad.add_point(0.0, Color(0.2, 0.8, 1.0, 0.8))
	grad.add_point(0.7, Color(0.2, 0.8, 1.0, 0.8))
	grad.add_point(1.0, Color(0.2, 0.8, 1.0, 0.0))
	col_ramp.gradient = grad
	imat_p.color_ramp = col_ramp
	
	impact_particles.process_material = imat_p
	var iq = QuadMesh.new()
	iq.size = Vector2(1.0, 1.0)
	var imatm = StandardMaterial3D.new()
	imatm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	imatm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	imatm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	imatm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	imatm.vertex_color_use_as_albedo = true
	imatm.albedo_texture = load("res://assets/textures/particles/circle/circle_03_a.png")
	iq.material = imatm
	impact_particles.draw_pass_1 = iq
	impact_particles.emitting = false
	impact_particles.amount = 8
	impact_particles.lifetime = 0.3
	add_child(impact_particles)

func _physics_process(delta):
	super._physics_process(delta)
	if not is_active:
		_stop_firing()
		return
	
	var has_chalk = false
	var target_item = null
	if inventory_component and inventory_component.has_item():
		var item = inventory_component.get_first_item()
		if item and item.resource_path.get_file().begins_with("aquachalk"):
			has_chalk = true
			target_item = item
			
	if has_chalk:
		chalk_consume_timer += delta
		attack_timer += delta
		
		if chalk_consume_timer >= 0.25: # 4 per sec consumption
			chalk_consume_timer = 0.0
			inventory_component.remove_item(target_item, 1)
			
		if attack_timer >= 0.25: # 4 per sec tick rate
			attack_timer = 0.0
			_fire_torrent_tick()
			
			# Light recoil animation
			if cannon_barrel:
				var tween = create_tween()
				var orig_z = cannon_barrel.position.z
				tween.tween_property(cannon_barrel, "position:z", orig_z - 0.2, 0.05)
				tween.tween_property(cannon_barrel, "position:z", orig_z, 0.2)
	else:
		_stop_firing()

func _stop_firing():
	is_firing = false
	if beam_mesh: beam_mesh.visible = false
	if impact_particles: impact_particles.emitting = false

func _fire_torrent_tick():
	is_firing = true
		
	var fwd = Vector3.FORWARD
	match output_direction:
		Direction.DOWN: fwd = Vector3(0,0,1)
		Direction.LEFT: fwd = Vector3(-1,0,0)
		Direction.UP: fwd = Vector3(0,0,-1)
		Direction.RIGHT: fwd = Vector3(1,0,0)
		
	var spawn_pos = global_position + Vector3(0, 0.6, 0) + fwd * 0.4
	var max_dist = 5.0 * LaneManager.GRID_SCALE
	var hit_pos = spawn_pos + fwd * max_dist
	target_enemy = null
	
	# Raycast logically via lane manager up to 5 tiles ahead
	var my_tile = LaneManager.world_to_tile(global_position)
	
	for i in range(1, 6):
		var check_tile = my_tile + Vector2i(int(fwd.x * i), int(fwd.z * i))
		var enemies = LaneManager.get_enemies_at(check_tile)
		var found_enemy = null
		for e in enemies:
			if is_instance_valid(e) and not e.get("is_dead"):
				found_enemy = e
				break
		if found_enemy:
			target_enemy = found_enemy
			hit_pos = found_enemy.global_position + Vector3(0, 0.5, 0)
			break
			
	if target_enemy:
		var dmg = 3.0 # Damage per tick
		var aqua = ElementManager.get_element("aqua")
		if target_enemy.has_method("take_damage"):
			target_enemy.take_damage(dmg, aqua, self)
		ElementManager.apply_element(target_enemy, aqua, self, dmg, 1, true)
		
	if beam_mesh:
		beam_mesh.visible = true
		var dist = spawn_pos.distance_to(hit_pos)
		
		# Place mesh strictly exactly between barrel tip and hit target
		var center_pos = spawn_pos + fwd * (dist / 2.0)
		beam_mesh.global_position = center_pos
		
		# Robustly generate a basis to perfectly map the mesh length (Y) across the distance
		var up_dir = fwd
		var right_dir = Vector3.UP.cross(up_dir).normalized()
		if right_dir.length_squared() < 0.01:
			right_dir = Vector3.RIGHT
		var forward_dir = right_dir.cross(up_dir).normalized()
		
		var new_basis = Basis(right_dir, up_dir, forward_dir)
		new_basis.x *= 1.0
		new_basis.y *= dist
		new_basis.z *= 1.0
		beam_mesh.global_basis = new_basis
		
	if impact_particles:
		impact_particles.emitting = true
		impact_particles.global_position = hit_pos
