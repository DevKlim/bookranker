extends ModChip

func get_stat_modifier(stat_name: String) -> float:
	match stat_name:
		"luck_stat_flat": return 15.0
	return 0.0

