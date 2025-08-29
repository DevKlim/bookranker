# skill-system/skills/Fireball.gd
extends Skill

func _init() -> void:
	skill_name = "Fireball"
	description = "Launches a fiery projectile."
	cooldown = 2.0
	skill_input_action = "skill1"
	
	# --- Inherited from Attack ---
	# Let's reuse an existing animation for this example
	animation_name = &"Attack2_1"
	required_state = "Grounded" # Can be used on the ground
	required_input = "attack1" # This is now unused for skills, but part of the base class
	effect_frame = 2 # The frame the fireball should appear
	end_lag_duration = 0.2 # Give it a bit of recovery time

func execute_effect(player: CharacterBody2D) -> void:
	print("WHOOSH! A fireball is launched from the player!")
	# In a real game, you would instance a projectile scene here:
	# var fireball_scene = load("res://scenes/projectiles/fireball.tscn").instantiate()
	# player.get_parent().add_child(fireball_scene)
	# fireball_scene.global_position = player.global_position + Vector2(30 * (1 if not player.animated_sprite.flip_h else -1), 0)