# HealthComponent.gd
extends Node

signal health_changed(current_health, max_health)
signal died

@export var max_health: float = 100.0
# This variable will be synced by the MultiplayerSynchronizer.
# The authority is the player who owns this component.
@export var current_health: float:
	set(value):
		var old_value = current_health
		current_health = value
		# Only emit the signal if the value actually changed.
		if old_value != current_health:
			emit_signal("health_changed", current_health, max_health)

func _ready():
	current_health = max_health

func take_damage(report: DamageReport):
	# No more server checks. Just apply the damage.
	# The authority check in Player.gd's RPC protects this function.
	var new_health = max(0, current_health - report.damage_amount)
	current_health = new_health # This will trigger the setter and the signal
	
	if new_health == 0:
		emit_signal("died")

func get_health_percentage() -> float:
	if max_health > 0:
		return current_health / max_health
	return 0.0
