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

# Equipment Slots
const SLOT_TOOL = 0
const SLOT_WEAPON = 1
const SLOT_ARMOR = 2
const SLOT_ARTIFACT = 3

var active_weapon_item: ItemResource = null

# Visuals & State
var selection_container: Node3D
var _vis_tween: Tween
var _tint_tween: Tween
var _tint_materials: Array[StandardMaterial3D] =[]
var _tint_sprites: Array[Node] =[]
var progress_bar: Node3D 

# Interaction
var interaction_target: Node = null
var interaction_type: String = ""
var interaction_data: Dictionary = {}
var is_interacting: bool = false
var interaction_progress: float = 0.0
var interaction_duration: float = 2.0 
var centering_target: Vector3 = Vector3.ZERO
var is_centering: bool = false

var facing_direction: Vector3 = Vector3(1, 0, 0)

# Dynamic Combat Stats
var attack_damage: float = 0.0
var lux_stat: float = 0.0
var attack_speed_mult: float = 0.0
var damage_mult: float = 0.0

# Respawn configuration
var respawns_count: int = 0
var respawns_unlimited: bool = false
var respawns_cooldown: float = 5.0

func _ready() -> void:
	collision_layer = 4 
	collision_mask = 0 # No collision with buildings/clutter (phases through them)
	add_to_group("allies")
	
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
		health_component.died.connect(_on_died)
		health_component.health_changed.connect(_on_health_changed)
	
	if stats: _apply_stats_from_resource()
	
	if inventory_component:
		if not self.is_in_group("player"):
			inventory_component.set_slot_restriction(SLOT_TOOL, ItemResource.EquipmentType.TOOL)
			inventory_component.set_slot_restriction(SLOT_WEAPON, ItemResource.EquipmentType.WEAPON)
			inventory_component.set_slot_restriction(SLOT_ARMOR, ItemResource.EquipmentType.ARMOR)
			inventory_component.set_slot_restriction(SLOT_ARTIFACT, ItemResource.EquipmentType.ACCESSORY)
		
		if not inventory_component.inventory_changed.is_connected(_recalculate_stats):
			inventory_component.inventory_changed.connect(_recalculate_stats)
		
	_setup_selection_visuals()
	_setup_progress_bar()
	_cache_visual_materials(self)
	_recalculate_stats()
	
	if is_instance_valid(GameManager):
		GameManager.run_data_changed.connect(_recalculate_stats)

func _input(event: InputEvent) -> void:
	if not is_instance_valid(selection_container) or not selection_container.visible: return
	
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
	if velocity.length_squared() > 0.01:
		var dir = velocity.normalized()
		dir.y = 0
		if dir.length_squared() > 0:
			facing_direction = dir.normalized()

	match current_mode:
		AllyMode.TOOL:
			_process_auto_mine(delta)
		AllyMode.ATTACK:
			_process_attack_mode(delta)
		AllyMode.IDLE:
			pass
	
	if is_interacting: _process_interaction(delta)
	elif is_centering: _process_centering()
	_update_bar_visual()

func _process_attack_mode(_delta: float) -> void:
	if not attacker_component or not attacker_component.basic_attack: return
	if not active_weapon_item: return
		
	var atk = attacker_component.basic_attack
	
	# Continuously compute the tile strictly in front of the entity rather than scalar offsets
	var current_tile = LaneManager.world_to_tile(global_position)
	
	# Snap raw facing direction to a cardinal direction vector
	var dir_x = 0
	var dir_z = 0
	if abs(facing_direction.x) > abs(facing_direction.z):
		dir_x = sign(facing_direction.x)
	else:
		dir_z = sign(facing_direction.z)
		
	var range_val = atk.max_range
	if range_val == 0: range_val = 1
	
	var target_tile = current_tile + Vector2i(dir_x * range_val, dir_z * range_val)
	var target_pos = LaneManager.tile_to_world(target_tile)
	target_pos.y = global_position.y
	
	# Updates the attacker position constantly so it hits the correct updated tile when timer reaches 0
	attacker_component.start_attacking_position(target_pos)

