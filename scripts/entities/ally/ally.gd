class_name Ally
extends CharacterBody3D

@export var display_name: String = "Ally"
@export var stats: AllyResource 

enum AllyMode {
	IDLE,
	TOOL,
	ATTACK
}

var current_mode: AllyMode = AllyMode.IDLE
var health_component: HealthComponent
var move_component: MoveComponent
var inventory_component: InventoryComponent
var attacker_component: AttackerComponent
var stat_component: StatComponent
var interaction_component: InteractionComponent
var respawn_component: RespawnComponent

const SLOT_TOOL = 0
const SLOT_WEAPON = 1
const SLOT_ARMOR = 2
const SLOT_ARTIFACT = 3

var active_weapon_item: Resource = null
var is_dead: bool = false
var facing_direction: Vector3 = Vector3(1, 0, 0)

# Visuals & State
var selection_container: Node3D
var _vis_tween: Tween
var _tint_tween: Tween
var _tint_materials: Array[StandardMaterial3D] =[]
var _tint_sprites: Array[Node] =[]
var progress_bar: Node3D 
var _visuals_node: Node3D

var _visuals_base_transform: Transform3D
var _base_visuals_y: float = 0.0
var _base_visuals_scale: Vector3 = Vector3.ONE

var _hop_phase: float = 0.0
var _path_progress: float = 0.0
var _last_pos2d: Vector2 = Vector2.ZERO

func _ready() -> void:
	collision_layer = 4 
	collision_mask = 0 
	add_to_group("allies")
	
	_last_pos2d = Vector2(global_position.x, global_position.z)
	
	stat_component = load("res://scripts/components/stat_component.gd").new()
	stat_component.name = "StatComponent"
	add_child(stat_component)
	stat_component.stats_changed.connect(_on_stats_changed)
	
	interaction_component = load("res://scripts/components/interaction_component.gd").new()
	interaction_component.name = "InteractionComponent"
	add_child(interaction_component)
	
	respawn_component = load("res://scripts/components/respawn_component.gd").new()
	respawn_component.name = "RespawnComponent"
	add_child(respawn_component)
	
	var r_count = stats.get("respawns_count") if stats and stats.get("respawns_count") != null else 0
	var r_unlim = stats.get("respawns_unlimited") if stats and stats.get("respawns_unlimited") != null else false
	var r_cd = stats.get("respawns_cooldown") if stats and stats.get("respawns_cooldown") != null else 5.0
	respawn_component.setup(r_count, r_unlim, r_cd)

	health_component = get_node_or_null("HealthComponent")
	move_component = get_node_or_null("MoveComponent")
	attacker_component = get_node_or_null("AttackerComponent")
	
	if not attacker_component:
		attacker_component = AttackerComponent.new()
		attacker_component.name = "AttackerComponent"
		add_child(attacker_component)
	if not attacker_component.attack_started.is_connected(_on_attack_started):
		attacker_component.attack_started.connect(_on_attack_started)
		
	if not inventory_component:
		inventory_component = get_node_or_null("InventoryComponent")
	
	if health_component:
		health_component.health_changed.connect(_on_health_changed)
		
	_visuals_node = get_node_or_null("Visuals")
	if not _visuals_node:
		for child in get_children():
			if child is Node3D and not (child is CollisionShape3D):
				if child.name.ends_with("Component"): continue
				if child.name == "SelectionVisuals" or child.name == "ProgressBar": continue
				if "visible" in child and not child.visible: continue
				_visuals_node = child
				break
				
	if is_instance_valid(_visuals_node):
		_visuals_base_transform = _visuals_node.transform
		_base_visuals_y = _visuals_node.position.y
		_base_visuals_scale = _visuals_node.scale
	
	if stats and stats.get("ally_name") != null: 
		display_name = str(stats.get("ally_name"))
	
	if inventory_component:
		var ItemResClass = load("res://scripts/resources/item_resource.gd")
		if ItemResClass:
			inventory_component.set_slot_restriction(SLOT_TOOL, ItemResClass.EquipmentType.TOOL)
			inventory_component.set_slot_restriction(SLOT_WEAPON, ItemResClass.EquipmentType.WEAPON)
			inventory_component.set_slot_restriction(SLOT_ARMOR, ItemResClass.EquipmentType.ARMOR)
			inventory_component.set_slot_restriction(SLOT_ARTIFACT, ItemResClass.EquipmentType.ACCESSORY)
		
	_setup_selection_visuals()
	_setup_progress_bar()
	_cache_visual_materials(self)
	_apply_retro_glow(self)
	_on_stats_changed()

