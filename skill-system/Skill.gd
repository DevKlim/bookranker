# skill-system/Skill.gd
class_name Skill
extends Node

var skill_name = "skill"
var description  = "description"
var cooldown = 1.0
var cooldown_timer = 0.0
var action_duration = 0.5

func _process(delta):
	if cooldown_timer > 0:
		cooldown_timer -= delta

func can_use(player):
	return cooldown_timer <= 0

# SERVER LOGIC: This function handles cooldowns, applies damage, etc.
# It runs ONLY on the host/server.
func execute(player):
	cooldown_timer = cooldown
	print("Executing skill " + skill_name + " on server.")

# CLIENT VISUALS: This function handles particles, sounds, animations.
# It runs on EVERYONE'S machine, called by the 'play_skill_effect' RPC.
func use(player):
	print("This is where you would spawn particles or play sounds for " + skill_name)
