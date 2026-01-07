@tool
class_name TurretBuilding
extends BaseBuilding

# Components
var target_acquirer: TargetAcquirerComponent
var shooter: ShooterComponent
var rotatable: Node3D

@export var storage_cap: int = 100
@onready var inventory: InventoryComponent = InventoryComponent.new()

func _init() -> void:
	has_output = false
	has_input = true

func _get_main_sprite() -> AnimatedSprite3D:
	return get_node_or_null("Rotatable/AnimatedSprite3D")

func _ready() -> void:
	if Engine.is_editor_hint(): return

	inventory.name = "InventoryComponent"
	inventory.max_slots = 1
	inventory.slot_capacity = storage_cap 
	add_child(inventory)

	target_acquirer = get_node_or_null("TargetAcquirerComponent")
	shooter = get_node_or_null("ShooterComponent")
	rotatable = get_node_or_null("Rotatable")
	
	if not target_acquirer:
		printerr("Turret %s missing TargetAcquirerComponent!" % name)
		
	if target_acquirer:
		target_acquirer.validation_callback = _is_valid_target
	
	super._ready() 
	
	var s = _get_main_sprite()
	if s: s.play("idle_up")
	
	if rotatable and visual_offset != Vector3.ZERO:
		rotatable.position = visual_offset

func _is_valid_target(body: Node3D) -> bool:
	if not (body is EnemyUnit): return false
	
	var my_tile = LaneManager.world_to_tile(global_position)
	var my_logical = LaneManager.get_logical_from_tile(my_tile)
	
	var enemy_tile = LaneManager.world_to_tile(body.global_position)
	var enemy_logical = LaneManager.get_logical_from_tile(enemy_tile)
	
	if my_logical == Vector2i(-1, -1) or enemy_logical == Vector2i(-1, -1):
		return false
	
	match output_direction:
		Direction.RIGHT: return (my_logical.x == enemy_logical.x) and (enemy_logical.y > my_logical.y)
		Direction.LEFT:  return (my_logical.x == enemy_logical.x) and (enemy_logical.y < my_logical.y)
		Direction.DOWN:  return (my_logical.y == enemy_logical.y) and (enemy_logical.x > my_logical.x)
		Direction.UP:    return (my_logical.y == enemy_logical.y) and (enemy_logical.x < my_logical.x)
			
	return false

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or not is_active: return
	if not target_acquirer or not shooter: return
		
	var current_target = target_acquirer.current_target
	
	if is_instance_valid(current_target) and not current_target.is_queued_for_deletion():
		# Rotate
		if is_instance_valid(rotatable):
			var target_pos = current_target.global_position
			var flat_target = Vector3(target_pos.x, rotatable.global_position.y, target_pos.z)
			if rotatable.global_position.distance_squared_to(flat_target) > 0.1:
				rotatable.look_at(flat_target, Vector3.UP)
				rotatable.rotation.x = 0
				rotatable.rotation.z = 0
		
		# Shoot
		if shooter.can_shoot():
			var ammo = inventory.get_first_item()
			if ammo:
				var shoot_dir = Vector3.ZERO
				match output_direction:
					Direction.RIGHT: shoot_dir = Vector3(1, 0, 0)
					Direction.LEFT:  shoot_dir = Vector3(-1, 0, 0)
					Direction.DOWN:  shoot_dir = Vector3(0, 0, 1)
					Direction.UP:    shoot_dir = Vector3(0, 0, -1)
				
				var t_lane = -1
				if current_target.has_method("get_lane_id"):
					t_lane = current_target.get_lane_id()

				print("Turret Firing: Dir %s | Target %s | Item %s" % [shoot_dir, current_target.name, ammo.item_name])
				shooter.shoot_in_direction(shoot_dir, t_lane, ammo)
				inventory.remove_item(ammo, 1)
			else:
				# Debug for one-shot issue: warn if target acquired but no ammo
				# Use a timer check or simple counter to avoid spamming console every frame
				if Engine.get_frames_drawn() % 60 == 0:
					print("Turret locked on %s but NO AMMO!" % current_target.name)

func receive_item(item: Resource, _from_node: Node3D = null, _extra_data: Dictionary = {}) -> bool:
	var i = item as ItemResource
	if not i: return false
	return inventory.add_item(i) == 0
