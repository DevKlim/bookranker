class_name ModChip
extends Node

var target: Node

func _enter_tree() -> void:
	target = get_parent().target
	_on_apply()

func _exit_tree() -> void:
	_on_remove()

## Called when the mod is successfully applied to a valid target.
func _on_apply() -> void:
	pass

## Called when the mod is removed from the target.
func _on_remove() -> void:
	pass

## Allows the mod to return a multiplier or flat value for a specific stat.
func get_stat_modifier(_stat_name: String) -> float:
	return 0.0
