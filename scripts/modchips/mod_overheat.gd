extends ModChip

func get_stat_modifier(stat_name: String) -> float:
	if stat_name == "damage_mult": 
		return 0.02
	return 0.0

func _process(delta: float) -> void:
	if is_instance_valid(target) and target.has_method("take_damage"):
		target.take_damage(1.0 * delta)
		