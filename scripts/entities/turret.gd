@tool
class_name TurretBuilding
extends BaseBuilding

var target_acquirer: TargetAcquirerComponent
var shooter: ShooterComponent

# Visuals
var ammo_visual: Sprite3D

@export var storage_cap: int = 100
@export var infinite_ammo: bool = false 

# Cache ammo availability to avoid iterating inventory every frame
var _cached_has_ammo: bool = false

@export_group("Targeting Zone")
@export var range_depth: int = 20
@export var range_width: float = 0.8 

func _init() -> void:
	has_output = false
	has_input = true

func _get_main_sprite() -> AnimatedSprite3D:
	return get_node_or_null("Rotatable/AnimatedSprite3D")

func _ready() -> void:
	if Engine.is_editor_hint(): return
	super._ready() 
	
	target_acquirer = get_node_or_null("TargetAcquirerComponent")
	shooter = get_node_or_null("ShooterComponent")
	
	var rotatable = get_node_or_null("Rotatable")
	if rotatable:
		ammo_visual = Sprite3D.new()
		ammo_visual.name = "AmmoVisual"
		ammo_visual.pixel_size = 0.015 
		ammo_visual.position = Vector3(0, 0.5, 0.0)
		ammo_visual.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		ammo_visual.visible = false
		rotatable.add_child(ammo_visual)
	
	if target_acquirer:
		call_deferred("_setup_targeting")
	
	if inventory_component:
		if not inventory_component.inventory_changed.is_connected(_update_state_check):
			inventory_component.inventory_changed.connect(_update_state_check)
		# Initialize cache immediately
		_update_state_check()

func set_build_rotation(rotation_val: Variant) -> void:
	super.set_build_rotation(rotation_val)
	if target_acquirer:
		call_deferred("_setup_targeting")

func _setup_targeting() -> void:
	if not target_acquirer: return
	target_acquirer.setup_custom_shape(Vector3(0, 0, range_depth * LaneManager.GRID_SCALE), Vector3.ZERO)

func _update_state_check(_arg = null) -> void:
	_update_ammo_visual()
	
	# Optimized: Cache the ammo state
	if infinite_ammo:
		_cached_has_ammo = true
	else:
		_cached_has_ammo = (inventory_component != null and inventory_component.has_item())
	
	# Disable targeting if we can't shoot, saving performance
	if target_acquirer:
		target_acquirer.is_active = is_active and _cached_has_ammo

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

func _process(_delta: float) -> void:
	if Engine.is_editor_hint(): return
	if not is_active: return
	
	# Stop firing logic: use cached state
	if not _cached_has_ammo: return
	
	if not target_acquirer or not shooter: return
		
	var target = target_acquirer.current_target
	if is_instance_valid(target):
		if shooter.can_shoot():
			_perform_shot(target)

func _perform_shot(_target: Node3D) -> void:
	var ammo: ItemResource = null
	if inventory_component:
		ammo = inventory_component.get_first_item()
	
	if ammo or infinite_ammo:
		var shoot_dir = Vector3.FORWARD # Default -Z
		match output_direction:
			Direction.DOWN:  shoot_dir = Vector3(0, 0, 1)  # +Z
			Direction.LEFT:  shoot_dir = Vector3(-1, 0, 0) # -X
			Direction.UP:    shoot_dir = Vector3(0, 0, -1) # -Z
			Direction.RIGHT: shoot_dir = Vector3(1, 0, 0)  # +X

		var my_lane = LaneManager.world_to_tile(global_position).y
		
		var start_pos = global_position + Vector3(0, 0.5, 0)
		if has_node("ProjectileOrigin"):
			start_pos = get_node("ProjectileOrigin").global_position
		elif has_node("Rotatable/ProjectileOrigin"):
			start_pos = get_node("Rotatable/ProjectileOrigin").global_position
		
		if shooter.shoot_in_direction(shoot_dir, my_lane, ammo, start_pos):
			var s = _get_main_sprite()
			if s and s.sprite_frames.has_animation("shoot_up"):
				s.play("shoot_up")
				get_tree().create_timer(0.2).timeout.connect(func(): if s and s.animation == "shoot_up": s.play("idle_up"))

			# Consume Ammo
			if ammo and not infinite_ammo:
				inventory_component.remove_item(ammo, 1)

func receive_item(item: Resource, _from_node: Node3D = null, _extra_data: Dictionary = {}) -> bool:
	var i = item as ItemResource
	if not i: return false
	if not inventory_component: return false
	# Inventory signal handles state update
	return inventory_component.add_item(i) == 0
