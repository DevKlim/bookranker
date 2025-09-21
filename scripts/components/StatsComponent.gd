extends Node
class_name StatsComponent

signal health_changed(current_health, max_health)
signal mana_changed(current_mana, max_mana)
signal died

@export_group("Health")
@export var max_health: float = 100.0
var health: float:
	set(value):
		health = clamp(value, 0, max_health)
		emit_signal("health_changed", health, max_health)
		if health <= 0:
			emit_signal("died")

@export_group("Mana")
@export var max_mana: float = 100.0
var mana: float:
	set(value):
		mana = clamp(value, 0, max_mana)
		emit_signal("mana_changed", mana, max_mana)

func _ready():
	health = max_health
	mana = max_mana

func take_damage(amount: float):
	health -= amount

func use_mana(amount: float):
	mana -= amount

func use_health(amount: float):
	health -= amount

func reset():
	health = max_health
	mana = max_mana