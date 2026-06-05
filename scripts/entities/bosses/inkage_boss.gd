extends Enemy
class_name InkageBoss

var phase: int = 1
var base_pos: Vector3
var action_timer: float = 3.0
var is_in_action: bool = false
var base_cooldown_mult: float = 1.0

var dodges_left: int = 0
var is_charging_plane: bool = false
var is_raining: bool = false
var ink_rain_cd: float = 0.0
var is_ultimating: bool = false
var active_tarstreams: Array[Node] = []
var ult_tarstreams: Array[Node] = []
var ult_timer: float = 0.0
var big_tar_hole: MeshInstance3D

# New Defensive / Y2K Mechanics
var recent_damage_accumulator: float = 0.0
var ink_shield_active: bool = false
var ink_shield_mesh: MeshInstance3D
var ink_shield_hp: float = 0.0

func _ready() -> void:
	super._ready()
	
	is_field_enemy = true
	
	var depth = LaneManager.LANE_LENGTH - 5
	if LaneManager.fog_manager and LaneManager.fog_manager.current_fog_depth > 0:
		depth = LaneManager.fog_manager.current_fog_depth + 1
	
	var middle_lane = int(LaneManager.num_lanes / 2)
	base_pos = LaneManager.tile_to_world(Vector2i(depth, middle_lane))
	base_pos.y = 1.0
	global_position = base_pos
	
	_setup_boss_ui()
	_setup_red_highlight_system()
	
	var bind_hl = func(node_ref):
		if is_instance_valid(node_ref):
			_apply_red_highlight_recursive(node_ref)
			_set_glow_color(node_ref, Color(0.86, 0.08, 0.24, 0.8))
	get_tree().process_frame.connect(bind_hl.bind(self), CONNECT_ONE_SHOT)

func _setup_red_highlight_system() -> void:
	var root = get_tree().get_root()
	if root.has_node("RedHighlightViewport"): return
	
	var main_cam: Camera3D = null
	var main_scene = root.get_node_or_null("Main")
	if main_scene and main_scene.has_node("Camera3D"):
		main_cam = main_scene.get_node("Camera3D")
	else:
		main_cam = root.get_camera_3d()
		
	if not is_instance_valid(main_cam): return
	
	var viewport = SubViewport.new()
	viewport.name = "RedHighlightViewport"
	viewport.transparent_bg = true
	viewport.handle_input_locally = false
	viewport.gui_disable_input = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.size = root.size
	root.size_changed.connect(func(): viewport.size = root.size)
	root.call_deferred("add_child", viewport)
	
	var highlight_cam = Camera3D.new()
	highlight_cam.name = "RedHighlightCamera"
	highlight_cam.cull_mask = 2048
	
	var env = Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.background_color = Color(0, 0, 0, 0)
	highlight_cam.environment = env
	
	viewport.add_child(highlight_cam)
	
	var script = GDScript.new()
	script.source_code = """
extends Camera3D
var target_cam: Camera3D
func _process(delta):
	if is_instance_valid(target_cam):
		global_transform = target_cam.global_transform
		projection = target_cam.projection
		size = target_cam.size
		fov = target_cam.fov
		near = target_cam.near
		far = target_cam.far
"""
	script.reload()
	highlight_cam.set_script(script)
	highlight_cam.set("target_cam", main_cam)
	highlight_cam.set_process(true)
	
	var outline_layer = CanvasLayer.new()
	outline_layer.name = "RedHighlightEffectLayer"
	outline_layer.layer = 10
	
	var outline_rect = ColorRect.new()
	outline_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	outline_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var outline_mat = ShaderMaterial.new()
	outline_mat.shader = load("res://shaders/highlight_outline.gdshader")
	if outline_mat.shader:
		outline_mat.set_shader_parameter("width_outline", 3.0)
		outline_mat.set_shader_parameter("color_outline", Color(0.86, 0.08, 0.24, 1.0))
		outline_mat.set_shader_parameter("highlighted_viewport_tex", viewport.get_texture())
	
	outline_rect.material = outline_mat
	outline_layer.add_child(outline_rect)
	root.call_deferred("add_child", outline_layer)

