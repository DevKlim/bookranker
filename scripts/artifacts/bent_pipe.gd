extends ArtifactBase

func on_attack(agent: Node, target: Node, item: ItemResource, damage: float) -> void:
	if target is CharacterBody3D and target.has_method("apply_impulse"):
		var dir = (target.global_position - agent.global_position).normalized()
		dir.y = 0.0
		if dir.length_squared() < 0.001:
			if "facing_direction" in agent:
				dir = agent.facing_direction
			else:
				dir = Vector3(1, 0, 0)
		
		# Knock slightly up and push backwards one tile gracefully
		dir.y = 0.2
		target.apply_impulse(dir.normalized() * 18.0)
