# skill-system/SkillIcon.gd
extends Panel

# --- Node References ---
@onready var skill_name_label = $SkillName
@onready var keybind_label = $Keybind
@onready var cooldown_overlay = $CooldownOverlay
@onready var cooldown_text_label = $CooldownText

# --- Private Variables ---
var skill # A reference to the actual Skill node

func _ready():
	# Hide the cooldown overlay by default
	cooldown_overlay.hide()
	cooldown_text_label.hide()

func _process(delta):
	# This function runs every frame to update the cooldown visuals
	if not skill:
		return

	if skill.cooldown_timer > 0:
		# If the skill is on cooldown, show the overlay
		cooldown_overlay.show()
		cooldown_text_label.show()
		# Update the text, formatted to one decimal place
		cooldown_text_label.text = "%.1f" % skill.cooldown_timer
	else:
		# If the skill is ready, hide the overlay
		cooldown_overlay.hide()
		cooldown_text_label.hide()

# This function is called by the SkillBar to set up the icon
func set_skill(skill_node, action_name):
	self.skill = skill_node
	skill_name_label.text = skill.skill_name
	# Find the physical key bound to the action for display
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey:
			keybind_label.text = OS.get_keycode_string(event.physical_keycode)
			print(OS.get_keycode_string(event.keycode))
			break # Stop after finding the first key
		
