extends ModChip

var applied: bool = false

func _on_apply() -> void:
	if not applied:
		LaneManager.add_lane()
		applied = true
		