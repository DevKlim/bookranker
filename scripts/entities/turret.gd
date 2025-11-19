class_name TurretBuilding
extends BaseBuilding

# Component references
@onready var target_acquirer: TargetAcquirerComponent = $TargetAcquirerComponent
@onready var shooter: ShooterComponent = $ShooterComponent
@onready var rotatable: Node2D = $Rotatable
@onready var turret_head: Sprite2D = $Rotatable/TurretHead

# Add Inventory
@onready var inventory: InventoryComponent = InventoryComponent.new()

func _get_main_sprite() -> AnimatedSprite2D:
	return get_node_or_null("Rotatable/TurretBase")

func _ready() -> void:
	inventory.name = "InventoryComponent"
	inventory.max_slots = 1
	inventory.slot_capacity = 20 # Buffer size
	add_child(inventory)

	super._ready() 
	
	assert(target_acquirer, "Turret is missing TargetAcquirerComponent!")
	assert(shooter, "Turret is missing ShooterComponent!")
	assert(rotatable, "Turret is missing a Node2D named 'Rotatable'!")
	assert(turret_head, "Turret is missing a Sprite2D at path Rotatable/TurretHead!")

	target_acquirer.target_acquired.connect(_on_target_acquired)
	_on_power_status_changed(false)

func _on_power_status_changed(has_power: bool) -> void:
	super._on_power_status_changed(has_power)
	if has_power:
		turret_head.modulate = Color(0.75, 0.75, 0.75, 1)
	else:
		turret_head.modulate = Color(0.25, 0.25, 0.25, 1)

func _on_target_acquired(_target: Node2D) -> void:
	pass

func _process(_delta: float) -> void:
	if not is_active:
		return

	var current_target = target_acquirer.current_target
	if is_instance_valid(current_target):
		turret_head.look_at(current_target.global_position)
		
		# Check if we have ammo
		var ammo = inventory.get_first_item()
		if ammo:
			if current_target.has_method("get_lane_id"):
				var target_lane_id = current_target.get_lane_id()
				
				# Try to shoot using the component
				if shooter.can_shoot():
					shooter.shoot_at(current_target, target_lane_id, ammo)
					inventory.remove_item(ammo, 1)

# Turret accepts items as ammo
func receive_item(item: ItemResource) -> bool:
	return inventory.add_item(item) == 0
