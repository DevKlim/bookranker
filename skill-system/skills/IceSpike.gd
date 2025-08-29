extends Skill

func _init():
	skill_name = "Ice Spike"
	description = "Summons a sharp ice spike from the ground."
	cooldown = 3.0
	skill_input_action = "skill2"

	# --- Inherited from Attack ---
	animation_name = &"Attack1_3" # Reuse another animation
	required_state = "Grounded"
	required_input = "attack1" # Unused for skills
	effect_frame = 4
	end_lag_duration = 0.3

func execute_effect(player: CharacterBody2D):
	print("SHING! An ice spike erupts from the ground in front of the player!")
	# In a real game, you would instance an effect scene here.