extends Node
class_name AttackerComponent

signal attack_started(target, attack_res)
signal cast_started(target, attack_res)
signal attacked(target, damage)

@export var basic_attack: AttackResource
@export var available_attacks: Array[AttackResource] =[]
@export var show_debug_hitboxes: bool = true

var attack_timer: Timer 
var cast_timer: Timer
var is_casting: bool = false

var current_target: Node3D = null
var current_target_pos: Vector3 = Vector3.INF
var current_target_dir: Vector3 = Vector3.ZERO
var current_attack: AttackResource = null
var base_active_attack: AttackResource = null

var processor: Node

func _ready() -> void:
	attack_timer = Timer.new()
	attack_timer.name = "AttackTimer"
	attack_timer.one_shot = true
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	add_child(attack_timer)
	
	cast_timer = Timer.new()
	cast_timer.name = "CastTimer"
	cast_timer.one_shot = true
	cast_timer.timeout.connect(_on_cast_timer_timeout)
	add_child(cast_timer)
	
	processor = load("res://scripts/components/attack_processor.gd").new()
	processor.name = "AttackProcessor"
	add_child(processor)
	processor.attacked.connect(func(t, d): emit_signal("attacked", t, d))

func initialize(damage: float, p_process_speed: float, element: ElementResource) -> void:
	if not basic_attack:
		basic_attack = AttackResource.new()
		basic_attack.base_damage = damage
		basic_attack.cooldown = 1.0 / max(0.1, p_process_speed)
		basic_attack.element = element

func start_attacking(target: Node3D, specific_attack: AttackResource = null) -> void:
	if not is_instance_valid(target): return
	current_target = target
	current_target_pos = target.global_position
	current_target_dir = Vector3.ZERO
	base_active_attack = specific_attack if specific_attack else basic_attack
	current_attack = base_active_attack
	if not current_attack: return
	if attack_timer.is_stopped() and not is_casting: _trigger_attack_sequence()

func start_attacking_position(target_pos: Vector3, specific_attack: AttackResource = null) -> void:
	current_target = null
	current_target_pos = target_pos
	current_target_dir = Vector3.ZERO
	base_active_attack = specific_attack if specific_attack else basic_attack
	current_attack = base_active_attack
	if not current_attack: return
	if attack_timer.is_stopped() and not is_casting: _trigger_attack_sequence()

func start_attacking_direction(dir: Vector3, specific_attack: AttackResource = null) -> void:
	current_target = null
	current_target_pos = Vector3.INF
	current_target_dir = dir
	base_active_attack = specific_attack if specific_attack else basic_attack
	current_attack = base_active_attack
	if not current_attack: return
	if attack_timer.is_stopped() and not is_casting: _trigger_attack_sequence()

func stop_attacking() -> void:
	current_target = null
	current_target_pos = Vector3.INF
	current_target_dir = Vector3.ZERO
	attack_timer.stop()
	cast_timer.stop()
	is_casting = false

func _trigger_attack_sequence() -> void:
	if current_attack and current_attack.cast_time > 0.0:
		_start_cast()
	else:
		_perform_attack()

func _on_attack_timer_timeout() -> void:
	var target_valid = is_instance_valid(current_target)
	if target_valid or current_target_pos != Vector3.INF or current_target_dir != Vector3.ZERO:
		if target_valid: current_target_pos = current_target.global_position
		_trigger_attack_sequence()
	else:
		stop_attacking()