func _apply_red_highlight_recursive(node: Node) -> void:
	if node is VisualInstance3D:
		node.set_layer_mask_value(11, false)
		node.set_layer_mask_value(12, true)
	for child in node.get_children():
		_apply_red_highlight_recursive(child)

func _set_glow_color(node: Node, color: Color) -> void:
	if node is MeshInstance3D and node.material_overlay is ShaderMaterial:
		node.material_overlay.set_shader_parameter("glow_color", color)
	elif (node is Sprite3D or node is AnimatedSprite3D) and node.material_override is ShaderMaterial:
		node.material_override.set_shader_parameter("glow_color", color)
	for child in node.get_children():
		_set_glow_color(child, color)

func _setup_boss_ui() -> void:
	if is_instance_valid(boss_ui): return
	
	boss_ui = CanvasLayer.new()
	boss_ui.layer = 100
	
	var panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	panel.custom_minimum_size = Vector2(600, 60)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	panel.offset_left = -300
	panel.offset_right = 300
	panel.offset_bottom = -110 
	panel.offset_top = -180
	
	if ClassDB.class_exists("WindowUtils") or ResourceLoader.exists("res://scripts/ui/window_utils.gd"):
		var wu = load("res://scripts/ui/window_utils.gd")
		wu.apply_liquid_glass(panel, 12.0)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	panel.add_child(margin)
	
	var vbox = VBoxContainer.new()
	margin.add_child(vbox)
	
	var lbl = Label.new()
	lbl.text = enemy_resource.enemy_name if enemy_resource else "Inkage, The Slathered Mage"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var font = load("res://assets/fonts/v2-fs-tahoma-8px.otf")
	if font: lbl.add_theme_font_override("font", font)
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 4)
	vbox.add_child(lbl)
	
	hp_bar = ProgressBar.new()
	hp_bar.custom_minimum_size = Vector2(0, 24)
	hp_bar.show_percentage = false
	
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	sb.border_width_left = 2; sb.border_width_right = 2
	sb.border_width_top = 2; sb.border_width_bottom = 2
	sb.border_color = Color(0.6, 0.1, 0.2, 1.0)
	hp_bar.add_theme_stylebox_override("background", sb)
	
	var sbf = StyleBoxFlat.new()
	sbf.bg_color = Color(0.9, 0.2, 0.3, 1.0)
	hp_bar.add_theme_stylebox_override("fill", sbf)
	vbox.add_child(hp_bar)
	
	boss_ui.add_child(panel)
	get_tree().root.call_deferred("add_child", boss_ui)
	
	if health_component:
		hp_bar.max_value = health_component.max_health
		hp_bar.value = health_component.current_health

func _process_grid_movement(_delta: float) -> void:
	velocity.x = 0
	velocity.z = 0
	
func _check_aggro(_delta: float) -> void: pass
func _pick_wander_target() -> void: pass
func _start_attacking_sequence(_t: Node) -> void: pass

func _play_vfx(vfx_name: String, pos: Vector3) -> void:
	if get_tree().root.has_node("GameManager"):
		var gm = get_tree().root.get_node("GameManager")
		if gm.get("vfx_manager"):
			gm.vfx_manager.play_vfx(vfx_name, pos)

func take_damage(amount: float, element: ElementResource = null, source: Node = null) -> void:
	if is_raining or (global_position.y > 2.0 and not is_staggered):
		return 
		
	# Y2K Ink Shield Mitigation
	if ink_shield_active:
		ink_shield_hp -= amount
		_play_vfx("hurt", global_position)
		if ink_shield_hp <= 0:
			_break_ink_shield()
		# Highly mitigated damage transfers to boss
		super.take_damage(amount * 0.1, element, source)
		return

	if phase == 2 and dodges_left > 0 and source != self:
		dodges_left -= 1
		var target_lane = randi() % LaneManager.num_lanes
		var tp_pos = LaneManager.tile_to_world(Vector2i(LaneManager.world_to_tile(base_pos).x, target_lane))
		tp_pos.y = global_position.y
		_play_vfx("inkage_teleport", global_position)
		global_position = tp_pos
		_play_vfx("inkage_teleport", global_position)

		if dodges_left <= 0 and not is_raining:
			_start_charge_plane()
		return

	recent_damage_accumulator += amount
	super.take_damage(amount, element, source)
	
	if recent_damage_accumulator > 250.0 and not ink_shield_active and phase >= 2:
		_activate_ink_shield()

