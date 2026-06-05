class_name WindwallEntity
extends CharacterBody3D

var health_component: HealthComponent
var elemental_component: ElementalComponent
var lifetime: float = 30.0
var travel_dist: float = 5.0
var distance_moved: float = 0.0
var speed: float = 1.0
var direction: Vector3 = Vector3.FORWARD
var is_stopped: bool = false
var start_pos: Vector3

var visual_mesh: MeshInstance3D

func _ready():
	add_to_group("allies")
	collision_layer = 1
	collision_mask = 2 # Enemy layer
	
	health_component = HealthComponent.new()
	health_component.max_health = 50.0
	health_component.current_health = 50.0
	add_child(health_component)
	health_component.died.connect(_on_died)
	
	elemental_component = ElementalComponent.new()
	add_child(elemental_component)
	
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(0.95, 2.0, 0.5) # Covers the lane width cleanly
	col.shape = box
	col.position = Vector3(0, 1, 0)
	add_child(col)
	
	# Area to detect enemy collision to stop and apply aero
	var area = Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	var area_col = CollisionShape3D.new()
	area_col.shape = box
	area_col.position = Vector3(0, 1, 0)
	area.add_child(area_col)
	area.body_entered.connect(_on_enemy_hit)
	add_child(area)
	
	# Stylized Y2K Visuals
	visual_mesh = MeshInstance3D.new()
	var q = QuadMesh.new()
	q.size = Vector2(1.2, 2.0)
	visual_mesh.mesh = q
	visual_mesh.position = Vector3(0, 1, 0)
	
	var mat = ShaderMaterial.new()
	var shader = load("res://shaders/windwall.gdshader")
	if shader:
		mat.shader = shader
		var noise = FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
		var noise_tex = NoiseTexture2D.new()
		noise_tex.noise = noise
		noise_tex.seamless = true
		mat.set_shader_parameter("noise_tex", noise_tex)
	else:
		mat = StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.6, 1.0, 0.9, 0.4)
		mat.emission_enabled = true
		mat.emission = Color(0.2, 1.0, 0.8)
		
	visual_mesh.material_override = mat
	add_child(visual_mesh)
	
	# Smooth entrance animation isolated to the visual mesh to prevent matrix collapse
	visual_mesh.scale = Vector3(0.01, 0.01, 0.01)
	var tween = create_tween()
	tween.tween_property(visual_mesh, "scale", Vector3.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	start_pos = global_position

func initialize(dir: Vector3):
	direction = dir.normalized()
	look_at(global_position + direction, Vector3.UP)
	start_pos = global_position # Re-set after translation

func _physics_process(delta):
	lifetime -= delta
	if lifetime <= 0:
		_on_died(self)
		return
		
	if not is_stopped:
		velocity = direction * speed
		move_and_slide()
		distance_moved = global_position.distance_to(start_pos)
		
		# Stop after moving 5 tiles
		if distance_moved >= travel_dist * LaneManager.GRID_SCALE:
			is_stopped = true
			velocity = Vector3.ZERO
			
func _on_enemy_hit(body: Node3D):
	if body.is_in_group("enemies"):
		is_stopped = true
		velocity = Vector3.ZERO
		var aero = ElementManager.get_element("aero")
		if aero:
			ElementManager.apply_element(body, aero, self, 0.0, 1)

func _on_died(_node):
	set_physics_process(false)
	collision_layer = 0
	
	if get_tree().root.has_node("GameManager"):
		var gm = get_tree().root.get_node("GameManager")
		if gm.get("vfx_manager"):
			gm.vfx_manager.play_vfx("tailwind", global_position + Vector3(0, 1, 0))
	
	var tween = create_tween()
	tween.tween_property(visual_mesh, "scale", Vector3(0.01, 0.01, 0.01), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)

func take_damage(amount: float, element: Resource = null, source: Node = null):
	if source and source.is_in_group("enemies"):
		var aero = ElementManager.get_element("aero")
		if aero:
			ElementManager.apply_element(source, aero, self, 0.0, 1)
			
	if element:
		ElementManager.apply_element(self, element, source, amount)
		
	health_component.take_damage(amount, element, source)
