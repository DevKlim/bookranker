class_name AbyssShellComponent
extends Node3D

var target: Node
var source: Node
var initial_units: int
var duration: float
var total_damage: float = 0.0
var total_units: int = 0
var reaction_count: int = 0

var elemental_component: ElementalComponent

var _stored_elements: Array[String] = []
var _timer: float = 0.0

var _visual_container: Node3D
var _void_material: ShaderMaterial
var _aura_material: ShaderMaterial
var _aura_mesh_inst: MeshInstance3D
var _affected_meshes: Array[GeometryInstance3D] = []
var _original_materials: Dictionary = {}

func setup(p_target: Node, p_source: Node, p_units: int) -> void:
	target = p_target
	source = p_source
	initial_units = p_units
	
	duration = clamp(4.0 + (p_units * 2.0), 4.0, 20.0)
	_timer = duration
	
	var ec = target.get_node_or_null("ElementalComponent")
	if ec: ec.process_mode = Node.PROCESS_MODE_DISABLED
	
	elemental_component = ElementalComponent.new()
	elemental_component.name = "ElementalComponent"
	add_child(elemental_component)
	
	var penalty_factor = max(0.1, 1.0 - (0.3 + 0.5 * p_units))
	
	if "speed" in target:
		target.set_meta("pre_abyss_speed", target.get("speed"))
		target.set("speed", target.get("speed") * penalty_factor)
		
	var move_comp = target.get_node_or_null("MoveComponent")
	if move_comp:
		target.set_meta("pre_abyss_move_speed", move_comp.move_speed)
		move_comp.move_speed *= penalty_factor
		
	_create_visual()
	
	var em = get_tree().root.get_node_or_null("ElementManager")
	if em:
		var abyss_res = em.get_element("abyss")
		if abyss_res:
			elemental_component.add_or_refresh_status(abyss_res, 1)

func _create_visual() -> void:
	var size_mult = 1.0
	if target.has_method("get_stat"): size_mult = target.get_stat("scale", 1.0)
	
	# 1. Locate CollisionShape3D to center visuals
	var col_offset = Vector3(0, 1.0 * size_mult, 0)
	var col_height = 1.0
	for child in target.get_children():
		if child is CollisionShape3D:
			col_offset = child.position
			if child.shape:
				if child.shape is BoxShape3D: col_height = child.shape.size.y
				elif child.shape is CapsuleShape3D or child.shape is CylinderShape3D: col_height = child.shape.height
				elif child.shape is SphereShape3D: col_height = child.shape.radius * 2.0
			break

	# 2. Void Material (Overrides Enemy visuals completely)
	_void_material = ShaderMaterial.new()
	var void_shader = load("res://shaders/abyss_void.gdshader")
	if void_shader: 
		_void_material.shader = void_shader
		var noise = FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
		noise.frequency = 0.05
		var ntex = NoiseTexture2D.new()
		ntex.noise = noise
		ntex.seamless = true
		_void_material.set_shader_parameter("noise_tex", ntex)
		_void_material.render_priority = 10 # Renders on top of aura
		
	_apply_overlay_recursive(target)

	# 3. Screentone Aura Background
	_aura_material = ShaderMaterial.new()
	var aura_shader = load("res://shaders/abyss_aura.gdshader")
	if aura_shader:
		_aura_material.shader = aura_shader
		_aura_material.render_priority = 9 # Renders behind void
		
	_aura_mesh_inst = MeshInstance3D.new()
	var quad = QuadMesh.new()
	quad.size = Vector2(4.0 * size_mult, 4.0 * size_mult)
	_aura_mesh_inst.mesh = quad
	_aura_mesh_inst.material_override = _aura_material
	_aura_mesh_inst.position = col_offset # Centered dynamically on hit-box
	add_child(_aura_mesh_inst)
	
	# 4. Status icons container
	_visual_container = Node3D.new()
	_visual_container.position = col_offset + Vector3(0, (col_height * 0.5 * size_mult) + 0.5, 0)
	add_child(_visual_container)

func _apply_overlay_recursive(node: Node) -> void:
	# Immediately halt recursion into UI and Status containers to prevent shader hijacking
	if node.name in ["StatusVisuals", "SelectionVisuals", "ProgressBar"] or "Highlight" in node.name:
		return
		
	if node is MeshInstance3D or node is Sprite3D or node is AnimatedSprite3D:
		# Cache original material to restore gracefully
		_original_materials[node] = node.material_override
		
		if node.has_meta("is_jellyfish"):
			var trans_void = _void_material.duplicate()
			trans_void.set_shader_parameter("alpha_mult", 0.4)
			trans_void.render_priority = 11 # Overlay translucent abyss strictly above opaque sections
			node.material_override = trans_void
			_affected_meshes.append(node)
		else:
			node.material_override = _void_material
			_affected_meshes.append(node)
			
	for child in node.get_children():
		_apply_overlay_recursive(child)

func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0: pop()
	
	if not elemental_component.has_element("abyss"):
		var em = get_tree().root.get_node_or_null("ElementManager")
		if em:
			var abyss_res = em.get_element("abyss")
			if abyss_res:
				elemental_component.add_or_refresh_status(abyss_res, 1)
	
	if has_meta("asphyxiate_timer"):
		var t = float(get_meta("asphyxiate_timer"))
		t -= delta
		if t <= 0:
			var rate = float(get_meta("asphyxiate_tick_rate"))
			t = rate
			var dmg = float(get_meta("asphyxiate_dmg"))
			var safe_source = source if is_instance_valid(source) else null
			
			if target.has_method("take_damage_no_conduct"):
				target.take_damage_no_conduct(dmg, safe_source)
			elif target.has_node("HealthComponent"):
				target.get_node("HealthComponent").take_damage_no_conduct(dmg, safe_source)
				
			if target.is_inside_tree() and target.get_tree().root.has_node("GameManager"):
				var gm = target.get_tree().root.get_node("GameManager")
				if gm.get("vfx_manager"):
					gm.vfx_manager.play_vfx("hurt", target.global_position)
		set_meta("asphyxiate_timer", t)

