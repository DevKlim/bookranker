class_name AttackerComponent
extends Node

## A component that handles attacking a target.

@onready var attack_timer: Timer = $AttackTimer

var attack_damage: float = 10.0
var attack_element: ElementResource = null
var current_target: Node2D = null

func _ready() -> void:
	assert(attack_timer, "AttackerComponent needs a child Timer named 'AttackTimer'")
	attack_timer.timeout.connect(_on_attack_timer_timeout)

func initialize(damage: float, p_attack_speed: float, element: ElementResource) -> void:
	attack_damage = damage
	attack_element = element
	if p_attack_speed > 0:
		attack_timer.wait_time = 1.0 / p_attack_speed
	else:
		attack_timer.wait_time = 9999 # effectively disable attacking

func start_attacking(target: Node2D) -> void:
	if not is_instance_valid(target) or not target.has_node("HealthComponent"):
		printerr("AttackerComponent: Target is invalid or has no HealthComponent.")
		return
		
	current_target = target
	attack_timer.start()
	# Attack immediately on acquiring target
	_on_attack_timer_timeout()

func stop_attacking() -> void:
	current_target = null
	attack_timer.stop()

func _on_attack_timer_timeout() -> void:
	if not is_instance_valid(current_target):
		stop_attacking()
		return
	
	current_target.get_node("HealthComponent").take_damage(attack_damage)
	
	if attack_element:
		ElementManager.apply_element(current_target, attack_element)
