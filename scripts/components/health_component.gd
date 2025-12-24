class_name HealthComponent
extends Node

## A component for managing health, armor, and regen.

signal health_changed(current_health, max_health)
signal died(node)

@export var max_health: float = 100.0

# Stats modified by external systems
var armor: float = 0.0
var thorns: float = 0.0
var regen_rate: float = 0.0

var _current_health: float

var current_health: float:
	get: return _current_health
	set(value):
		var new_health = clamp(value, 0, max_health)
		if _current_health == new_health: return
		_current_health = new_health
		emit_signal("health_changed", _current_health, max_health)
		if _current_health == 0: emit_signal("died", get_parent())

func _ready() -> void:
	self.current_health = max_health

func _process(delta: float) -> void:
	if regen_rate > 0 and _current_health < max_health and _current_health > 0:
		heal(regen_rate * delta)

func take_damage(amount: float) -> void:
	var effective_damage = max(1.0, amount - armor)
	self.current_health -= effective_damage
	
	# Thorns logic would go here if we tracked attacker reference

func heal(amount: float) -> void:
	self.current_health += amount

func set_max_health(new_max: float) -> void:
	max_health = new_max
	self.current_health = max_health