func _physics_process(delta: float) -> void:
	velocity.x = 0
	velocity.z = 0
	
	# Cool down burst accumulator
	if recent_damage_accumulator > 0:
		recent_damage_accumulator = max(0.0, recent_damage_accumulator - (40.0 * delta))
	
	super._physics_process(delta)
	if current_state == State.RAGDOLL or is_staggered: return
	
	if ink_rain_cd > 0: ink_rain_cd -= delta
	
	if phase == 1 and health_component and health_component.current_health <= health_component.max_health * 0.5:
		_enter_phase_2()
		return
	elif phase == 2 and health_component and health_component.current_health <= health_component.max_health * 0.15:
		_enter_phase_3()
		return
		
	if is_ultimating:
		_process_ultimate(delta)
		return
		
	if not is_in_action and not is_charging_plane:
		action_timer -= delta
		if action_timer <= 0:
			_pick_attack()

func _activate_ink_shield() -> void:
	ink_shield_active = true
	ink_shield_hp = 300.0
	recent_damage_accumulator = 0.0
	_play_vfx("inkage_cast", global_position + Vector3(0, 1.5, 0))
	
	ink_shield_mesh = MeshInstance3D.new()
	var sphere = SphereMesh.new()
	sphere.radius = 2.0
	sphere.height = 4.0
	ink_shield_mesh.mesh = sphere
	
	var mat = ShaderMaterial.new()
	var shader = load("res://shaders/y2k_ink_shield.gdshader")
	if shader: mat.shader = shader
	ink_shield_mesh.material_override = mat
	add_child(ink_shield_mesh)
	ink_shield_mesh.position.y = 1.0
	
	# Start a counter-attack
	_attack_screentone_burst()

func _break_ink_shield() -> void:
	ink_shield_active = false
	if is_instance_valid(ink_shield_mesh): ink_shield_mesh.queue_free()
	_play_vfx("abyss_pop", global_position)
	if health_component: health_component.stagger(1.5)

func _pick_attack() -> void:
	is_in_action = true
	
	if phase >= 2 and ink_rain_cd <= 0.0:
		_attack_ink_rain()
		return

	var roll = randi() % (5 if phase == 2 else 3)
	match roll:
		0: _attack_ink_bullets()
		1: _attack_paper_planes()
		2: _attack_inkhogs()
		3: _attack_morph_building()
		4: _attack_screentone_burst()

func _attack_screentone_burst() -> void:
	is_in_action = true
	_play_vfx("inkage_cast", global_position + Vector3(0, 1.5, 0))
	await get_tree().create_timer(1.0).timeout
	
	# Bullet Hell Spiral Pattern
	var projectiles = 16
	var angle_step = (PI * 2.0) / float(projectiles)
	var speed_mult = 1.2 if phase == 3 else 0.8
	
	for i in range(projectiles):
		if is_staggered or not is_instance_valid(self): break
		var current_angle = float(i) * angle_step
		var dir = Vector3(cos(current_angle), 0, sin(current_angle)).normalized()
		var spawn_pos = global_position + (dir * 1.5)
		
		# FIXED: Removed 'var proj =' variable assignment to void function
		_spawn_spiral_projectile(spawn_pos, dir, 8.0 * speed_mult)
		await get_tree().create_timer(0.05).timeout
		
	await get_tree().create_timer(1.0 * base_cooldown_mult).timeout
	_end_attack()

func _spawn_spiral_projectile(pos: Vector3, dir: Vector3, hp: float) -> void:
	var target_lane = LaneManager.world_to_tile(pos).y
	_spawn_destructible_projectile(target_lane, pos, hp, false, true)

func _enter_phase_2() -> void:
	phase = 2
	is_in_action = true
	dodges_left = 3
	base_cooldown_mult = 0.8
	_play_vfx("inkage_cast", global_position + Vector3(0, 1.5, 0))
	
	if health_component:
		health_component.stagger(2.0)
		
	await get_tree().create_timer(2.0).timeout
	_end_attack()

