class_name ElementalComponent
extends Node

signal status_applied(element_id, units)
signal status_removed(element_id)
signal status_changed(element_id, units)

# Structure: { "element_id": { "resource": ElementResource, "visual": Sprite3D, "units": int, "duration": float, "target_x": float, "current_x": float, "is_permanent": bool } }
var active_statuses: Dictionary = {}
var cooldowns: Dictionary = {}

@export var elemental_cd: float = 0.0

@onready var visual_container: Node3D = Node3D.new()
var _health_component: HealthComponent
var _bg_mesh: MeshInstance3D
var _bg_material: ShaderMaterial
var _current_bg_width: float = 0.0
var _target_bg_width: float = 0.0

const SPACING: float = 0.4
const FLASH_THRESHOLD: float = 1.5

func _ready() -> void:
	_health_component = get_parent().get_node_or_null("HealthComponent")
	
	visual_container.name = "StatusVisuals"
	visual_container.position = Vector3(0, 3.5, 0) # High up to clear massive structures (Windwalls/Drills)
	get_parent().call_deferred("add_child", visual_container)

	_setup_pill_background()

	if get_parent().has_signal("tile_changed"):
		get_parent().tile_changed.connect(_on_parent_tile_changed)

func _setup_pill_background() -> void:
	_bg_mesh = MeshInstance3D.new()
	var quad = QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	_bg_mesh.mesh = quad
	
	_bg_material = ShaderMaterial.new()
	
	var shader = Shader.new()
	shader.code = """
	shader_type spatial;
	render_mode unshaded, depth_test_disabled, blend_mix;
	
	uniform vec2 size = vec2(1.0, 0.45);
	uniform float fade = 1.0;

	void vertex() {
		VERTEX.xy *= size;
	}

	void fragment() {
		vec2 p = UV * 2.0 - 1.0; 
		p.x *= size.x / size.y; 
		
		float line_half_len = max(0.0, (size.x / size.y) - 1.0);
		p.x = max(0.0, abs(p.x) - line_half_len);
		
		float d = length(p);
		float alpha = smoothstep(1.0, 0.95, d);
		if(alpha < 0.01 || fade < 0.01) discard;
		
		float highlight = smoothstep(0.5, 0.0, d) * clamp(1.0 - (UV.y * 2.0), 0.0, 1.0);
		float rim = smoothstep(0.8, 1.0, d) * 0.5;
		
		ALBEDO = mix(vec3(0.02, 0.05, 0.15), vec3(0.6, 0.8, 1.0), highlight + rim);
		ALPHA = alpha * (0.5 + highlight) * fade;
	}
	"""
	_bg_material.shader = shader
	_bg_material.set_shader_parameter("size", Vector2(0.0, 0.45))
	_bg_material.set_shader_parameter("fade", 0.0)
	_bg_material.render_priority = 49 
	
	_bg_mesh.material_override = _bg_material
	_bg_mesh.position.z = -0.02
	_bg_mesh.visible = false
	visual_container.add_child(_bg_mesh)

func is_on_cooldown(element_id: String) -> bool:
	if not cooldowns.has(element_id): return false
	return Time.get_ticks_msec() < cooldowns[element_id]

func set_cooldown(element_id: String, duration_sec: float) -> void:
	var fw = 0.0
	if _health_component:
		fw = _health_component.firewall
	
	var final_duration = (duration_sec + elemental_cd) * (1.0 + fw)
	if final_duration <= 0: return
	cooldowns[element_id] = Time.get_ticks_msec() + int(final_duration * 1000.0)