func extend_shell(time: float) -> void:
	_timer = min(_timer + time, 20.0)

func absorb_damage(amount: float, element: Resource) -> void:
	total_damage += amount
	if element: absorb_element(element, 1)
		
	if is_instance_valid(_aura_material):
		var tween = create_tween()
		var current = _aura_material.get_shader_parameter("pulse_expand")
		if current == null: current = 0.0
		tween.tween_method(func(v): _aura_material.set_shader_parameter("pulse_expand", v), 0.2, 0.0, 0.3)

func absorb_element(element: Resource, units: int) -> void:
	total_units += units
	var id = element.element_name.to_lower()
	var reacted = false
	
	var em = target.get_tree().root.get_node_or_null("ElementManager")
	if em:
		for stored in _stored_elements:
			var result = em.get_reaction_result(stored, id)
			if result != "": reacted = true
			
	if reacted:
		pass 
	else:
		if not _stored_elements.has(id): 
			_stored_elements.append(id)
			_update_element_bar()

func _update_element_bar() -> void:
	if not is_instance_valid(_visual_container): return
	for c in _visual_container.get_children(): c.queue_free()
	
	var count = _stored_elements.size()
	var spacing = 0.5
	var start_x = -((count - 1) * spacing) / 2.0
	
	var em = target.get_tree().root.get_node_or_null("ElementManager")
	if not em: return
	
	for i in range(count):
		var el_id = _stored_elements[i]
		var res = em.get_element(el_id)
		if res and res.icon:
			var sprite = Sprite3D.new()
			sprite.texture = res.icon
			sprite.pixel_size = 0.02
			sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			sprite.position = Vector3(start_x + (i * spacing), 0, 0)
			_visual_container.add_child(sprite)

func take_damage(amount: float, element: Resource = null, p_source: Node = null) -> void:
	absorb_damage(amount, element)

func take_damage_no_conduct(amount: float, p_source: Node = null) -> void:
	take_damage(amount, null, p_source)

func get_stat(stat_name: String, default_value: float = 0.0) -> float:
	if is_instance_valid(target) and target.has_method("get_stat"):
		return target.get_stat(stat_name, default_value)
	return default_value

func on_reaction() -> void:
	reaction_count += 1
	extend_shell(2.0)

func pop() -> void:
	if self.name == "PoppingShell": return
	self.name = "PoppingShell" 
	set_process(false)
	
	if is_instance_valid(_visual_container):
		_visual_container.visible = false
	
	if is_instance_valid(_aura_mesh_inst):
		var tween = create_tween().set_parallel(true)
		# Changed TRANS_BACK to TRANS_QUAD to eliminate sudden expanding bulge before shrinking
		tween.tween_property(_aura_mesh_inst, "scale", Vector3.ZERO, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		if is_instance_valid(_aura_material):
			tween.tween_method(func(v): _aura_material.set_shader_parameter("aura_color", Color(0.7, 0.1, 1.0, v)), 1.0, 0.0, 0.25)
	
	# Restore Original Materials cleanly
	for m in _affected_meshes:
		if is_instance_valid(m):
			m.material_override = _original_materials.get(m, null)
			
	var networking = 0.0
	var safe_source = source if is_instance_valid(source) else null
	if safe_source and safe_source.has_method("get_stat"):
		networking = safe_source.get_stat("networking", 0.0)
		
	var f_dmg = ((reaction_count + 0.1 * total_damage + 0.25 * total_units) * 0.5 * initial_units) + (0.5 * networking)
	
	if target.has_meta("pre_abyss_speed"):
		target.set("speed", target.get_meta("pre_abyss_speed"))
		target.remove_meta("pre_abyss_speed")
		
	var move_comp = target.get_node_or_null("MoveComponent")
	if move_comp and target.has_meta("pre_abyss_move_speed"):
		move_comp.move_speed = target.get_meta("pre_abyss_move_speed")
		target.remove_meta("pre_abyss_move_speed")
		
	var ec = target.get_node_or_null("ElementalComponent")
	if ec: 
		ec.process_mode = Node.PROCESS_MODE_INHERIT
		for id in ec.active_statuses:
			ec.active_statuses[id].duration = ec.active_statuses[id].resource.duration
	
	if target.is_inside_tree() and target.get_tree().root.has_node("GameManager"):
		var gm = target.get_tree().root.get_node("GameManager")
		if gm.get("vfx_manager"): gm.vfx_manager.play_vfx("abyss_pop", target.global_position)
	
	if target.has_method("take_damage_no_conduct"):
		target.take_damage_no_conduct(f_dmg, safe_source)
	elif target.has_node("HealthComponent"):
		target.get_node("HealthComponent").take_damage_no_conduct(f_dmg, safe_source)
		
	# Destroy Undine Host Jellyfish Gracefully if it was the target of Abyss
	if target.name == "UndineComponent" or target is UndineComponent:
		if target.has_method("pop"):
			target.pop()
		else:
			target.queue_free()
		
	get_tree().create_timer(0.35).timeout.connect(queue_free)