func _attack_ink_rain() -> void:
	_play_vfx("inkage_cast", global_position + Vector3(0, 1.5, 0))
	is_raining = true
	
	await get_tree().create_timer(1.0).timeout
	
	for i in range(5):
		if is_staggered or is_ultimating: break
		var rx = randi_range(-3, 3)
		var rz = randi_range(-2, 2)
		var tile = LaneManager.world_to_tile(base_pos) + Vector2i(rx, rz)
		tile.y = clamp(tile.y, 0, LaneManager.num_lanes - 1)
		
		_spawn_red_tarstream(tile, 8.0, false)
		await get_tree().create_timer(0.4).timeout
		
	is_raining = false
	ink_rain_cd = 10.0
	_end_attack()

func _attack_ink_bullets() -> void:
	_play_vfx("inkage_cast", global_position + Vector3(0, 1.5, 0))
	await get_tree().create_timer(1.0).timeout
	
	var target_lane = randi() % LaneManager.num_lanes
	var tp_pos = LaneManager.tile_to_world(Vector2i(LaneManager.world_to_tile(base_pos).x, target_lane))
	tp_pos.y = target_y_pos
	
	_play_vfx("inkage_teleport", global_position)
	global_position = tp_pos
	_play_vfx("inkage_teleport", global_position)
	
	await get_tree().create_timer(0.5).timeout
	
	var hp_mult = 2.0 if phase >= 2 else 1.0
	for i in range(3):
		if is_staggered or is_ultimating: break
		_spawn_destructible_projectile(target_lane, global_position, 1.0 * hp_mult, false)
		await get_tree().create_timer(0.3 * base_cooldown_mult).timeout
		
	await get_tree().create_timer(0.5).timeout
	if not is_ultimating and not is_raining: 
		base_pos.y = target_y_pos
		global_position = base_pos
	_end_attack()

func _attack_paper_planes() -> void:
	_play_vfx("inkage_cast", global_position + Vector3(0, 1.5, 0))
	await get_tree().create_timer(1.0).timeout

	var target_lane = randi() % LaneManager.num_lanes
	var tp_pos = LaneManager.tile_to_world(Vector2i(LaneManager.world_to_tile(base_pos).x, target_lane))
	tp_pos.y = target_y_pos
	
	var hp_mult = 2.0 if phase >= 2 else 1.0
	var leave_trail = (phase >= 2)
	_spawn_destructible_projectile(target_lane, tp_pos, 5.0 * hp_mult, true, leave_trail)
	await get_tree().create_timer(1.0 * base_cooldown_mult).timeout
	_end_attack()

func _attack_inkhogs() -> void:
	_play_vfx("inkage_cast", global_position + Vector3(0, 1.5, 0))
	await get_tree().create_timer(1.0).timeout
	var hog_res = load("res://resources/enemies/inkhog.tres")
	for i in range(LaneManager.num_lanes):
		var pos = LaneManager.tile_to_world(Vector2i(LaneManager.world_to_tile(base_pos).x, i))
		pos.y = 1.0
		if hog_res and hog_res.scene:
			var hog = hog_res.scene.instantiate()
			hog.enemy_resource = hog_res
			var container = get_tree().current_scene.get_node_or_null("Enemies")
			if container: container.add_child(hog)
			else: get_tree().current_scene.add_child(hog)
			hog.global_position = pos
			hog.set_as_wave_enemy()
	await get_tree().create_timer(1.0 * base_cooldown_mult).timeout
	_end_attack()

func _attack_morph_building() -> void:
	_play_vfx("inkage_cast", global_position + Vector3(0, 1.5, 0))
	await get_tree().create_timer(1.0).timeout
	var buildings = get_tree().get_nodes_in_group("buildings")
	var valid = []
	for b in buildings:
		if not b.is_in_group("core") and not b.is_in_group("clutter"):
			valid.append(b)
	
	if valid.size() > 0:
		var target_b = valid.pick_random()
		var tile = LaneManager.world_to_tile(target_b.global_position)
		
		var tp_pos = LaneManager.tile_to_world(tile + Vector2i(1, 0))
		tp_pos.y = target_y_pos
		_play_vfx("inkage_teleport", global_position)
		global_position = tp_pos
		_play_vfx("inkage_teleport", global_position)
		
		await get_tree().create_timer(0.5).timeout
		
		target_b.process_mode = Node.PROCESS_MODE_DISABLED
		target_b.visible = false
		
		var ts = _spawn_red_tarstream(tile, 5.0)
		
		await get_tree().create_timer(0.5).timeout
		if not is_ultimating and not is_raining:
			base_pos.y = target_y_pos
			global_position = base_pos
		
		get_tree().create_timer(5.0).timeout.connect(func():
			if is_instance_valid(target_b):
				target_b.process_mode = Node.PROCESS_MODE_INHERIT
				target_b.visible = true
		)
		
	await get_tree().create_timer(1.0 * base_cooldown_mult).timeout
	_end_attack()