func play_reaction_animation(id_a: String, id_b: String, result_id: String) -> void:
	var res_a = null
	var res_b = null
	var res_result = null
	
	if get_tree().root.has_node("ElementManager"):
		var em = get_tree().root.get_node("ElementManager")
		res_a = em.get_element(id_a)
		res_b = em.get_element(id_b)
		res_result = em.get_element(result_id)
		
	if not res_a or not res_b or not res_result: return
	
	var sprite_a = Sprite3D.new()
	sprite_a.texture = res_a.icon
	sprite_a.pixel_size = 0.02
	sprite_a.billboard = 0 
	sprite_a.render_priority = 60
	sprite_a.no_depth_test = true
	visual_container.add_child(sprite_a)
	
	var sprite_b = sprite_a.duplicate()
	sprite_b.texture = res_b.icon
	visual_container.add_child(sprite_b)
	
	var end_pos_x = (_current_bg_width / 2.0) + 0.1
	sprite_a.position = Vector3(end_pos_x - 0.2, 0.2, 0.05)
	sprite_b.position = Vector3(end_pos_x + 0.2, 0.2, 0.05)
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(sprite_a, "position", Vector3(end_pos_x, 0.35, 0.05), 0.3).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(sprite_b, "position", Vector3(end_pos_x, 0.35, 0.05), 0.3).set_ease(Tween.EASE_IN_OUT)
	
	tween.chain().set_parallel(true)
	var sprite_res = sprite_a.duplicate()
	sprite_res.texture = res_result.icon
	sprite_res.scale = Vector3.ZERO
	sprite_res.position = Vector3(end_pos_x, 0.35, 0.06)
	visual_container.add_child(sprite_res)
	
	tween.tween_property(sprite_a, "scale", Vector3.ZERO, 0.15)
	tween.tween_property(sprite_b, "scale", Vector3.ZERO, 0.15)
	tween.tween_property(sprite_res, "scale", Vector3(1.4, 1.4, 1.4), 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	
	tween.chain().set_parallel(true)
	tween.tween_property(sprite_res, "position:y", 0.7, 0.5)
	tween.tween_property(sprite_res, "modulate:a", 0.0, 0.5)
	
	tween.chain().tween_callback(sprite_a.queue_free)
	tween.chain().tween_callback(sprite_b.queue_free)
	tween.chain().tween_callback(sprite_res.queue_free)

func add_or_refresh_status(element: ElementResource, units: int, is_permanent: bool = false) -> void:
	var id = element.element_name.to_lower()
	var purity = 0.0
	if _health_component: purity = _health_component.purity
	
	var effective_duration = element.duration * (1.0 - purity)
	if effective_duration < 0.1: effective_duration = 0.1
	if is_permanent: effective_duration = INF
	
	if active_statuses.has(id):
		var data = active_statuses[id]
		data.units = max(data.units, units)
		data.duration = effective_duration
		data.is_permanent = is_permanent
		_update_visual_label(data)
		emit_signal("status_changed", id, data.units)
	else:
		var sprite = Sprite3D.new()
		sprite.texture = element.icon
		sprite.billboard = 0 
		sprite.pixel_size = 0.02
		sprite.no_depth_test = true
		sprite.render_priority = 50
		sprite.scale = Vector3.ZERO 
		visual_container.add_child(sprite)
		
		var lbl = Label3D.new()
		lbl.name = "UnitLabel"
		lbl.pixel_size = 0.01
		lbl.position = Vector3(0.15, -0.15, 0.01)
		lbl.render_priority = 51
		lbl.no_depth_test = true
		lbl.billboard = 0 
		lbl.outline_modulate = Color.BLACK
		lbl.outline_size = 4
		sprite.add_child(lbl)
		
		active_statuses[id] = {
			"resource": element,
			"visual": sprite,
			"units": units,
			"duration": effective_duration,
			"target_x": 0.0,
			"current_x": 0.0,
			"is_permanent": is_permanent
		}
		
		ElementManager.track_element_addition(id)
		
		if id in ElementManager.SPATIAL_ELEMENTS:
			var tile = LaneManager.world_to_tile(get_parent().global_position)
			ElementManager.register_spatial_status(id, get_parent(), tile)
		
		_update_visual_label(active_statuses[id])
		_calculate_targets()
		
		var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tween.tween_property(sprite, "scale", Vector3(1.0, 1.0, 1.0), 0.3)
		
		emit_signal("status_applied", id, units)

func consume_units(id: String, amount: int) -> int:
	if not active_statuses.has(id): return 0
	
	var data = active_statuses[id]
	var removed = min(data.units, amount)
	data.units -= removed
	
	if data.units <= 0:
		remove_status(id)
	else:
		_update_visual_label(data)
		emit_signal("status_changed", id, data.units)
		
	return removed

func remove_status(id: String) -> void:
	if active_statuses.has(id):
		ElementManager.track_element_removal(id)
		
		if id in ElementManager.SPATIAL_ELEMENTS:
			var tile = LaneManager.world_to_tile(get_parent().global_position)
			ElementManager.unregister_spatial_status(id, get_parent(), tile)
			
		if id == "boil":
			var steam = get_parent().get_node_or_null("BoilSteam")
			if steam and steam is GPUParticles3D:
				steam.emitting = false
				get_tree().create_timer(steam.lifetime + 0.1).timeout.connect(steam.queue_free)

		var data = active_statuses[id]
		if is_instance_valid(data.visual): 
			var tween = create_tween()
			tween.tween_property(data.visual, "scale", Vector3.ZERO, 0.2)
			tween.tween_callback(data.visual.queue_free)
			
		active_statuses.erase(id)
		_calculate_targets()
		emit_signal("status_removed", id)

func remove_all_statuses() -> void:
	var keys = active_statuses.keys()
	for id in keys:
		remove_status(id)
	
	active_statuses.clear()
	_calculate_targets()

func _on_parent_tile_changed(old_tile: Vector2i, new_tile: Vector2i) -> void:
	for id in active_statuses:
		if id in ElementManager.SPATIAL_ELEMENTS:
			ElementManager.update_spatial_status_position(id, get_parent(), old_tile, new_tile)

func _update_visual_label(data: Dictionary) -> void:
	var lbl = data.visual.get_node_or_null("UnitLabel")
	if lbl:
		lbl.text = str(data.units) if data.units > 1 else ""

func _calculate_targets() -> void:
	var keys = active_statuses.keys()
	keys.sort_custom(func(a, b): return active_statuses[a].duration < active_statuses[b].duration)
	
	var count = keys.size()
	if count == 0:
		_target_bg_width = 0.0
		return
		
	var start_x = -((count - 1) * SPACING) / 2.0
	for i in range(count):
		active_statuses[keys[i]].target_x = start_x + (i * SPACING)
		
	_target_bg_width = max(0.0, ((count - 1) * SPACING) + 0.6)

func get_stat_modifier(stat_key: String) -> float:
	var total = 0.0
	for id in active_statuses:
		var res = active_statuses[id].resource
		if res.stat_modifiers.has(stat_key):
			total += res.stat_modifiers[stat_key]
	return total

func has_element(id: String) -> bool:
	return active_statuses.has(id.to_lower())

func get_active_element_names() -> Array:
	return active_statuses.keys()

func get_active_data(id: String) -> Dictionary:
	return active_statuses.get(id, {})

func _process(delta: float) -> void:
	# Safely synchronize visual container to explicitly face the active camera viewport basis
	# Utilizing an inversion safeguard to prevent condition 'det == 0' crashes on scale-squashed parent nodes
	var cam = get_viewport().get_camera_3d()
	if cam and is_instance_valid(cam):
		var b = cam.global_basis
		var parent_basis = get_parent().global_transform.basis
		if abs(parent_basis.determinant()) > 0.001 and abs(b.determinant()) > 0.001:
			visual_container.global_transform.basis = b

	if _current_bg_width != _target_bg_width:
		_current_bg_width = lerp(_current_bg_width, _target_bg_width, delta * 12.0)
		_bg_material.set_shader_parameter("size", Vector2(_current_bg_width, 0.45))
		
	var fade_amt = clamp((_current_bg_width - 0.1) / 0.15, 0.0, 1.0)
	_bg_material.set_shader_parameter("fade", fade_amt)
	_bg_mesh.visible = _current_bg_width > 0.1

	if active_statuses.is_empty(): return
	var keys = active_statuses.keys()
	
	for id in keys:
		if not active_statuses.has(id): continue
		var data = active_statuses[id]
		
		if not data.is_permanent:
			data.duration -= delta
			
			if data.duration <= 0:
				remove_status(id)
				continue
			
		data.current_x = lerp(data.current_x, data.target_x, delta * 10.0)
		if is_instance_valid(data.visual):
			data.visual.position.x = data.current_x
			
			if data.duration < FLASH_THRESHOLD and not data.is_permanent:
				var flash = (sin(Time.get_ticks_msec() * 0.02) * 0.5) + 0.5
				data.visual.modulate = Color.WHITE.lerp(Color(1.5, 0.5, 0.5), flash)
				if data.duration < 0.5:
					data.visual.modulate.a = data.duration / 0.5
			else:
				data.visual.modulate = Color.WHITE
		
		if _health_component:
			var res = data.resource
			var dmg = 0.0
			if res.stat_modifiers.has("damage_per_second"):
				dmg = res.stat_modifiers["damage_per_second"]
			
			if res.damage_equation != "":
				if ClassDB.class_exists("FormulaHelper") or ResourceLoader.exists("res://scripts/utils/formula_helper.gd"):
					var fh = load("res://scripts/utils/formula_helper.gd")
					if fh:
						var vars = {"base_damage": dmg, "units": data.units}
						dmg = fh.evaluate(res, res.damage_equation, vars, dmg)
					
			if dmg > 0:
				_health_component.take_damage(dmg * delta, res)
				
	if Engine.get_frames_drawn() % 15 == 0:
		_calculate_targets()
