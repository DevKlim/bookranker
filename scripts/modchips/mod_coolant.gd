extends ModChip

func get_stat_modifier(stat_name: String) -> float:
	if stat_name == "attack_speed_mult":
		return -0.02
	return 0.0

func _process(delta: float) -> void:
	if is_instance_valid(target) and target.get("health_component"):
		var hc = target.health_component
		if hc.current_health < hc.max_health:
			hc.current_health = min(hc.max_health, hc.current_health + (1.0 * delta))
			