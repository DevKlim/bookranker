extends ModChip

func get_stat_modifier(stat_name: String) -> float:
	if stat_name == "attack_damage_mult":
		return 0.5
	return 0.0

func _on_apply() -> void:
	if is_instance_valid(target) and target.get("health_component"):
		if not target.health_component.is_connected("died", _on_target_died):
			target.health_component.died.connect(_on_target_died)

func _on_remove() -> void:
	if is_instance_valid(target) and target.get("health_component"):
		if target.health_component.is_connected("died", _on_target_died):
			target.health_component.died.disconnect(_on_target_died)

func _on_target_died(_node) -> void:
	if not is_instance_valid(target): return
	var dmg = target.get_stat("max_health", 100.0) * 0.5
	
	if is_instance_valid(ElementManager):
		ElementManager.apply_aoe_damage(target, 3.0, dmg, target, false, 10.0)
			
	if is_instance_valid(GameManager) and GameManager.get("vfx_manager"):
		GameManager.vfx_manager.play_vfx("y2k_reaction", target.global_position)

