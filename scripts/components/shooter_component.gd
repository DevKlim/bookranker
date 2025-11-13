class_name ShooterComponent
extends Node

## A component that handles the logic for shooting projectiles.


## The scene for the projectile to be spawned. Must be set in the editor.
@export var projectile_scene: PackedScene
## The speed of the projectile in pixels per second.
@export var projectile_speed: float = 600.0
## The damage each projectile deals.
@export var projectile_damage: float = 10.0
## The element this component's projectiles will apply.
@export var element: ElementResource
## The time delay between shots, in seconds.
@export var fire_rate: float = 1.0


# A reference to a child Marker2D node that indicates where projectiles should spawn.
@onready var fire_point: Marker2D = $FirePoint

# A timer to control the rate of fire.
@onready var fire_rate_timer: Timer = $FireRateTimer

var _can_shoot: bool = true


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	assert(projectile_scene, "ShooterComponent: projectile_scene is not set!")
	assert(fire_point, "ShooterComponent requires a child Marker2D named 'FirePoint'.")
	assert(fire_rate_timer, "ShooterComponent requires a child Timer named 'FireRateTimer'.")

	# Set up the fire rate timer.
	fire_rate_timer.wait_time = fire_rate
	fire_rate_timer.one_shot = true
	fire_rate_timer.timeout.connect(_on_fire_rate_timer_timeout)


## Attempts to fire a projectile at the given target in a specific lane.
func shoot_at(target: Node2D, target_lane_id: int) -> void:
	if not _can_shoot or not is_instance_valid(target):
		return

	# Instantiate the projectile.
	var projectile_instance = projectile_scene.instantiate()
	
	# Add the projectile to the scene tree under a dedicated container for organization.
	var main_scene = get_tree().current_scene
	var projectile_container = main_scene.get_node("Projectiles")
	projectile_container.add_child(projectile_instance)
	
	# Calculate the direction from the fire point to the target.
	var direction = fire_point.global_position.direction_to(target.global_position)
	
	# Initialize the projectile's properties, including its lane and element.
	projectile_instance.initialize(fire_point.global_position, direction, projectile_speed, projectile_damage, target_lane_id, element)
	
	# Start the cooldown timer.
	_can_shoot = false
	fire_rate_timer.start()


## Called when the fire rate timer finishes, allowing the component to shoot again.
func _on_fire_rate_timer_timeout() -> void:
	_can_shoot = true