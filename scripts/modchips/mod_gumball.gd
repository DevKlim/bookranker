extends ModChip

var applied: bool = false

func _on_apply() -> void:
	if not applied:
		if is_instance_valid(GameManager):
			GameManager.set_global_stat("gumball_slime_stun", 1.0)
		applied = true

func _on_remove() -> void:
	if applied:
		if is_instance_valid(GameManager):
			GameManager.set_global_stat("gumball_slime_stun", 0.0)
		applied = false

