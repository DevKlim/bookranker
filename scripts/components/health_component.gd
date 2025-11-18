class_name HealthComponent
extends Node

## A component for managing the health of an entity. It handles taking damage,
## healing, and dying.


## Signal emitted when health changes. Passes the current health and max health.
signal health_changed(current_health, max_health)
## Signal emitted when health reaches zero. Passes the node that died.
signal died(node)


## The maximum health of the entity.
@export var max_health: float = 100.0


## Private variable to store the current health.
var _current_health: float

## Public property for current_health with a custom setter.
var current_health: float:
	get:
		return _current_health
	set(value):
		# Clamp the new health value between 0 and max_health.
		var new_health = clamp(value, 0, max_health)
		# Only proceed if the health value has actually changed.
		if _current_health == new_health:
			return

		_current_health = new_health
		emit_signal("health_changed", _current_health, max_health)
		
		# If health drops to 0, emit the 'died' signal.
		if _current_health == 0:
			emit_signal("died", get_parent())


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Initialize current health to the maximum.
	self.current_health = max_health


## Applies damage to the component.
func take_damage(damage_amount: float) -> void:
	self.current_health -= damage_amount


## Heals the component.
func heal(heal_amount: float) -> void:
	self.current_health += heal_amount


## Sets the maximum health and fully heals the entity.
func set_max_health(new_max: float) -> void:
	max_health = new_max
	self.current_health = max_health