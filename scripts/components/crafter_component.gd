class_name CrafterComponent
extends Node

signal craft_started(recipe)
signal craft_finished(recipe)
signal progress_changed(percent)

var is_crafting: bool = false
var progress: float = 0.0
var current_recipe: RecipeResource = null
var processing_speed_mult: float = 1.0

func _ready() -> void:
	set_process(false)

func _process(delta: float) -> void:
	update_process(delta)

## Returns true if a cycle finished this frame
func update_process(delta: float) -> bool:
	if not is_crafting or not current_recipe: 
		set_process(false)
		return false
	
	progress += delta * processing_speed_mult
	
	var duration = max(0.1, current_recipe.craft_time)
	var percent = clamp(progress / duration, 0.0, 1.0)
	emit_signal("progress_changed", percent)
	
	if progress >= duration:
		_complete_craft()
		return true
		
	return false

func start_craft(recipe: RecipeResource):
	current_recipe = recipe
	is_crafting = true
	progress = 0.0
	emit_signal("craft_started", recipe)
	set_process(true)

func stop_craft():
	is_crafting = false
	progress = 0.0
	emit_signal("progress_changed", 0.0)
	set_process(false)

func _complete_craft() -> void:
	var finished_recipe = current_recipe
	is_crafting = false
	progress = 0.0
	emit_signal("progress_changed", 1.0)
	emit_signal("craft_finished", finished_recipe)
	set_process(false)

func is_busy() -> bool:
	return is_crafting