func _on_attack_started(target: Node3D, _attack_res: AttackResource) -> void:
	if current_mode == AllyMode.ATTACK and not is_instance_valid(target):
		var current_tile = LaneManager.world_to_tile(global_position)
		var target_tile = LaneManager.world_to_tile(attacker_component.current_target_pos)
		var dir_x = 0
		var dir_z = 0
		if abs(facing_direction.x) > abs(facing_direction.z):
			dir_x = sign(facing_direction.x)
		else:
			dir_z = sign(facing_direction.z)
			
		print("[Attack Trace] Fired! Ally Tile: ", current_tile, " | Facing: Vector2i(", dir_x, ", ", dir_z, ") | Target Tile: ", target_tile, " | World Target: ", attacker_component.current_target_pos)

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
	for s in _tint_sprites:
		if is_instance_valid(s): s.modulate = final
	for m in _tint_materials:
		if is_instance_valid(m): m.albedo_color = final

func _process_auto_mine(_delta: float) -> void:
	if not ToolManager.instance: return
	if ToolManager.instance.active_miners.has(self): return
	var tool_item = _get_item_in_slot(SLOT_TOOL)
	if not tool_item: return
	
	var tile = LaneManager.world_to_tile(global_position)
	var entity = LaneManager.get_entity_at(tile, "building")
	
	if entity is ClutterObject:
		ToolManager.instance.request_mining(self, tool_item)
		if move_component: move_component.stop_moving()
		return
		
	var world_pos = LaneManager.tile_to_world(tile)
	var ore = LaneManager.get_ore_at_world_pos(world_pos)
	
	if ore:
		ToolManager.instance.request_mining(self, tool_item)
		if move_component: move_component.stop_moving()
		return

func _get_item_in_slot(slot_idx: int) -> ItemResource:
	if not inventory_component: return null
	if inventory_component.slots.size() > slot_idx:
		var s = inventory_component.slots[slot_idx]
		if s and s.item: return s.item
	return null

func activate_mode() -> void:
	match current_mode:
		AllyMode.TOOL:
			_process_auto_mine(0.0)
		AllyMode.ATTACK:
			pass
		AllyMode.IDLE:
			pass

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
	if is_interacting:
		progress_bar.visible = true
		progress_bar.fill_color = Color(1.0, 0.85, 0.2)
		progress_bar.progress = interaction_progress / interaction_duration
		return
	if ToolManager.instance and ToolManager.instance.active_miners.has(self):
		progress_bar.visible = true
		var data = ToolManager.instance.active_miners[self]
		progress_bar.fill_color = Color(0.2, 0.9, 0.3)
		if data.max_time > 0:
			progress_bar.progress = data.time / data.max_time
	else:
		progress_bar.visible = false

func _apply_stats_from_resource() -> void:
	if not stats: return
	display_name = stats.ally_name
	
	respawns_count = stats.respawns_count
	respawns_unlimited = stats.respawns_unlimited
	respawns_cooldown = stats.respawns_cooldown
	
	if health_component:
		health_component.max_health = stats.health
		health_component.current_health = stats.health
	if move_component:
		move_component.move_speed = stats.speed
	if inventory_component:
		if self.is_in_group("player"):
			var target_size = max(10, stats.inventory_slots)
			inventory_component.set_capacity(target_size)
		else:
			inventory_component.set_capacity(stats.inventory_slots)

