extends ModChip

func get_stat_modifier(stat_name: String) -> float:
	match stat_name:
		"damage_mult": return 2.0
		"max_health_mult": return -0.9
		"incoming_damage_mult": return 1.0
	return 0.0

