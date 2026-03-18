extends ModChip

func get_stat_modifier(stat_name: String) -> float:
	if stat_name == "max_health_mult":
		return 0.2
	return 0.0
	