func _start_cast() -> void:
	var source = get_parent()
	# Check artifact authorization before committing to cast
	if "active_weapon_item" in source and source.active_weapon_item:
		var artifact = source.active_weapon_item.get_artifact_instance()
		if artifact and artifact.has_method("can_attack"):
			if not artifact.can_attack(source, current_attack):
                # Don't proceed with cast if unauthorized (e.g. out of ammo)
				stop_attacking()
				return

	is_casting = true
	var safe_target = current_target if is_instance_valid(current_target) else null
	emit_signal("cast_started", safe_target, current_attack)
	
	if current_attack.on_cast_scene:
		var vis = current_attack.on_cast_scene.instantiate()
		if is_instance_valid(source):
			source.add_child(vis)
			if "visual_offset" in current_attack: vis.position = current_attack.visual_offset
			if vis is GPUParticles3D:
				get_tree().create_timer(current_attack.cast_time + vis.lifetime + 0.1).timeout.connect(func(): if is_instance_valid(vis): vis.queue_free())
			else:
				get_tree().create_timer(current_attack.cast_time + 1.0).timeout.connect(func(): if is_instance_valid(vis): vis.queue_free())

	cast_timer.start(current_attack.cast_time)

func _on_cast_timer_timeout() -> void:
	is_casting = false
	_perform_attack()

func _perform_attack() -> void:
	if not current_attack:
		stop_attacking(); return
		
	var target_valid = is_instance_valid(current_target)
	if not target_valid and current_target_pos == Vector3.INF and current_target_dir == Vector3.ZERO:
		stop_attacking(); return
		
	var source = get_parent()
	var ammo_item: Resource = null
	
	# Early check for artifact/weapon approval (blocks VFX/CD if out of ammo)
	if "active_weapon_item" in source and source.active_weapon_item:
		var artifact = source.active_weapon_item.get_artifact_instance()
		if artifact and artifact.has_method("can_attack"):
			if not artifact.can_attack(source, current_attack):
				stop_attacking()
				return
	
	if source is Node3D and source.has_node("InventoryComponent"):
		var inv = source.get_node("InventoryComponent")
		var is_ammo_user = ("infinite_ammo" in source) or (inv.can_receive and not inv.can_output)
		if is_ammo_user and inv.has_item():
			var first_item = inv.get_first_item()
			if first_item:
				ammo_item = first_item
				var infinite = source.get("infinite_ammo") if "infinite_ammo" in source else false
				if not infinite: inv.remove_item(ammo_item, 1)
			
	var base_attack = current_attack
	if ammo_item and ammo_item.get("attack_config"):
		current_attack = ammo_item.get("attack_config")

	var final_damage = processor.calculate_damage(source, current_attack)
	var safe_target = current_target if target_valid else null
	
	emit_signal("attack_started", safe_target, current_attack)
	processor.spawn_visuals(source, safe_target, current_target_pos, current_attack)

	if current_attack.spawn_projectile or ammo_item != null:
		var proj_damage = final_damage
		if ammo_item and "damage" in ammo_item and float(ammo_item.get("damage")) > 0:
			proj_damage += float(ammo_item.get("damage"))
		processor.spawn_projectile(source, safe_target, current_target_pos, current_target_dir, proj_damage, current_attack, ammo_item)
	else:
		processor.apply_hit(source, safe_target, current_target_pos, final_damage, current_attack, show_debug_hitboxes)

	if base_attack != current_attack and not base_attack.spawn_projectile:
		var base_dmg = processor.calculate_damage(source, base_attack)
		processor.apply_hit(source, safe_target, current_target_pos, base_dmg, base_attack, show_debug_hitboxes)

	if current_attack.chain_next:
		var next = current_attack.chain_next
		var delay = current_attack.chain_delay
		get_tree().create_timer(delay).timeout.connect(func(): 
			current_attack = next
			_perform_attack()
		)
	else:
		current_attack = base_active_attack
			
	var cd = current_attack.cooldown
	var spd_mult = source.get_stat("process_speed", 1.0) if source.has_method("get_stat") else 1.0
			
	if "active_weapon_item" in source and source.active_weapon_item:
		var artifact = source.active_weapon_item.get_artifact_instance()
		if artifact and artifact.has_method("modify_cooldown"):
			cd = artifact.modify_cooldown(cd, source, current_attack)
	
	cd /= max(0.1, spd_mult)
	attack_timer.start(cd)