func _exit_tree() -> void:
	var main = get_tree().current_scene
	if main and main.get("selection_controller"):
		var sc = main.selection_controller
		if "selected_allies" in sc:
			for i in range(sc.selected_allies.size() - 1, -1, -1):
				if sc.selected_allies[i] == self or not is_instance_valid(sc.selected_allies[i]):
					sc.selected_allies.remove_at(i)

func _input(event: InputEvent) -> void:
	if not is_instance_valid(selection_container) or not selection_container.visible: return
	if is_dead: return
	
	if event.is_action_pressed("switch"):
		_cycle_mode()

func _cycle_mode() -> void:
	match current_mode:
		AllyMode.IDLE: current_mode = AllyMode.TOOL
		AllyMode.TOOL: current_mode = AllyMode.ATTACK
		AllyMode.ATTACK: current_mode = AllyMode.IDLE
	
	if current_mode == AllyMode.ATTACK:
		if not attacker_component or not attacker_component.basic_attack or not active_weapon_item:
			current_mode = AllyMode.IDLE
			_show_notification("No Weapon Equipped", Color.RED)
	
	if current_mode != AllyMode.ATTACK:
		if attacker_component: attacker_component.stop_attacking()
	if current_mode != AllyMode.TOOL:
		if ToolManager.instance: ToolManager.instance.active_miners.erase(self)
	
	_show_mode_notification()

func _show_mode_notification() -> void:
	var mode_name = AllyMode.keys()[current_mode]
	var col = Color.WHITE
	match current_mode:
		AllyMode.TOOL: col = Color.GREEN
		AllyMode.ATTACK: col = Color.RED
		AllyMode.IDLE: col = Color.GRAY
	_show_notification("%s Mode: %s" %[display_name, mode_name], col)

func _show_notification(text: String, col: Color) -> void:
	var ui = get_node_or_null("/root/Main/GameUI")
	if ui: ui.show_notification(text, col)

func _process(delta: float) -> void:
	if is_dead: return
	
	var current_pos2d = Vector2(global_position.x, global_position.z)
	var step_vec = current_pos2d - _last_pos2d
	_last_pos2d = current_pos2d
	
	if velocity.length_squared() > 0.01:
		var dir = velocity.normalized()
		dir.y = 0
		if dir.length_squared() > 0:
			facing_direction = dir.normalized()

	match current_mode:
		AllyMode.TOOL: _process_auto_mine(delta)
		AllyMode.ATTACK: _process_attack_mode(delta)
		AllyMode.IDLE: pass
	
	if interaction_component.is_interacting: interaction_component.process_interaction(delta)
	elif interaction_component.is_centering: interaction_component.process_centering()
	_update_bar_visual()
	
	var base_spd = stats.get("speed") if stats and stats.get("speed") != null else 5.0
	var active_speed = get_stat("speed", float(base_spd))
	if move_component:
		move_component.move_speed = active_speed
	
	var moving = false
	if velocity.length_squared() > 0.01:
		moving = true
	elif move_component and move_component.is_moving:
		moving = true
	elif get("is_moving") != null and get("is_moving") == true:
		moving = true
		
	if is_instance_valid(_visuals_node):
		if moving and step_vec.length_squared() > 0.00001:
			var forward_dist = step_vec.length()
			var grid_scale = 1.0
			if Engine.has_singleton("LaneManager"): grid_scale = LaneManager.GRID_SCALE
			_path_progress += forward_dist / grid_scale
			_hop_phase = fmod(_path_progress, 1.0)
		else:
			if _hop_phase > 0.0:
				var settle_speed = max(4.0, active_speed)
				if _hop_phase > 0.5:
					_hop_phase += delta * settle_speed
					if _hop_phase >= 1.0: 
						_hop_phase = 0.0
						_path_progress = 0.0
				else:
					_hop_phase -= delta * settle_speed
					if _hop_phase <= 0.0: 
						_hop_phase = 0.0
						_path_progress = 0.0
						
		if _hop_phase > 0.0 or (moving and step_vec.length_squared() > 0.00001):
			var p = _hop_phase
			var hop_height = 0.8
			var y_offset = 4.0 * hop_height * p * (1.0 - p)
			var impact = pow(cos(p * PI), 6.0) 
			var mid_air = sin(p * PI)
			
			var scale_y = 1.0 - (0.3 * impact) + (0.15 * mid_air)
			var scale_xz = 1.0 + (0.3 * impact) - (0.15 * mid_air)
			
			var physical_speed = 0.0
			if delta > 0: physical_speed = step_vec.length() / delta
			var tilt_intensity = clamp(physical_speed * 0.02, 0.0, 0.35)
			var tilt_angle = -sin(p * PI * 2.0) * tilt_intensity
			
			_visuals_node.position.y = _base_visuals_y + y_offset
			_visuals_node.scale = _base_visuals_scale * Vector3(scale_xz, scale_y, scale_xz)
			_visuals_node.rotation.z = tilt_angle
		else:
			_visuals_node.position.y = lerp(_visuals_node.position.y, _base_visuals_y, delta * 15.0)
			_visuals_node.scale = _visuals_node.scale.lerp(_base_visuals_scale, delta * 15.0)
			_visuals_node.rotation.z = lerp_angle(_visuals_node.rotation.z, 0.0, delta * 15.0)

