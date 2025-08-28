extends Panel

signal skill_clicked(keybind)

var skill
var keybind

func set_skill(new_skill, new_keybind):
	self.skill = new_skill
	self.keybind = new_keybind
	$SkillName.text = skill.skill_name
	$Keybind.text = OS.get_keycode_string(keybind)

func _on_gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		emit_signal("skill_clicked", keybind)
	