func _start_charge_plane() -> void:
	if is_charging_plane: return
	is_charging_plane = true
	is_in_action = true
	_play_vfx("inkage_cast", global_position + Vector3(0, 1.5, 0))
	await get_tree().create_timer(5.0).timeout
	
	if is_staggered or is_ultimating: 
		is_charging_plane = false
		return
		
	_spawn_destructible_projectile(LaneManager.world_to_tile(global_position).y, global_position, 10.0, true, true)
	is_charging_plane = false
	if not is_raining:
		_end_attack()

func _enter_phase_3() -> void:
	phase = 3
	is_in_action = true
	is_ultimating = true
	is_charging_plane = false
	dodges_left = 0
	
	target_y_pos = 8.0
	
	var count = active_tarstreams.size()
	for ts in active_tarstreams:
		if is_instance_valid(ts): ts.queue_free()
	active_tarstreams.clear()
	
	_spawn_big_tar_hole()
	
	var to_spawn = 3 + count
	ult_tarstreams.clear()
	for i in range(to_spawn):
		var rx = randi_range(-15, 15)
		var rz = randi_range(-4, 4)
		var tile = LaneManager.world_to_tile(base_pos) + Vector2i(rx, rz)
		tile.y = clamp(tile.y, 0, LaneManager.num_lanes - 1)
		var ts = _spawn_red_tarstream(tile, 0.0, true)
		ult_tarstreams.append(ts)
		
	ult_timer = 20.0

func _process_ultimate(delta: float) -> void:
	ult_timer -= delta
	ult_tarstreams = ult_tarstreams.filter(func(ts): return is_instance_valid(ts) and not ts.is_queued_for_deletion())
	
	if is_instance_valid(big_tar_hole):
		var scale_val = lerp(1.0, 10.0, 1.0 - (ult_timer / 20.0))
		big_tar_hole.scale = Vector3(scale_val, 1, scale_val)
		
	if ult_tarstreams.size() == 0 and ult_timer > 0:
		is_ultimating = false
		target_y_pos = 1.0
		if is_instance_valid(big_tar_hole): big_tar_hole.queue_free()
		if health_component: health_component.stagger(5.0)
		get_tree().create_timer(5.0).timeout.connect(_end_attack)
	elif ult_timer <= 0:
		is_ultimating = false
		target_y_pos = 1.0
		if is_instance_valid(big_tar_hole): big_tar_hole.queue_free()
		_end_attack()

func _spawn_big_tar_hole() -> void:
	big_tar_hole = MeshInstance3D.new()
	var pm = PlaneMesh.new()
	pm.size = Vector2(2, 2)
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.1, 0.0, 0.0, 0.95)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	big_tar_hole.mesh = pm
	big_tar_hole.material_override = mat
	get_tree().current_scene.add_child(big_tar_hole)
	big_tar_hole.global_position = base_pos
	big_tar_hole.global_position.y = 0.02
	_apply_red_highlight_recursive(big_tar_hole)