func _process_attack_mode(_delta: float) -> void:
	if not attacker_component or not attacker_component.basic_attack: return
	if not active_weapon_item: return
	
	# Prevent constantly requesting new attack targets if currently casting or on cooldown
	if not attacker_component.attack_timer.is_stopped() or attacker_component.is_casting: return
		
	var atk = attacker_component.basic_attack
	var current_tile = LaneManager.world_to_tile(global_position)
	var dir_x = 0
	var dir_z = 0
	if abs(facing_direction.x) > abs(facing_direction.z): dir_x = sign(facing_direction.x)
	else: dir_z = sign(facing_direction.z)
		
	var range_val = atk.max_range
	if range_val == 0: range_val = 1
	
	var target_tile = current_tile + Vector2i(dir_x * range_val, dir_z * range_val)
	var target_pos = LaneManager.tile_to_world(target_tile)
	target_pos.y = global_position.y
	attacker_component.start_attacking_position(target_pos)

func _on_attack_started(target: Node3D, _attack_res: AttackResource) -> void:
	if current_mode == AllyMode.ATTACK and not is_instance_valid(target):
		var current_tile = LaneManager.world_to_tile(global_position)
		var target_tile = LaneManager.world_to_tile(attacker_component.current_target_pos)
		var dir_x = 0; var dir_z = 0
		if abs(facing_direction.x) > abs(facing_direction.z): dir_x = sign(facing_direction.x)
		else: dir_z = sign(facing_direction.z)

func _cache_visual_materials(node: Node) -> void:
	if node.name == "SelectionVisuals" or node.name == "ProgressBar": return
	if node is Sprite3D or node is AnimatedSprite3D:
		_tint_sprites.append(node)
	elif node is MeshInstance3D:
		if node.mesh:
			var surf_count = node.mesh.get_surface_count()
			for i in range(surf_count):
				var mat = node.get_active_material(i)
				if not mat: mat = StandardMaterial3D.new()
				if mat is StandardMaterial3D:
					var unique_mat = mat.duplicate()
					node.set_surface_override_material(i, unique_mat)
					_tint_materials.append(unique_mat)
	for child in node.get_children():
		_cache_visual_materials(child)

func _apply_retro_glow(node: Node) -> void:
	if not is_instance_valid(node): return
	if node.name == "SelectionVisuals" or node.name == "ProgressBar": return
	if node is MeshInstance3D:
		var glow_mat = ShaderMaterial.new()
		glow_mat.shader = load("res://shaders/retro_glow.gdshader")
		if glow_mat.shader:
			glow_mat.set_shader_parameter("glow_color", Color(0.1, 0.8, 1.0, 0.8))
			glow_mat.set_shader_parameter("fresnel_power", 2.0)
			glow_mat.set_shader_parameter("edge_intensity", 1.5)
			node.material_overlay = glow_mat
	elif node is Sprite3D or node is AnimatedSprite3D:
		var sprite_mat = ShaderMaterial.new()
		sprite_mat.shader = load("res://shaders/sprite_retro_glow.gdshader")
		if sprite_mat.shader:
			sprite_mat.set_shader_parameter("glow_color", Color(0.1, 0.8, 1.0, 0.8))
			sprite_mat.set_shader_parameter("width", 2.0)
			if node.material_override:
				var base_tex = null
				if node.material_override is StandardMaterial3D:
					base_tex = node.material_override.albedo_texture
				sprite_mat.set_shader_parameter("texture_albedo", base_tex)
			else:
				if "texture" in node and node.get("texture"):
					sprite_mat.set_shader_parameter("texture_albedo", node.texture)
				elif "sprite_frames" in node and node is AnimatedSprite3D:
					if node.sprite_frames and node.animation:
						sprite_mat.set_shader_parameter("texture_albedo", node.sprite_frames.get_frame_texture(node.animation, node.frame))
			node.material_override = sprite_mat

	for child in node.get_children():
		_apply_retro_glow(child)

