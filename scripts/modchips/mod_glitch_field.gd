extends ModChip

var timer: float = 0.0

func _on_apply() -> void:
	pass

func _on_remove() -> void:
	pass

func _process(delta: float) -> void:
	if not is_instance_valid(target): return
	timer += delta
	if timer >= 5.0:
		timer = 0.0
		_trigger_glitch()

func _trigger_glitch() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty(): return
	
	var target_enemy = enemies.pick_random()
	if is_instance_valid(target_enemy):
		if is_instance_valid(GameManager) and GameManager.get("vfx_manager"):
			GameManager.vfx_manager.play_vfx("y2k_glitch", target_enemy.global_position)
		
		var elements =["igni", "aqua", "volt", "abyss", "light", "plasma"]
		var chosen = elements.pick_random()
		var res = ElementManager.get_element(chosen)
		if res:
			ElementManager.apply_element(target_enemy, res, target, 50.0, 2, true)
			if target_enemy.has_method("take_damage"):
				target_enemy.take_damage(25.0, res, target)

