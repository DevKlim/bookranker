# skill-system/SkillBar.gd
extends Node

# A list of the action names we care about
var skill_actions = ["skill1", "skill2", "skill3", "skill4"]

func _unhandled_input(event):
	for action in skill_actions:
		if Input.is_action_just_pressed(action):
			# Tell the server which action was triggered
			get_parent().rpc("use_skill", action)
