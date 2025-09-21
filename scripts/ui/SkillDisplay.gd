extends PanelContainer
class_name SkillDisplay

@onready var icon_texture: TextureRect = $MarginContainer/Icon
@onready var key_label: Label = $KeyLabel

var assigned_attack: Attack

func setup(attack: Attack, key_text: String):
	assigned_attack = attack
	key_label.text = key_text
	
	if attack and not attack.icon_path.is_empty():
		icon_texture.texture = load(attack.icon_path)
	else:
		icon_texture.texture = null # Clear texture if no icon

	# TODO: Add logic for cooldowns, costs, etc.