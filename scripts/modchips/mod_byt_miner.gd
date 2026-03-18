extends ModChip

var applied: bool = false

func _on_apply() -> void:
	if not applied:
		var ally_res = load("res://resources/allies/drone.tres")
		if ally_res and ally_res.scene:
			var ally = ally_res.scene.instantiate()
			# Target is Core. Parent is Main
			var buildings_node = target.get_parent().get_node_or_null("Buildings")
			if buildings_node:
				buildings_node.add_child(ally)
			else:
				target.get_parent().add_child(ally)
			ally.global_position = target.global_position + Vector3(2, 0, 2)
		applied = true
		