func _recalculate_stats(_arg = null) -> void:
	var base_hp = 10.0
	var base_spd = 5.0
	var total_def = 0.0
	
	attack_damage = 0.0
	lux_stat = 0.0
	attack_speed_mult = 0.0
	damage_mult = 0.0
	
	if stats:
		base_hp = stats.health
		base_spd = stats.speed
		total_def = stats.defense
	
	var active_weapon_attack: AttackResource = null
	active_weapon_item = null

	if inventory_component:
		for i in range(4):
			if i >= inventory_component.slots.size(): break
			var slot = inventory_component.slots[i]
			if slot and slot.item:
				var it = slot.item
				if "defense_bonus" in it: total_def += it.defense_bonus
				if "speed_bonus" in it: base_spd += it.speed_bonus
				if "health_bonus" in it: base_hp += it.health_bonus
				if "stats" in it and it.stats is Dictionary:
					if it.stats.has("defense"): total_def += it.stats["defense"]
					if it.stats.has("speed"): base_spd += it.stats["speed"]
					if it.stats.has("health"): base_hp += it.stats["health"]
					if it.stats.has("attack_damage"): attack_damage += it.stats["attack_damage"]
					if it.stats.has("lux_stat"): lux_stat += it.stats["lux_stat"]
				
				if it.modifiers:
					if it.modifiers.has("attack_speed_mult"): attack_speed_mult += it.modifiers["attack_speed_mult"]
					if it.modifiers.has("damage_mult"): damage_mult += it.modifiers["damage_mult"]
					if it.modifiers.has("attack_damage"): attack_damage += it.modifiers["attack_damage"]
					if it.modifiers.has("lux_stat"): lux_stat += it.modifiers["lux_stat"]
				
				if i == SLOT_WEAPON and it.attack_config:
					active_weapon_attack = it.attack_config
					active_weapon_item = it

	if is_instance_valid(GameManager):
		base_hp *= GameManager.get_stat_multiplier("ally_health")
		base_spd *= GameManager.get_stat_multiplier("ally_speed")
		attack_speed_mult += GameManager.get_global_stat("ally_attack_speed_mult", 0.0)
		damage_mult += GameManager.get_global_stat("ally_damage_mult", 0.0)

	if health_component:
		health_component.max_health = base_hp
		health_component.defense = total_def
		if health_component.current_health > base_hp:
			health_component.current_health = base_hp

	if move_component:
		move_component.move_speed = max(1.0, base_spd)

	if attacker_component:
		if active_weapon_attack:
			attacker_component.basic_attack = active_weapon_attack
		else:
			attacker_component.initialize(2.0, 1.0, null)
			
	if current_mode == AllyMode.ATTACK and (not attacker_component or not attacker_component.basic_attack):
		current_mode = AllyMode.IDLE
		if attacker_component: attacker_component.stop_attacking()

func _setup_selection_visuals() -> void:
	selection_container = Node3D.new()
	selection_container.name = "SelectionVisuals"
	selection_container.visible = false
	add_child(selection_container)
	var bracket_mat = StandardMaterial3D.new()
	bracket_mat.albedo_color = Color(0.0, 1.0, 0.5, 0.8)
	bracket_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bracket_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var corner_mesh = BoxMesh.new()
	corner_mesh.size = Vector3(0.1, 0.1, 0.4)
	var rotator = Node3D.new()
	rotator.name = "Rotator"
	selection_container.add_child(rotator)
	var radius = 0.7
	for i in range(4):
		var corner = Node3D.new()
		corner.rotation.y = i * (PI/2.0)
		var arm1 = MeshInstance3D.new()
		arm1.mesh = corner_mesh; arm1.material_override = bracket_mat; arm1.position = Vector3(radius, 0.1, radius)
		corner.add_child(arm1)
		var arm2 = MeshInstance3D.new()
		arm2.mesh = corner_mesh; arm2.material_override = bracket_mat; arm2.position = Vector3(radius, 0.1, radius); arm2.rotation.y = PI/2.0
		corner.add_child(arm2)
		rotator.add_child(corner)

func set_selected(selected: bool) -> void:
	selection_container.visible = selected
	if selected: _animate_visuals()
	else: if _vis_tween: _vis_tween.kill()

