extends Node

@onready var player = get_parent()

var skills = {}
var skill_actions = ["skill1", "skill2", "skill3", "skill4"]

func _ready():
	if is_multiplayer_authority():
		add_skill("skill1", load("res://skill-system/skills/Fireball.gd").new())
		add_skill("skill2", load("res://skill-system/skills/IceSpike.gd").new())
	


func _unhandled_input(event):
	if get_multiplayer_authority() == multiplayer.get_unique_id():
		for action in skill_actions:
			if Input.is_action_just_pressed(action):
				rpc("use_skill", action)

func add_skill(action_name, skill):
	if skills.has(action_name):
		remove_child(skills[action_name])
	skills[action_name] = skill
	add_child(skill)
	

@rpc("call_local")
func use_skill(action_name):
	if not is_multiplayer_authority(): return

	if not player.can_use_skill():
		print("Player is busy!")
		return

	if skills.has(action_name):
		var skill = skills[action_name]
		if skill.can_use(self):
			player.set_action_busy()
			skill.execute(self)
			rpc("play_skill_effect", action_name)
			
			# Create a one-shot timer in code.
			# When it times out, it will call the _on_skill_duration_finished function.
			get_tree().create_timer(skill.action_duration).timeout.connect(_on_skill_duration_finished)

func _on_skill_duration_finished():
	# This function is called on the authority (host) when the timer ends.
	# It tells the player node to return to a neutral state.
	player.end_action_busy()

@rpc("reliable")
func play_skill_effect(action_name):
	if skills.has(action_name):
		var skill = skills[action_name]
		skill.use(self)
