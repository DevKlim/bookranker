class_name AttackerComponent
extends Node

## A component that handles attacking logic using AttackResources.

signal attack_started(target, attack_res)
signal attacked(target, damage)

@export var basic_attack: AttackResource
@export var available_attacks: Array[AttackResource] = []

var attack_timer: Timer 
var current_target: Node3D = null
var current_attack: AttackResource = null

func _ready() -> void:
	attack_timer = Timer.new()
	attack_timer.name = "AttackTimer"
	attack_timer.one_shot = true
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	add_child(attack_timer)

## Legacy initialization for backward compatibility or simple setup
func initialize(damage: float, p_attack_speed: float, element: ElementResource) -> void:
	if not basic_attack:
		basic_attack = AttackResource.new()
		basic_attack.base_damage = damage
		basic_attack.cooldown = 1.0 / max(0.1, p_attack_speed)
		basic_attack.element = element

func start_attacking(target: Node3D, specific_attack: AttackResource = null) -> void:
	if not is_instance_valid(target): return
	
	current_target = target
	current_attack = specific_attack if specific_attack else basic_attack
	
	if not current_attack: return
	
	if attack_timer.is_stopped():
		_perform_attack()

func stop_attacking() -> void:
	current_target = null
	attack_timer.stop()

func _on_attack_timer_timeout() -> void:
	if is_instance_valid(current_target):
		_perform_attack()

func _perform_attack() -> void:
	if not is_instance_valid(current_target) or not current_attack:
		stop_attacking()
		return
		
	var source = get_parent()
	var final_damage = _calculate_damage(source, current_attack)
	
	emit_signal("attack_started", current_target, current_attack)
	_spawn_visuals(source, current_target)

	# projectile handling
	if current_attack.spawn_projectile:
		_spawn_projectile(source, final_damage)
	else:
		_apply_hit(current_target, final_damage, current_attack, source)

	# Handle Chaining
	if current_attack.chain_next:
		var next = current_attack.chain_next
		var delay = current_attack.chain_delay
		get_tree().create_timer(delay).timeout.connect(func(): 
			current_attack = next
			_perform_attack()
		)
	else:
		# Reset to basic attack for next cycle if we were chaining
		if basic_attack and current_attack != basic_attack:
			current_attack = basic_attack
			
	# Cooldown
	var cd = current_attack.cooldown
	# Apply attack speed modifiers from source
	if source.has_node("ElementalComponent"):
		var spd_mult = source.get_node("ElementalComponent").get_stat_modifier("attack_speed_mult")
		cd /= max(0.1, (1.0 + spd_mult))
	
	attack_timer.start(cd)

func _calculate_damage(source: Node, atk: AttackResource) -> float:
	var dmg = atk.base_damage
	
	# Scaling
	var stat_val = 0.0
	if atk.scaling_stat != "":
		if atk.scaling_stat in source:
			stat_val = source.get(atk.scaling_stat)
		elif source.get("stats") and atk.scaling_stat in source.stats:
			stat_val = source.stats.get(atk.scaling_stat)
			
	dmg += (stat_val * atk.scaling_factor)
	
	# Global Modifiers
	if source.has_node("ElementalComponent"):
		var d_mult = source.get_node("ElementalComponent").get_stat_modifier("damage_mult")
		dmg *= (1.0 + d_mult)
		
	return dmg

func _spawn_visuals(source: Node3D, target: Node3D) -> void:
	if not current_attack.visual_scene: return
	
	var vis = current_attack.visual_scene.instantiate()
	
	# Attachment Logic
	if current_attack.attach_visual_to_source and current_attack.visual_spawn_point == 0:
		source.add_child(vis)
		vis.position = current_attack.visual_offset
	else:
		get_tree().root.add_child(vis)
		var pos = source.global_position
		match current_attack.visual_spawn_point:
			0: pos = source.global_position # Attacker
			1: pos = target.global_position # Target
			2: pos = source.global_position.lerp(target.global_position, 0.5) # Midpoint
		vis.global_position = pos + current_attack.visual_offset
	
	# Orientation: Look at target
	if current_attack.visual_spawn_point == 0:
		# If attached, we trust the parent's rotation or local transform, 
		# otherwise we look_at in world space.
		if not current_attack.attach_visual_to_source:
			vis.look_at(Vector3(target.global_position.x, vis.global_position.y, target.global_position.z), Vector3.UP)
		
	if current_attack.visual_duration > 0 and not vis.has_method("_on_finished"):
		get_tree().create_timer(current_attack.visual_duration).timeout.connect(func(): if is_instance_valid(vis): vis.queue_free())

func _spawn_projectile(source: Node, damage: float) -> void:
	if not current_attack.projectile_scene: return
	
	var proj = current_attack.projectile_scene.instantiate()
	get_tree().root.add_child(proj)
	
	var dir = (current_target.global_position - source.global_position).normalized()
	var start_pos = source.global_position + Vector3(0, 0.5, 0)
	
	var params = {
		"source": source,
		"element_units": current_attack.element_units,
		"ignore_element_cd": current_attack.ignore_element_cd
	}
	
	if proj.has_method("initialize"):
		proj.initialize(start_pos, dir, current_attack.projectile_speed, damage, -1, current_attack.element, null, current_attack.projectile_color, false, params)

func _apply_hit(target: Node, damage: float, atk: AttackResource, source: Node) -> void:
	# AoE Handling: If is_aoe is true, find all entities in target tile
	var targets_to_hit = [target]
	
	if atk.is_aoe:
		var tile = LaneManager.world_to_tile(target.global_position)
		var enemies = LaneManager.get_enemies_at(tile)
		for e in enemies:
			if e != target and is_instance_valid(e):
				targets_to_hit.append(e)
	
	for t in targets_to_hit:
		if not is_instance_valid(t): continue
		
		if atk.element:
			ElementManager.apply_element(t, atk.element, source, damage, atk.element_units, atk.ignore_element_cd)
		
		if t.has_method("take_damage"):
			t.take_damage(damage, atk.element, source)
		elif t.has_node("HealthComponent"):
			t.get_node("HealthComponent").take_damage(damage, atk.element, source)
		
		emit_signal("attacked", t, damage)
