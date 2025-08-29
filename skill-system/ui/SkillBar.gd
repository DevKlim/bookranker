# skill-system/ui/SkillBar.gd
extends CanvasLayer

# --- Node References ---
# Get a reference to the HBoxContainer that will hold the icons.
@onready var container = $MarginContainer/HBoxContainer

# --- Preload Scenes ---
# Preload the SkillIcon scene so we can create instances of it.
const SkillIconScene = preload("res://skill-system/ui/SkillIcon.tscn")

# This is the function that PlayerSkillHandler is trying to call.
# It takes the player's skills and builds the UI.
func setup_skill_bar(player_skills: Dictionary):
	# Clear any old icons first to prevent duplicates.
	for child in container.get_children():
		child.queue_free()

	# Create a new icon for each skill the player has.
	for action_name in player_skills:
		var skill = player_skills[action_name]
		var skill_icon = SkillIconScene.instantiate()
		container.add_child(skill_icon)
		# Call the set_skill function on the new icon to configure it.
		skill_icon.set_skill(skill, action_name)