func _animate_visuals() -> void:
	if _vis_tween: _vis_tween.kill()
	_vis_tween = create_tween().set_loops().set_parallel(true)
	var rot = selection_container.get_node_or_null("Rotator")
	if rot:
		_vis_tween.tween_property(rot, "rotation:y", 2*PI, 4.0).as_relative()
		_vis_tween.tween_property(rot, "scale", Vector3(1.1, 1.1, 1.1), 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_vis_tween.chain().tween_property(rot, "scale", Vector3(1.0, 1.0, 1.0), 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func command_move(target_pos: Vector3) -> void:
	interaction_target = null
	is_interacting = false
	is_centering = false
	if move_component:
		move_component.move_to(target_pos)

func set_interaction(target: Node, type: String, data: Dictionary = {}) -> void:
	interaction_target = target
	interaction_type = type
	interaction_data = data
	is_interacting = false
	if target is Node3D:
		var best_pos = _find_adjacent_center(target.global_position)
		centering_target = best_pos
		is_centering = true
		var dist = global_position.distance_to(best_pos)
		if dist > 0.1:
			move_component.move_to(best_pos)
		else:
			global_position = best_pos
			_start_interaction()

func _find_adjacent_center(target_pos: Vector3) -> Vector3:
	var t_tile = LaneManager.world_to_tile(target_pos)
	var my_tile = LaneManager.world_to_tile(global_position)
	var candidates =[]
	var neighbor_offsets =[Vector2i(0,1), Vector2i(0,-1), Vector2i(1,0), Vector2i(-1,0)]
	for n in neighbor_offsets:
		var check = t_tile + n
		if LaneManager.is_valid_tile(check):
			candidates.append(check)
	if candidates.is_empty():
		return LaneManager.tile_to_world(t_tile)
	candidates.sort_custom(func(a, b):
		var pos_a = LaneManager.tile_to_world(a)
		var pos_b = LaneManager.tile_to_world(b)
		return global_position.distance_squared_to(pos_a) < global_position.distance_squared_to(pos_b)
	)
	return LaneManager.tile_to_world(candidates[0])

func _process_centering() -> void:
	var dist = Vector3(global_position.x, 0, global_position.z).distance_to(Vector3(centering_target.x, 0, centering_target.z))
	if dist < 0.1:
		move_component.stop_moving()
		global_position.x = centering_target.x
		global_position.z = centering_target.z
		is_centering = false
		_start_interaction()

func _start_interaction() -> void:
	if interaction_type == "pickup_clutter":
		is_interacting = true
		interaction_progress = 0.0
		interaction_duration = 2.0

func _process_interaction(delta: float) -> void:
	if not is_interacting: return
	if not is_instance_valid(interaction_target):
		is_interacting = false
		return
	interaction_progress += delta
	if interaction_progress >= interaction_duration:
		_complete_interaction()

func _complete_interaction() -> void:
	is_interacting = false
	if interaction_type == "pickup_clutter":
		if not is_instance_valid(interaction_target): return
		if not interaction_target is ClutterObject: return
		var drop_item = null
		var count = 1
		if interaction_target.clutter_resource:
			drop_item = interaction_target.clutter_resource.drop_item
			count = interaction_target.clutter_resource.drop_count
		if drop_item and inventory_component:
			_equip_or_add_item(drop_item, count)
		interaction_target.queue_free()
		interaction_target = null

func _equip_or_add_item(item: Resource, count: int) -> void:
	if not item is ItemResource:
		inventory_component.add_item(item, count)
		return
	var target_slot = -1
	match item.equipment_type:
		ItemResource.EquipmentType.TOOL: target_slot = SLOT_TOOL
		ItemResource.EquipmentType.WEAPON: target_slot = SLOT_WEAPON
		ItemResource.EquipmentType.ARMOR: target_slot = SLOT_ARMOR
		ItemResource.EquipmentType.ACCESSORY: target_slot = SLOT_ARTIFACT
	if target_slot != -1:
		var current = inventory_component.slots[target_slot]
		if current == null:
			inventory_component.slots[target_slot] = { "item": item, "count": 1 }
			count -= 1
			inventory_component.inventory_changed.emit()
	if count > 0:
		inventory_component.add_item(item, count)

func use_equipped_tool() -> void:
	activate_mode()

func receive_item(item: Resource, _from_node: Node3D = null, _extra_data: Dictionary = {}) -> bool:
	if not inventory_component: return false
	return inventory_component.add_item(item) == 0

func _on_died(_node) -> void:
	if respawns_unlimited or respawns_count > 0:
		if not respawns_unlimited:
			respawns_count -= 1
		
		visible = false
		collision_layer = 0
		set_process(false)
		set_physics_process(false)
		
		if current_mode != AllyMode.IDLE:
			current_mode = AllyMode.IDLE
		if attacker_component: attacker_component.stop_attacking()
		if move_component: move_component.stop_moving()
		if ToolManager.instance and ToolManager.instance.active_miners.has(self):
			ToolManager.instance.active_miners.erase(self)
		
		get_tree().create_timer(respawns_cooldown).timeout.connect(_respawn)
	else:
		queue_free()

func _respawn() -> void:
	var respawn_pos = LaneManager.get_nearby_valid_ally_spawn_pos(global_position)
	global_position = respawn_pos
	
	if move_component:
		move_component.target_position = respawn_pos
	
	# For Player specifically to cancel mouse movement tasks
	if "target_pos" in self:
		self.set("target_pos", respawn_pos)
	if "is_moving" in self:
		self.set("is_moving", false)
	
	if health_component:
		health_component.current_health = health_component.max_health
	
	visible = true
	collision_layer = 4
	set_process(true)
	set_physics_process(true)
