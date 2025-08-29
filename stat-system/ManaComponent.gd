# ManaComponent.gd
extends Node

signal mana_changed(current_mana, max_mana)

@export var max_mana: float = 100.0
var current_mana: float

func _ready():
	current_mana = max_mana

func spend_mana(mana_cost: float) -> bool:
	if current_mana >= mana_cost:
		current_mana -= mana_cost
		emit_signal("mana_changed", current_mana, max_mana)
		return true
	return false

func get_mana_percentage() -> float:
	if max_mana > 0:
		return current_mana / max_mana
	return 0.0
