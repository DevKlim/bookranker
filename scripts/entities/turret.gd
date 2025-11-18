class_name TurretBuilding
extends BaseBuilding

# Component references
@onready var target_acquirer: TargetAcquirerComponent = $TargetAcquirerComponent
@onready var shooter: ShooterComponent = $ShooterComponent
@onready var rotatable: Node2D = $Rotatable
@onready var turret_head: Sprite2D = $Rotatable/TurretHead

# `power_consumer` and `health_component` are inherited from BaseBuilding.
# `is_active` is also inherited.

# Override base implementation to point to the correct sprite node for the base.
func _get_main_sprite() -> AnimatedSprite2D:
	return get_node_or_null("Rotatable/TurretBase")

## Called when the node enters the scene tree.
func _ready() -> void:
	super._ready() # This calls BaseBuilding's ready, which sets up power, health, animated_sprite
	
	assert(target_acquirer, "Turret is missing TargetAcquirerComponent!")
	assert(shooter, "Turret is missing ShooterComponent!")
	assert(rotatable, "Turret is missing a Node2D named 'Rotatable'!")
	assert(turret_head, "Turret is missing a Sprite2D at path Rotatable/TurretHead!")

	# Connect signals from components.
	target_acquirer.target_acquired.connect(_on_target_acquired)
	
	# Initial power state visual is handled by super._ready() and _on_power_status_changed
	# but turret has a second visual part (the head) to update.
	_on_power_status_changed(false)


# `set_build_rotation` is inherited and rotates the base sprite.
# `get_sprite_frames` is inherited.
# `_on_died` is inherited.

## Called by the PowerConsumerComponent when power status changes.
func _on_power_status_changed(has_power: bool) -> void:
	super._on_power_status_changed(has_power) # Handles base color and sets is_active
	
	# A simple visual indicator for the turret head.
	if has_power:
		turret_head.modulate = Color(0.75, 0.75, 0.75, 1)
	else:
		turret_head.modulate = Color(0.25, 0.25, 0.25, 1)


## Called when the TargetAcquirerComponent finds a new target.
func _on_target_acquired(_target: Node2D) -> void:
	# This function is connected to a signal, but we don't need to do anything here
	# because the _process loop constantly checks for the current target.
	# The parameter is prefixed with an underscore to prevent an "unused parameter" warning.
	pass


## Called every frame.
func _process(_delta: float) -> void:
	# The turret only functions if it's active (has power).
	if not is_active: # is_active is inherited from BaseBuilding
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
