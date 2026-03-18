@tool
class_name TurretBuilding
extends BaseBuilding

var attacker: AttackerComponent

# Visuals
var ammo_visual: Sprite3D

@export var storage_cap: int = 100
@export var infinite_ammo: bool = true # Default true so it fires without ammo if powered

var _is_firing: bool = false
var _current_ammo: ItemResource = null

func _init() -> void:
	has_output = false
	has_input = true

func _get_main_sprite() -> AnimatedSprite3D:
	return get_node_or_null("Rotatable/AnimatedSprite3D")

func _ready() -> void:
	if Engine.is_editor_hint(): return
	super._ready() 
	
	attacker = get_node_or_null("AttackerComponent")
	if not attacker:
		attacker = AttackerComponent.new()
		attacker.name = "AttackerComponent"
		add_child(attacker)
		
	if attacker and not attacker.attack_started.is_connected(_on_attack_started):
		attacker.attack_started.connect(_on_attack_started)
	
	var rotatable = get_node_or_null("Rotatable")
	if rotatable:
		ammo_visual = Sprite3D.new()
		ammo_visual.name = "AmmoVisual"
		ammo_visual.pixel_size = 0.015 
		ammo_visual.position = Vector3(0, 0.5, 0.0)
		ammo_visual.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		ammo_visual.visible = false
		rotatable.add_child(ammo_visual)
	
	if inventory_component:
		if not inventory_component.inventory_changed.is_connected(_update_state_check):
			inventory_component.inventory_changed.connect(_update_state_check)
		# Initialize cache immediately
		_update_state_check()

func set_build_rotation(rotation_val: Variant) -> void:
	super.set_build_rotation(rotation_val)
	if is_active and _is_firing:
		_start_firing()

func _update_state_check(_arg = null) -> void:
	_update_ammo_visual()
	
	var new_ammo = null
	if inventory_component:
		new_ammo = inventory_component.get_first_item()

	var ammo_changed = (new_ammo != _current_ammo)
	_current_ammo = new_ammo
	
	_check_firing_state(ammo_changed)

func _on_power_status_changed(has_power: bool) -> void:
	super._on_power_status_changed(has_power)
	_update_state_check()

func _update_ammo_visual() -> void:
	if not is_instance_valid(ammo_visual) or not inventory_component: return
	var item = inventory_component.get_first_item()
	if item:
		ammo_visual.texture = item.icon
		ammo_visual.visible = true
		ammo_visual.modulate = item.color
	else:
		ammo_visual.visible = false

func _check_firing_state(force_restart: bool = false) -> void:
	# Requires power (is_active) AND (infinite_ammo OR an actual loaded ammo item)
	var can_fire = is_active and (infinite_ammo or _current_ammo != null)
	if can_fire:
		if not _is_firing or force_restart:
			_start_firing()
	else:
		if _is_firing:
			_stop_firing()

func _start_firing() -> void:
	if not attacker: return
		
	var attack = attacker.basic_attack
	if not attack:
		attack = load("res://resources/attacks/turret_shoot.tres")
		
	if _current_ammo and _current_ammo.attack_config:
		attack = _current_ammo.attack_config.duplicate()
	elif attack:
		# Duplicate so we can modify it per ammo safely without altering the base resource globally
		attack = attack.duplicate()
		if _current_ammo:
			attack.base_damage = _current_ammo.damage
			attack.element = _current_ammo.element
			attack.element_units = _current_ammo.element_units
			attack.ignore_element_cd = _current_ammo.ignore_element_cooldown
			if _current_ammo.projectile_scene:
				attack.projectile_scene = _current_ammo.projectile_scene
			if _current_ammo.icon:
				attack.projectile_texture = _current_ammo.icon
			attack.projectile_color = _current_ammo.color
	else:
		# Final failsafe
		attack = AttackResource.new()
		if _current_ammo:
			attack.base_damage = _current_ammo.damage
			attack.element = _current_ammo.element
			attack.element_units = _current_ammo.element_units
			attack.ignore_element_cd = _current_ammo.ignore_element_cooldown
			if _current_ammo.projectile_scene:
				attack.projectile_scene = _current_ammo.projectile_scene
			if _current_ammo.icon:
				attack.projectile_texture = _current_ammo.icon
			attack.projectile_color = _current_ammo.color
		attack.spawn_projectile = true
		attack.cooldown = 1.0 # default attack speed
		attack.projectile_speed = 200.0
	
	var shoot_dir = Vector3.FORWARD # Default -Z
	match output_direction:
		Direction.DOWN:  shoot_dir = Vector3(0, 0, 1)  # +Z
		Direction.LEFT:  shoot_dir = Vector3(-1, 0, 0) # -X
		Direction.UP:    shoot_dir = Vector3(0, 0, -1) # -Z
		Direction.RIGHT: shoot_dir = Vector3(1, 0, 0)  # +X

	attacker.start_attacking_direction(shoot_dir, attack)
	_is_firing = true

func _stop_firing() -> void:
	if attacker: attacker.stop_attacking()
	_is_firing = false

func _on_attack_started(_target, _attack_res) -> void:
	var s = _get_main_sprite()
	if s and s.sprite_frames and s.sprite_frames.has_animation("shoot_up"):
		s.play("shoot_up")
		get_tree().create_timer(0.2).timeout.connect(func(): if s and s.animation == "shoot_up": s.play("idle_up"))

	# Consume Ammo
	if not infinite_ammo and inventory_component and _current_ammo:
		inventory_component.remove_item(_current_ammo, 1)

func receive_item(item: Resource, _from_node: Node3D = null, _extra_data: Dictionary = {}) -> bool:
	var i = item as ItemResource
	if not i: return false
	if not inventory_component: return false
	# Inventory signal handles state update
	return inventory_component.add_item(i) == 0
