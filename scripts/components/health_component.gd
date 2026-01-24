class_name HealthComponent
extends Node

## Handles Health and Energy. Energy depletion causes Stagger.
## Delegates reaction side-effects (Conduct, Ripple) to ElementManager.

signal died(node)
signal health_changed(new_amount, max_amount)
signal energy_changed(new_amount, max_amount)
signal staggered(duration)
signal recovered

@export var max_health: float = 100.0
@export var max_energy: float = 50.0 

var current_health: float
var current_energy: float
var defense: float = 0.0
## Magical Defense acts as a multiplier for Elemental Application Cooldowns.
var magical_defense: float = 0.0
var purity: float = 0.0

var _stagger_timer: Timer
# Optimization: Cache the sibling component to avoid get_node calls on every hit
var _elemental_component: ElementalComponent

func _ready() -> void:
	current_health = max_health
	current_energy = max_energy
	
	# Attempt to cache sibling immediately
	_elemental_component = get_parent().get_node_or_null("ElementalComponent")
	
	_stagger_timer = Timer.new()
	_stagger_timer.one_shot = true
	_stagger_timer.name = "StaggerTimer"
	_stagger_timer.timeout.connect(_on_stagger_end)
	add_child(_stagger_timer)

## Standard Damage: Triggers reactions/Conduct checks
func take_damage(amount: float, _element: Resource = null, source: Node = null) -> float:
	var damage_taken = _calculate_mitigation(amount)
	_apply_damage(damage_taken)
	
	# Trigger generic on-damage logic (Conduct, Ripple, etc.)
	if damage_taken > 0:
		ElementManager.on_damage_dealt(get_parent(), damage_taken, source)
		
	return damage_taken

## Special Damage: Used by Conduct/Reaction effects to prevent infinite loops.
func take_damage_no_conduct(amount: float, _source: Node = null) -> float:
	var damage_taken = _calculate_mitigation(amount)
	_apply_damage(damage_taken)
	return damage_taken

func _calculate_mitigation(amount: float) -> float:
	# Optimization: No rounding, precise float math. 
	# Min damage 0.0 instead of 1.0 to allow full immunity if stats allow.
	var damage_taken = max(0.0, amount - defense)
	
	if _elemental_component:
		var mult = _elemental_component.get_stat_modifier("incoming_damage_mult")
		damage_taken *= (1.0 + mult)
		
		var defense_taken_mult = _elemental_component.get_stat_modifier("damage_taken_mult")
		damage_taken *= (1.0 + defense_taken_mult)
		
	return damage_taken

func _apply_damage(val: float) -> void:
	current_health -= val
	emit_signal("health_changed", current_health, max_health)
	
	if current_health <= 0:
		emit_signal("died", get_parent())

func take_energy_damage(amount: float) -> void:
	current_energy -= amount
	emit_signal("energy_changed", current_energy, max_energy)
	
	if current_energy <= 0 and _stagger_timer.is_stopped():
		current_energy = 0
		stagger(3.0)

func stagger(base_duration: float) -> void:
	var effective_duration = base_duration * (1.0 - purity)
	if effective_duration < 0.1: effective_duration = 0.1
	
	emit_signal("staggered", effective_duration)
	_stagger_timer.start(effective_duration)

func _on_stagger_end() -> void:
	current_energy = max_energy
	emit_signal("energy_changed", current_energy, max_energy)
	emit_signal("recovered")
