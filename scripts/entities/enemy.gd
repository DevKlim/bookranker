class_name EnemyUnit
extends CharacterBody2D

## The main script for a basic enemy unit. Its stats are set on initialization.

## Signal to notify the WaveManager that this enemy has been removed (died or reached core).
signal died

@onready var health_component: HealthComponent = $HealthComponent
@onready var elemental_component: ElementalComponent = $ElementalComponent
@onready var sprite: Sprite2D = $Sprite2D

var speed: float = 75.0
var lane_id: int = -1
var target_position: Vector2


func _ready() -> void:
	assert(health_component, "Enemy is missing a HealthComponent!")
	assert(elemental_component, "Enemy is missing an ElementalComponent!")
	assert(sprite, "Enemy is missing a Sprite2D!")
	
	health_component.died.connect(_on_health_depleted)
	elemental_component.status_applied.connect(_on_status_applied)
	elemental_component.status_removed.connect(_on_status_removed)


## Initializes the enemy's state. Called by WaveManager after spawning.
func initialize(enemy_resource: EnemyResource, start_pos: Vector2, end_pos: Vector2, p_lane_id: int) -> void:
	# Set stats from the resource
	self.speed = enemy_resource.speed
	health_component.set_max_health(enemy_resource.health)
	
	# Set pathing info
	global_position = start_pos
	target_position = end_pos
	lane_id = p_lane_id


func _physics_process(_delta: float) -> void:
	if global_position.distance_to(target_position) < 5.0:
		_on_reached_end()
		return

	var direction = global_position.direction_to(target_position)
	velocity = direction * speed
	move_and_slide()


## Public method for components or projectiles to deal damage to this enemy.
func take_damage(damage_amount: float) -> void:
	health_component.take_damage(damage_amount)


func get_lane_id() -> int:
	return lane_id


func _on_reached_end() -> void:
	var core = get_tree().current_scene.get_node_or_null("Core")
	if is_instance_valid(core) and core.has_node("HealthComponent"):
		core.get_node("HealthComponent").take_damage(10)
		print("Enemy reached the Core.")
	
	emit_signal("died")
	queue_free()


func _on_health_depleted(_node_that_died) -> void:
	emit_signal("died")
	queue_free()


## Provides visual feedback when a status is applied or removed.
func _on_status_applied(_status_name: String, effect_data: Dictionary) -> void:
	if effect_data.has("color"):
		sprite.self_modulate = effect_data["color"]

func _on_status_removed(_status_name: String) -> void:
	# If this was the last status, return to normal color.
	# A more complex system could blend colors or show the most recent one.
	if elemental_component.active_statuses.is_empty():
		sprite.self_modulate = Color.WHITE