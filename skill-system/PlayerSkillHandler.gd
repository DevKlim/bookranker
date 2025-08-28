extends Node

# Add this export so you can assign your SkillBar.tscn scene in the Inspector.
@export var skill_bar_scene: PackedScene

var skills = {}
var skill_actions = ["skill1", "skill2", "skill3", "skill4"] # A list of your skill input actions

func _ready():
	# --- Authoritative Skill Setup (Runs on Host) ---
	if is_multiplayer_authority():
		# Map the ACTION STRING to the skill resource
		add_skill("skill1", load("res://skill-system/skills/Fireball.gd").new())
		add_skill("skill2", load("res://skill-system/skills/IceSpike.gd").new())
	
	# --- Local Player GUI Setup (Runs ONLY on your screen) ---
	# This checks if the current game instance belongs to the player who owns this node.
	if get_multiplayer_authority() == multiplayer.get_unique_id():
		# If it is, create the skill bar GUI.
		var skill_bar = skill_bar_scene.instantiate()
		add_child(skill_bar)
		skill_bar.setup_skill_bar(skills)

# --- Local Player Input Handling (Runs ONLY on your screen) ---
func _unhandled_input(event):
	# Only process input for the player who owns this node.
	if get_multiplayer_authority() == multiplayer.get_unique_id():
		for action in skill_actions:
			if Input.is_action_just_pressed(action):
				# Send the request to use the skill to the server (or host).
				rpc("use_skill", action)

func add_skill(action_name, skill):
	if skills.has(action_name):
		remove_child(skills[action_name])
	skills[action_name] = skill
	add_child(skill)

# --- RPC Functions (Server-Side Logic and Replication) ---

@rpc("call_local")
func use_skill(action_name): # Receives the action string from a client
	# Only the authority (the host) can execute this logic.
	if not is_multiplayer_authority(): return

	if skills.has(action_name):
		var skill = skills[action_name]
		# The host checks the cooldown.
		if skill.can_use(self):
			# If valid, execute the skill's core logic...
			skill.execute(self)
			# ...and tell all players to play the visual effect.
			rpc("play_skill_effect", action_name)

@rpc("reliable")
func play_skill_effect(action_name): # Receives the instruction from the host
	if skills.has(action_name):
		var skill = skills[action_name]
		# All players run the 'use' function to see the visuals.
		skill.use(self)
