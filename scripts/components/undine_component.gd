class_name UndineComponent
extends Node3D

@export var max_reactions: int = 1

var target: Node
var source: Node
var conversion_rate: float = 0.3
var _timer: float = 20.0
var dmg_delay = 0.5
var current_reactions: int = 0

func setup(p_target: Node, p_source: Node) -> void:
	target = p_target
	source = p_source
	name = "UndineComponent"
	
	if is_instance_valid(source) and source.has_method("get_stat"):
		var lux = source.get_stat("lux_stat", 0.0)
		conversion_rate = (30.0 + lux * 0.5) / 100.0
		
	var ec = ElementalComponent.new()
	ec.name = "ElementalComponent"
	add_child(ec)
	
	var em = get_tree().root.get_node_or_null("ElementManager")
	
	var host_ec = target.get_node_or_null("ElementalComponent")
	if host_ec and em:
		for element_id in host_ec.get_active_element_names():
			if element_id == "undine": continue
			var res = em.get_element(element_id)
			var data = host_ec.get_active_data(element_id)
			if res and data:
				ec.add_or_refresh_status(res, data.units)
				
	if em and not ec.has_element("ghost"):
		var ghost = em.get_element("ghost")
		if ghost:
			ec.add_or_refresh_status(ghost, 1)
			
	var mesh_inst = MeshInstance3D.new()
	mesh_inst.set_meta("is_jellyfish", true)
	var sphere = SphereMesh.new()
	sphere.radius = 1.0 # Slightly larger to envelop the host
	sphere.height = 2.0
	mesh_inst.mesh = sphere
	
	var mat = ShaderMaterial.new()
	var j_shader = load("res://shaders/jellyfish_shield.gdshader")
	if j_shader:
		mat.shader = j_shader
		mat.set_shader_parameter("base_color", Color(0.0, 0.4, 0.8, 0.3))
		mat.set_shader_parameter("rim_color", Color(0.0, 0.8, 1.0, 0.8))
	else:
		mat.shader = load("res://shaders/retro_glow.gdshader")
		if mat.shader:
			mat.set_shader_parameter("glow_color", Color(0.0, 0.8, 1.0, 0.5))
			
	mesh_inst.material_override = mat
	mesh_inst.position.y = 1.0
	add_child(mesh_inst)

func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0 or not is_instance_valid(target) or target.get("is_dead"):
		pop()

func reset_duration() -> void:
	_timer = 20.0

func take_damage(amount: float, element: Resource = null, p_source: Node = null) -> void:
	var dmg_to_host = amount * conversion_rate
	if is_instance_valid(target):
		var safe_source = p_source if is_instance_valid(p_source) else null

		await get_tree().create_timer(dmg_delay).timeout
		if target.has_method("take_damage_no_conduct"):
			target.take_damage_no_conduct(dmg_to_host, safe_source)
		elif target.has_node("HealthComponent"):
			target.get_node("HealthComponent").take_damage_no_conduct(dmg_to_host, safe_source)

func take_damage_no_conduct(amount: float, p_source: Node = null) -> void:
	take_damage(amount, null, p_source)

func get_stat(stat_name: String, default_value: float = 0.0) -> float:
	if is_instance_valid(target) and target.has_method("get_stat"):
		return target.get_stat(stat_name, default_value)
	return default_value

func on_reaction() -> void:
	current_reactions += 1
	if current_reactions >= max_reactions:
		pop()

func pop() -> void:
	if has_meta("is_popping"): return
	set_meta("is_popping", true)
	set_process(false)
	
	var tween = create_tween().set_parallel(true)
	for child in get_children():
		if child is MeshInstance3D:
			# Changed TRANS_BACK to TRANS_QUAD to prevent sudden bulging
			tween.tween_property(child, "scale", Vector3.ZERO, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
			
	tween.chain().tween_callback(queue_free)
