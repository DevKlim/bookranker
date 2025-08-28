# skill-system/skills/Fireball.gd
extends Skill

func _init():
	skill_name = "Fireball"
	description = "Launches a fiery projectile."
	cooldown = 2.0
	action_duration = 1

# The 'use' function now only contains logic that ALL players should see.
func use(player):
	print("Fireball visual/audio logic is triggered for everyone.")
	# Example:
	# var fireball_scene = load("res://path/to/fireball_effect.tscn").instantiate()
	# get_tree().root.add_child(fireball_scene)
	# fireball_scene.global_transform = player.global_transform