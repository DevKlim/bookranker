class_name BoxFanBuilding
extends BaseBuilding

var attacker: AttackerComponent
var wind_mesh: MeshInstance3D
var _active_dir: Vector3 = Vector3.ZERO

func _ready() -> void:
	display_name = "Box Fan"
	super._ready()
	if Engine.is_editor_hint(): return
	
	attacker = get_node_or_null("AttackerComponent")
	if not attacker:
		attacker = AttackerComponent.new()
		attacker.name = "AttackerComponent"
		add_child(attacker)
		
	var attack_res = load("res://resources/attacks/fan_blow.tres") as AttackResource
	if attack_res:
		# Allows the AoE to hit the Desk and successfully imbue it with Aero
		attack_res.set_meta("targets_buildings", true)
		attack_res.set_meta("targets_allies", true)
	
	attacker.basic_attack = attack_res
	attacker.show_debug_hitboxes = true
	
	_setup_wind_visual()

func _setup_wind_visual() -> void:
	wind_mesh = MeshInstance3D.new()
	var box = BoxMesh.new()
	box.size = Vector3(1.0, 1.0, 3.0)
	wind_mesh.mesh = box
	
	var mat = ShaderMaterial.new()
	var shader = Shader.new()
	shader.code = """
	shader_type spatial;
	render_mode blend_add, unshaded, cull_disabled;
	uniform vec4 color : source_color = vec4(0.5, 0.9, 1.0, 0.3);
	void fragment() {
		vec2 uv = UV;
		float line = smoothstep(0.1, 0.0, abs(sin(uv.x * 20.0 - TIME * 15.0)));
		ALBEDO = color.rgb * (1.0 + line);
		ALPHA = color.a * (0.5 + line * 0.5);
	}
	"""
	mat.shader = shader
	wind_mesh.material_override = mat
	
	# Since BaseBuilding sets physical rotation according to output direction, 
	# attaching it as a standard child naturally inherits that rotation!
	wind_mesh.position = Vector3(0, 0.5, -1.5) # Local -Z is forward
	wind_mesh.visible = false
	add_child(wind_mesh)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if Engine.is_editor_hint(): return
	
	if not is_active:
		if attacker: attacker.stop_attacking()
		if wind_mesh: wind_mesh.visible = false
		_active_dir = Vector3.ZERO
		return
	
	# Extract literal global forward vector from the building's current rotation matrix
	var dir = -global_transform.basis.z.normalized()
	
	if wind_mesh:
		wind_mesh.visible = true
			
	if attacker:
		if _active_dir != dir:
			attacker.stop_attacking()
			_active_dir = dir
			
		# Calculate the true global epicenter of the 3-block wind tunnel using local offset
		var target_pos = global_transform * Vector3(0, 0.5, -1.5)
			
		if attacker.attack_timer.is_stopped() and not attacker.is_casting:
			attacker.current_target = null
			attacker.current_target_dir = dir
			attacker.current_target_pos = target_pos
			attacker.base_active_attack = attacker.basic_attack
			attacker.current_attack = attacker.basic_attack
			
			attacker._trigger_attack_sequence()
