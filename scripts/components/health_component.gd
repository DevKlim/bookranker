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

# Elemental resistances (0.0 = 0%, 1.0 = 100% reduction)
var resistances: Dictionary = {}

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

func take_damage(amount: float, element: ElementResource = null) -> void:
	var multiplier = 1.0
	
	# Check elemental resistance
	if element and resistances.has(element.element_name.to_lower()):
		multiplier -= resistances[element.element_name.to_lower()]
	
	# Clamp multiplier (allow negative for healing elements? No, standard 0 min)
	multiplier = max(0.0, multiplier)
	
	# Calculate damage after defense (Armor acts as flat reduction here)
	# effective = (Base * Multiplier) - Armor
	var damage_after_res = amount * multiplier
	var effective_damage = max(1.0, damage_after_res - armor)
	
	self.current_health -= effective_damage
	
	# Thorns logic would go here if we tracked attacker reference

func heal(amount: float) -> void:
	self.current_health += amount

func set_max_health(new_max: float) -> void:
	max_health = new_max
	self.current_health = max_health
