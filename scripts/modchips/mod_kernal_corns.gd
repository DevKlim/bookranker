extends ModChip

func get_stat_modifier(stat_name: String) -> float:
	if stat_name == "max_energy_flat":
		return 120.0
	return 0.0

func _on_apply() -> void:
	if is_instance_valid(target) and target.get("health_component"):
		target.health_component.current_energy += 120.0
		