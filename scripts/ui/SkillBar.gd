extends Control

# Preload the script to ensure it's available and to make checks more reliable.
const SkillDisplayScript = preload("res://scripts/ui/SkillDisplay.gd")

@onready var bar1_container: HBoxContainer = $Bar1Container
@onready var bar2_container: HBoxContainer = $Bar2Container

var player: CharacterBody2D # Use base type to avoid script parsing issues
var skill_displays: Array = [] # Use a generic array, we will check the type at runtime
var switch_action_name: String = ""

func _ready():
	# Gather all child skill displays in order
	for child in bar1_container.get_children():
		if child.get_script() == SkillDisplayScript:
			skill_displays.append(child)
	for child in bar2_container.get_children():
		if child.get_script() == SkillDisplayScript:
			skill_displays.append(child)
	
	bar2_container.hide()

# Change the type hint here from 'Player' to 'CharacterBody2D'
func link_to_player(player_node: CharacterBody2D):
	player = player_node
	if not is_instance_valid(player): return
	
	# The 'player_id' and 'attack_handler' properties exist on our player script,
	# so we can still access them safely.
	switch_action_name = "p%d_skill_bar_switch" % player.player_id
	player.attack_handler.skills_updated.connect(_on_skills_updated)

func _input(event: InputEvent):
	if switch_action_name.is_empty(): return
	
	if event.is_action_pressed(switch_action_name):
		bar1_container.hide()
		bar2_container.show()
	elif event.is_action_released(switch_action_name):
		bar1_container.show()
		bar2_container.hide()

func _on_skills_updated(skills: Array[Attack]):
	var key_map = {
		"skill1": {"key": "Q", "index": 0}, "skill2": {"key": "W", "index": 1},
		"skill3": {"key": "E", "index": 2}, "skill4": {"key": "R", "index": 3},
		"skill5": {"key": "T", "index": 4}, "skill6": {"key": "Y", "index": 5},
		"skill7": {"key": "G", "index": 6}, "skill8": {"key": "H", "index": 7},
	}
	
	for display in skill_displays: display.hide()
	
	for attack in skills:
		var base_action = attack.skill_input_action
		if key_map.has(base_action):
			var map_data = key_map[base_action]
			var display_index = map_data["index"]
			
			if display_index >= 0 and display_index < skill_displays.size():
				var display = skill_displays[display_index]
				display.setup(attack, map_data["key"])
				display.show()
