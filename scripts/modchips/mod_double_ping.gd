extends ModChip

var applied: bool = false

func _on_apply() -> void:
	if not applied:
		if is_instance_valid(GameManager):
			GameManager.set_global_stat("global_flat_damage", GameManager.get_global_stat("global_flat_damage", 0.0) + 2.0)
		applied = true

func _on_remove() -> void:
	if applied:
		if is_instance_valid(GameManager):
			GameManager.set_global_stat("global_flat_damage", GameManager.get_global_stat("global_flat_damage", 0.0) - 2.0)
		applied = false
		