class_name ShooterComponent
extends Node

## A component that handles the logic for shooting projectiles.

@export var projectile_scene: PackedScene
@export var projectile_speed: float = 600.0
# Base stats if no item is provided (fallback)
@export var base_damage: float = 10.0
@export var base_element: ElementResource
@export var fire_rate: float = 1.0
@export var fire_point_path: NodePath

@onready var fire_point: Marker2D
@onready var fire_rate_timer: Timer = $FireRateTimer

var _can_shoot: bool = true

func _ready() -> void:
	assert(projectile_scene, "ShooterComponent: projectile_scene is not set!")
	assert(fire_point_path, "ShooterComponent: fire_point_path is not set!")
	fire_point = get_node_or_null(fire_point_path)
	assert(fire_point, "ShooterComponent: could not find FirePoint node at path: " + str(fire_point_path))
	assert(fire_rate_timer, "ShooterComponent requires a child Timer named 'FireRateTimer'.")

	fire_rate_timer.wait_time = fire_rate
	fire_rate_timer.one_shot = true
	fire_rate_timer.timeout.connect(_on_fire_rate_timer_timeout)

func can_shoot() -> bool:
	return _can_shoot

## Attempts to fire a projectile using the provided item as ammo properties.
func shoot_at(target: Node2D, target_lane_id: int, ammo_item: ItemResource = null) -> void:
	if not _can_shoot or not is_instance_valid(target):
		return

	var damage = base_damage
	var element = base_element
	var texture = null
	var color = Color.WHITE

	if ammo_item:
		damage = ammo_item.damage
		element = ammo_item.element
		texture = ammo_item.icon
		color = ammo_item.color

	var projectile_instance = projectile_scene.instantiate()
	var main_scene = get_tree().current_scene
	var projectile_container = main_scene.get_node("Projectiles")
	projectile_container.add_child(projectile_instance)
	
	var direction = fire_point.global_position.direction_to(target.global_position)
	
	projectile_instance.initialize(
		fire_point.global_position, 
		direction, 
		projectile_speed, 
		damage, 
		target_lane_id, 
		element,
		texture,
		color
	)
	
	_can_shoot = false
	fire_rate_timer.start()

func _on_fire_rate_timer_timeout() -> void:
	_can_shoot = true