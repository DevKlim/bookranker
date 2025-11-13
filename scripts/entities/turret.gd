class_name TurretBuilding
extends StaticBody2D

## The main script for a basic Turret. It connects its components together.


# Component references
@onready var power_consumer: PowerConsumerComponent = $PowerConsumerComponent
@onready var target_acquirer: TargetAcquirerComponent = $TargetAcquirerComponent
@onready var shooter: ShooterComponent = $ShooterComponent
@onready var turret_head: Sprite2D = $TurretHead


var _is_active: bool = false


## Called when the node enters the scene tree.
func _ready() -> void:
	assert(power_consumer, "Turret is missing PowerConsumerComponent!")
	assert(target_acquirer, "Turret is missing TargetAcquirerComponent!")
	assert(shooter, "Turret is missing ShooterComponent!")
	assert(turret_head, "Turret is missing a Sprite2D named TurretHead!")

	# Register with the power grid.
	PowerGridManager.register_consumer(power_consumer)

	# Connect signals from components.
	target_acquirer.target_acquired.connect(_on_target_acquired)


## Called by the PowerConsumerComponent when power status changes.
func _on_power_status_changed(has_power: bool) -> void:
	_is_active = has_power
	
	# A simple visual indicator for power status.
	if has_power:
		turret_head.modulate = Color(0.75, 0.75, 0.75, 1)
		print("Turret powered ON.")
	else:
		turret_head.modulate = Color(0.25, 0.25, 0.25, 1)
		print("Turret powered OFF.")


## Called when the TargetAcquirerComponent finds a new target.
func _on_target_acquired(_target: Node2D) -> void:
	# This function is connected to a signal, but we don't need to do anything here
	# because the _process loop constantly checks for the current target.
	# The parameter is prefixed with an underscore to prevent an "unused parameter" warning.
	pass


## Called every frame.
func _process(_delta: float) -> void:
	# The turret only functions if it's active (has power).
	if not _is_active:
		return

	var current_target = target_acquirer.current_target
	if is_instance_valid(current_target):
		# Point the turret head at the target.
		turret_head.look_at(current_target.global_position)
		
		# Check if the target is an enemy with a lane_id before shooting.
		if current_target.has_method("get_lane_id"):
			var target_lane_id = current_target.get_lane_id()
			# Tell the shooter component to fire at the target, providing its lane.
			# The shooter component's internal fire rate will handle the timing.
			shooter.shoot_at(current_target, target_lane_id)
