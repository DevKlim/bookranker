extends ModChip

func get_stat_modifier(stat_name: String) -> float:
	match stat_name:
		"attack_speed_mult": return 1.0
		"process_speed_mult": return 1.0
		"power_consumption_mult": return 0.5
	return 0.0

func _process(delta: float) -> void:
	if is_instance_valid(target) and target.has_method("take_damage"):
		target.take_damage(2.0 * delta)

