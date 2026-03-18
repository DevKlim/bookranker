extends ModChip

func get_stat_modifier(stat_name: String) -> float:
	# Returns 10 energy to shield reserves
	if stat_name == "max_energy_flat":
		return 10.0
	return 0.0

func _on_apply() -> void:
	if is_instance_valid(target) and target.get("health_component"):
		target.health_component.current_energy += 10.0
		