func _spawn_red_tarstream(tile: Vector2i, duration: float = 15.0, _is_ult: bool = false) -> Node:
	var ts = null
	var ts_scene = load("res://scenes/buildables/tarstream.tscn")
	if ts_scene: ts = ts_scene.instantiate()
	
	if not ts:
		ts = Area3D.new()
	else:
		ts.add_to_group("red_tarstream")
		ts.call_deferred("add_child", Node.new())
		var bind_hl = func(node_ref):
			if is_instance_valid(node_ref):
				_apply_red_highlight_recursive(node_ref)
		get_tree().process_frame.connect(bind_hl.bind(ts), CONNECT_ONE_SHOT)
			
		var detector = Area3D.new()
		detector.collision_layer = 0
		detector.collision_mask = 4 | 1 
		var col = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = Vector3(1.5, 1.0, 1.5)
		col.shape = shape
		col.position = Vector3(0, 0.5, 0)
		detector.add_child(col)
		ts.add_child(detector)
		
		detector.body_entered.connect(func(body):
			if body.is_in_group("allies") or body.is_in_group("player"):
				if is_instance_valid(ts): ts.queue_free()
		)
		
	get_tree().current_scene.add_child(ts)
	ts.global_position = LaneManager.tile_to_world(tile)
	
	var old_wire = LaneManager.get_entity_at(tile, "wire")
	LaneManager.register_entity(ts, tile, "wire")
	
	ts.tree_exiting.connect(func():
		if LaneManager.get_entity_at(tile, "wire") == ts:
			if is_instance_valid(old_wire):
				LaneManager.register_entity(old_wire, tile, "wire")
			else:
				LaneManager.unregister_entity(tile, "wire")
	)
	
	if duration > 0:
		get_tree().create_timer(duration).timeout.connect(func():
			if is_instance_valid(ts): ts.queue_free()
		)

	active_tarstreams.append(ts)
	return ts

func _spawn_destructible_projectile(lane_id: int, start_pos: Vector3, hp: float, is_plane: bool, leave_trail: bool = false) -> void:
	var proj = null
	
	if is_plane:
		var plane_scene = load("res://scenes/attacks/fold_plane.tscn")
		if plane_scene: proj = plane_scene.instantiate()
			
	if not proj:
		proj = Area3D.new()
		var mesh = MeshInstance3D.new()
		mesh.mesh = BoxMesh.new()
		mesh.mesh.size = Vector3(0.5, 0.2, 0.5) if is_plane else Vector3(0.3, 0.3, 0.3)
		proj.add_child(mesh)
		
		var col = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = mesh.mesh.size
		col.shape = shape
		col.position = Vector3(0, 0.2, 0) 
		proj.add_child(col)
		
	proj.collision_layer = 2
	proj.collision_mask = 1
	
	var hc = HealthComponent.new()
	hc.max_health = hp
	hc.name = "HealthComponent"
	proj.add_child(hc)
	
	_color_meshes_black(proj)
	var bind_hl = func(node_ref):
		if is_instance_valid(node_ref):
			_apply_red_highlight_recursive(node_ref)
	get_tree().process_frame.connect(bind_hl.bind(proj), CONNECT_ONE_SHOT)
	
	var atk_id = "inkage_plane" if is_plane else "inkage_bullet"
	var atk = load("res://resources/attacks/" + atk_id + ".tres")
	
	if not atk:
		atk = AttackResource.new()
		atk.base_damage = 10.0
		atk.damage_equation = "base_damage + (attack_damage * attack_damage_weight)"
		atk.stat_weights = {"attack_damage": 1.0}
		var em = get_tree().root.get_node_or_null("ElementManager")
		if em: atk.element = em.get_element("dark")
	
	var final_dmg = 10.0
	if attacker_component and attacker_component.processor:
		final_dmg = attacker_component.processor.calculate_damage(self, atk)
		
	var script = load("res://scripts/attacks/inkage_projectile.gd")
	if script:
		proj.set_script(script)
		proj.speed = 10.0 if leave_trail else (8.0 if is_plane else 15.0)
		proj.damage = final_dmg
		proj.is_plane = is_plane
		proj.leave_trail = leave_trail
		proj.boss_ref = self
		proj.attack_res = atk
	
	get_tree().root.add_child(proj)
	proj.global_position = start_pos
	proj.global_position.y = target_y_pos

func _color_meshes_black(node: Node) -> void:
	if node is MeshInstance3D:
		if node.mesh:
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(0.1, 0.1, 0.1, 1.0)
			node.material_override = mat
	for child in node.get_children():
		_color_meshes_black(child)

func _end_attack() -> void:
	is_in_action = false
	action_timer = 3.0 * base_cooldown_mult