func _on_health_changed(new_val, old_val) -> void:
	if new_val < old_val: _flash_damage()

func _flash_damage() -> void:
	if _tint_tween: _tint_tween.kill()
	_tint_tween = create_tween()
	var base_col = Color.WHITE
	var damage_col = Color(1.0, 0.4, 0.4, 1.0)
	_tint_tween.tween_method(_apply_tint_ratio.bind(base_col, damage_col), 1.0, 0.0, 0.3)

func _apply_tint_ratio(ratio: float, base: Color, dmg: Color) -> void:
	var final = base.lerp(dmg, ratio)
	for s in _tint_sprites: if is_instance_valid(s): s.modulate = final
	for m in _tint_materials: if is_instance_valid(m): m.albedo_color = final

func _process_auto_mine(_delta: float) -> void:
	if not ToolManager.instance: return
	if ToolManager.instance.active_miners.has(self): return
	var tool_item = _get_item_in_slot(SLOT_TOOL)
	if not tool_item: return
	
	var target_data = ToolManager.instance._find_target_at_agent(self, tool_item)
	if not target_data.is_empty():
		ToolManager.instance.request_mining(self, tool_item)
		if move_component: move_component.stop_moving()

func _get_item_in_slot(slot_idx: int) -> Resource:
	if not inventory_component: return null
	if inventory_component.slots.size() > slot_idx:
		var s = inventory_component.slots[slot_idx]
		if s and s.item: return s.item
	return null

func activate_mode() -> void:
	match current_mode:
		AllyMode.TOOL: _process_auto_mine(0.0)
		AllyMode.ATTACK: pass
		AllyMode.IDLE: pass

func _setup_progress_bar() -> void:
	if ClassDB.class_exists("WorldProgressBar") or (is_instance_valid(load("res://scripts/ui/world_progress_bar.gd"))):
		var script = load("res://scripts/ui/world_progress_bar.gd")
		if script:
			progress_bar = script.new()
			progress_bar.name = "ProgressBar"
			progress_bar.position = Vector3(0, 2.4, 0)
			progress_bar.visible = false
			add_child(progress_bar)

func _update_bar_visual() -> void:
	if not progress_bar: return
	if interaction_component.is_interacting:
		progress_bar.visible = true
		progress_bar.fill_color = Color(1.0, 0.85, 0.2)
		progress_bar.progress = interaction_component.interaction_progress / interaction_component.interaction_duration
		return
	if ToolManager.instance and ToolManager.instance.active_miners.has(self):
		progress_bar.visible = true
		var data = ToolManager.instance.active_miners[self]
		progress_bar.fill_color = Color(0.2, 0.9, 0.3)
		if data.max_time > 0:
			progress_bar.progress = data.time / data.max_time
	else:
		progress_bar.visible = false

func get_stat(stat_name: String, default_value: float = 0.0) -> float:
	var val: float = default_value
	if stats:
		var raw = stats.get(stat_name)
		if raw != null:
			val = float(raw)
			
	if stat_component: 
		val = float(stat_component.get_stat(stat_name, val))
	
	if stats:
		var eq = ""
		match stat_name:
			"speed": eq = str(stats.get("speed_equation")) if stats.get("speed_equation") != null else ""
			"health": eq = str(stats.get("health_equation")) if stats.get("health_equation") != null else ""
			"defense": eq = str(stats.get("defense_equation")) if stats.get("defense_equation") != null else ""
			
		if eq != "":
			if ClassDB.class_exists("FormulaHelper") or ResourceLoader.exists("res://scripts/utils/formula_helper.gd"):
				var fh = load("res://scripts/utils/formula_helper.gd")
				if fh:
					var vars = {"base_" + stat_name: val}
					var weights = stats.get("stat_weights")
					if weights and typeof(weights) == TYPE_DICTIONARY:
						for k in weights.keys():
							vars[k+"_weight"] = weights[k]
							vars[k] = stat_component.get_stat(k, 0.0) if stat_component else 0.0
					val = fh.evaluate(stats, eq, vars, val)
	return float(val)

