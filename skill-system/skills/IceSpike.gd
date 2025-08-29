extends Skill

func _init():
	skill_name = "Ice Spike"
	description = "Summons a sharp ice spike from the ground."
	cooldown = 3.0

func use(player):
	print("Ice Spike specific logic")
