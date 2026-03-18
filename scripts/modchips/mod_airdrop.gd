extends ModChip

var applied: bool = false

func _on_apply() -> void:
	if not applied:
		if is_instance_valid(GameManager):
			GameManager._grant_starting_items()
		applied = true
		