func _on_stats_changed() -> void:
	var base_spd = stats.get("speed") if stats and stats.get("speed") != null else 5.0
	var current_speed = get_stat("speed", float(base_spd))
	
	if health_component:
		var base_mhp = stats.get("max_health") if stats and stats.get("max_health") != null else 100.0
		health_component.max_health = get_stat("max_health", float(base_mhp))
		
		health_component.max_security = get_stat("security", float(stats.get("security") if stats and stats.get("security") != null else 0.0))
		health_component.defense = get_stat("defense", float(stats.get("defense") if stats and stats.get("defense") != null else 0.0))
		health_component.firewall = get_stat("firewall", float(stats.get("firewall") if stats and stats.get("firewall") != null else 0.0))
		health_component.malware = get_stat("malware", float(stats.get("malware") if stats and stats.get("malware") != null else 0.0))

	if inventory_component:
		var spc = get_stat("space", 10.0)
		var needed_slots = 4 + int(spc)
		if inventory_component.max_slots != needed_slots:
			inventory_component.set_capacity(needed_slots)

	if move_component:
		move_component.move_speed = current_speed
	
	var size_mult = get_stat("scale", float(stats.get("scale") if stats and stats.get("scale") != null else 1.0))
	
	var model = get_node_or_null("ModelContainer")
	if not model: model = get_node_or_null("Visual")
	if model:
		model.scale = Vector3(size_mult, size_mult, size_mult)

	_update_animation_speeds()

	active_weapon_item = null
	if inventory_component:
		var it = inventory_component.slots[SLOT_WEAPON]
		if it and it != null:
			if typeof(it) == TYPE_DICTIONARY: active_weapon_item = it.item
			elif it is ItemResource: active_weapon_item = it
			
	if attacker_component:
		if active_weapon_item and "attack_config" in active_weapon_item and active_weapon_item.attack_config:
			attacker_component.basic_attack = active_weapon_item.attack_config
		else:
			attacker_component.initialize(2.0, 1.0, null)

	if current_mode == AllyMode.ATTACK and (not attacker_component or not attacker_component.basic_attack):
		current_mode = AllyMode.IDLE
		if attacker_component: attacker_component.stop_attacking()

func _update_animation_speeds() -> void:
	var base_speed = stats.get("speed") if stats and stats.get("speed") != null else 5.0
	base_speed = float(base_speed)
	if base_speed <= 0: base_speed = 5.0
	
	var active_speed = get_stat("speed", base_speed)
	var speed_ratio = active_speed / base_speed
	_apply_animation_speed_recursive(self, speed_ratio)

func _apply_animation_speed_recursive(node: Node, ratio: float) -> void:
	if node is AnimatedSprite3D:
		node.speed_scale = ratio
	elif node is AnimationPlayer:
		node.speed_scale = ratio
	for child in node.get_children():
		_apply_animation_speed_recursive(child, ratio)

func _setup_selection_visuals() -> void:
	selection_container = Node3D.new()
	selection_container.name = "SelectionVisuals"
	selection_container.visible = false
	add_child(selection_container)
	
	var ring_mat = StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.0, 1.0, 0.5, 0.8)
	ring_mat.render_priority = 10 
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	var ring_mesh = TorusMesh.new()
	ring_mesh.inner_radius = 0.6
	ring_mesh.outer_radius = 0.7
	ring_mesh.rings = 16 
	ring_mesh.ring_segments = 8
	
	var rotator = Node3D.new()
	rotator.name = "Rotator"
	selection_container.add_child(rotator)
	
	var ring = MeshInstance3D.new()
	ring.mesh = ring_mesh
	ring.material_override = ring_mat
	ring.position = Vector3(0, 0.05, 0)
	ring.scale = Vector3(1.0, 0.1, 1.0)
	rotator.add_child(ring)

func set_selected(selected: bool) -> void:
	selection_container.visible = selected
	if selected: _animate_visuals()
	else: if _vis_tween: _vis_tween.kill()

func _animate_visuals() -> void:
	if _vis_tween: _vis_tween.kill()
	_vis_tween = create_tween().set_loops()
	var rot = selection_container.get_node_or_null("Rotator")
	if rot: _vis_tween.tween_property(rot, "rotation:y", 2*PI, 3.0).as_relative()

func command_move(target_pos: Vector3) -> void:
	if interaction_component: interaction_component.set_interaction(null, "")
	if move_component: move_component.move_to(target_pos)

func set_interaction(target: Node, type: String, data: Dictionary = {}) -> void:
	if interaction_component: interaction_component.set_interaction(target, type, data)

func use_equipped_tool() -> void: activate_mode()
func receive_item(item: Resource, _from_node: Node3D = null, _extra_data: Dictionary = {}) -> bool:
	if not inventory_component: return false
	return inventory_component.add_item(item) == 0