extends BaseBuilding

var bubble_visual: MeshInstance3D
var bubble_ready: bool = true
var regen_timer: float = 0.0
var base_scale: float = 1.0
var bubble_area: Area3D

func _ready():
	# Make enemies walk through it in grid pathfinding and physics
	add_to_group("stream")
	collision_layer = 8 
	collision_mask = 0
	
	super._ready()
	base_scale = get_stat("space", 10.0) / 10.0
	_setup_bubble()

func _setup_bubble():
	var base = get_node_or_null("blockbench_export")
	if not base:
		base = MeshInstance3D.new()
		var torus = TorusMesh.new()
		torus.inner_radius = 0.3
		torus.outer_radius = 0.4
		base.mesh = torus
		base.position = Vector3(0, 0.1, 0)
		add_child(base)
	
	bubble_visual = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 0.4
	sphere.height = 0.8
	bubble_visual.mesh = sphere
	bubble_visual.position = Vector3(0, 0.8, 0)
	bubble_visual.scale = Vector3(base_scale, base_scale, base_scale)
	
	var mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/lily_bubble.gdshader")
	if mat.shader:
		mat.set_shader_parameter("base_color", Color(0.8, 0.9, 1.0, 0.4))
		mat.set_shader_parameter("iridescence", Color(1.0, 0.5, 0.8, 1.0))
		mat.set_shader_parameter("speed", 2.0)
	else:
		var sm = StandardMaterial3D.new()
		sm.albedo_color = Color(0.8, 0.9, 1.0, 0.4)
		sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat = sm
		
	bubble_visual.material_override = mat
	add_child(bubble_visual)
	
	var t = create_tween().set_loops()
	t.tween_property(bubble_visual, "position:y", 1.0, 1.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	t.tween_property(bubble_visual, "position:y", 0.8, 1.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)

	# Bubble Area for triggering pops
	bubble_area = Area3D.new()
	bubble_area.collision_layer = 0
	bubble_area.collision_mask = 2 # Enemy layer
	var area_col = CollisionShape3D.new()
	var sphere_shape = SphereShape3D.new()
	sphere_shape.radius = 0.6 * base_scale
	area_col.shape = sphere_shape
	area_col.position = Vector3(0, 0.8, 0)
	bubble_area.add_child(area_col)
	add_child(bubble_area)

func take_damage(amount: float, element: Resource = null, source: Node = null) -> void:
	if element and element.element_name.to_lower() == "aero" and bubble_ready:
		_shoot_bubble()
	super.take_damage(amount, element, source)

func _physics_process(delta):
	super._physics_process(delta)
	
	if not bubble_ready and is_active:
		regen_timer -= delta
		if regen_timer <= 0:
			bubble_ready = true
			bubble_visual.visible = true
			bubble_visual.scale = Vector3.ZERO
			create_tween().tween_property(bubble_visual, "scale", Vector3(base_scale, base_scale, base_scale), 0.5).set_trans(Tween.TRANS_BACK)
			
	if bubble_ready and is_active:
		if is_instance_valid(bubble_area):
			var overlapping = bubble_area.get_overlapping_bodies()
			var enemy_found = false
			for body in overlapping:
				if body.is_in_group("enemies") and not body.get("is_dead"):
					enemy_found = true
					break
			
			if enemy_found:
				_pop_bubble()

func _pop_bubble() -> void:
	bubble_ready = false
	regen_timer = 5.0
	bubble_visual.visible = false
	
	if get_tree().root.has_node("GameManager"):
		var gm = get_tree().root.get_node("GameManager")
		if gm.get("vfx_manager"):
			gm.vfx_manager.play_vfx("bubble_pop", global_position + Vector3(0, 0.8, 0))
			
	var dmg = 5.0 * base_scale
	var aqua = ElementManager.get_element("aqua")
	
	for body in bubble_area.get_overlapping_bodies():
		if body.is_in_group("enemies") and not body.get("is_dead"):
			if body.has_method("take_damage"):
				body.take_damage(dmg, aqua, self)
			ElementManager.apply_element(body, aqua, self, dmg, 1, true)

func _shoot_bubble():
	bubble_ready = false
	regen_timer = 5.0
	bubble_visual.visible = false
	
	var fwd = Vector3.FORWARD
	match output_direction:
		Direction.DOWN: fwd = Vector3(0,0,1)
		Direction.LEFT: fwd = Vector3(-1,0,0)
		Direction.UP: fwd = Vector3(0,0,-1)
		Direction.RIGHT: fwd = Vector3(1,0,0)
		
	var spawn_pos = global_position + Vector3(0, 0.8, 0) + fwd * 0.5
	
	var p_scene = load("res://scenes/entities/projectile.tscn")
	if p_scene:
		var p = p_scene.instantiate()
		get_tree().root.add_child(p)
		var lane_id = LaneManager.world_to_tile(spawn_pos).y
		var aqua = ElementManager.get_element("aqua")
		var dmg = 5.0 * base_scale
		
		var params = {
			"source": self,
			"element_units": 1,
			"scale": base_scale,
			"aoe_explosion": true,
			"tick_damage": false
		}
		
		p.tree_exiting.connect(func():
			if get_tree().root.has_node("GameManager"):
				var gm = get_tree().root.get_node("GameManager")
				if gm.get("vfx_manager"):
					gm.vfx_manager.play_vfx("bubble_pop", p.global_position)
		)
		
		p.initialize(spawn_pos, fwd, 50.0, dmg, lane_id, aqua, null, Color(0.8, 0.9, 1.0, 0.8), false, params)
		
		var mesh = MeshInstance3D.new()
		var sphere = SphereMesh.new()
		sphere.radius = 0.4
		sphere.height = 0.8
		mesh.mesh = sphere
		mesh.material_override = bubble_visual.material_override
		mesh.scale = Vector3(base_scale, base_scale, base_scale)
		p.add_child(mesh)
