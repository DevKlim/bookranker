class_name WorldDropTarget
extends Control

func _can_drop_data(_at_position, data):
	return typeof(data) == TYPE_DICTIONARY and data.get('type') == 'inventory_drag'

func _drop_data(at_position, data):
	var game_ui = get_parent()
	if game_ui.has_method('handle_world_drop'):
		game_ui.handle_world_drop(at_position, data)
		