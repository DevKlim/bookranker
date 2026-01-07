class_name AttackerComponent
extends Node

## A component that handles attacking a target.

# Removed @onready to allow dynamic creation
var attack_timer: Timer 

var attack_damage: float = 10.0
var attack_element: ElementResource = null
var current_target: Node3D = null

func _ready() -> void:
	# Robust Timer Initialization
	attack_timer = get_node_or_null("AttackTimer")
	if not attack_timer:
		attack_timer = Timer.new()
		attack_timer.name = "AttackTimer"
		add_child(attack_timer)
	
	if not attack_timer.timeout.is_connected(_on_attack_timer_timeout):
		attack_timer.timeout.connect(_on_attack_timer_timeout)

func initialize(damage: float, p_attack_speed: float, element: ElementResource) -> void:
	attack_damage = damage
	attack_element = element
	
	# Ensure timer exists if called before _ready (unlikely but safe)
	if not attack_timer:
		attack_timer = get_node_or_null("AttackTimer")
		if not attack_timer: return 

	if p_attack_speed > 0:
		attack_timer.wait_time = 1.0 / p_attack_speed
	else:
		attack_timer.wait_time = 9999 # effectively disable attacking

func start_attacking(target: Node3D) -> void:
	if not is_instance_valid(target) or not target.has_node("HealthComponent"):
		printerr("AttackerComponent: Target is invalid or has no HealthComponent.")
		return
		
	current_target = target
	attack_timer.start()
	# Attack immediately on acquiring target
	_on_attack_timer_timeout()

func stop_attacking() -> void:
	current_target = null
	if is_instance_valid(attack_timer):
		attack_timer.stop()

func _on_attack_timer_timeout() -> void:
	if not is_instance_valid(current_target):
		stop_attacking()
		return
	
	if current_target.has_method("take_damage"):
		current_target.take_damage(attack_damage)
	elif current_target.has_node("HealthComponent"):
		current_target.get_node("HealthComponent").take_damage(attack_damage)
	
	if attack_element:
		ElementManager.apply_element(current_target, attack_element)
