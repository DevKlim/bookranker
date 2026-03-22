class_name CrafterComponent
extends Node

signal craft_started(recipe)
signal craft_finished(recipe)
signal progress_changed(percent)

@export var auto_craft: bool = true

var is_crafting: bool = false
var progress: float = 0.0
var current_recipe: RecipeResource = null
var processing_speed_mult: float = 1.0
var _recipe_check_timer: float = 0.0

func _ready() -> void:
	set_process(true) # Need process for auto-crafting checks

func _process(delta: float) -> void:
	if is_crafting:
		update_process(delta)
	elif auto_craft:
		_recipe_check_timer -= delta
		if _recipe_check_timer <= 0:
			_recipe_check_timer = 1.0
			_try_auto_craft()

func _try_auto_craft() -> void:
	var parent = get_parent()
	if "is_active" in parent and not parent.is_active: return
	var inv = parent.get_node_or_null("InventoryComponent")
	if not inv: return
	
	var available = GameManager.get_available_recipes()
	# Match by category
	var b_name = parent.display_name.to_lower().replace(" ", "_")
	
	for r in available:
		if r.category.to_lower() == b_name or r.category == "assembly" or r.category == "basic":
			if inv.has_ingredients_for(r):
				var can_fit = true
				for out in r.outputs:
					if not inv.has_space_for(out.resource):
						can_fit = false
						break
				if can_fit:
					inv.consume_ingredients_for(r)
					start_craft(r)
					return

## Returns true if a cycle finished this frame
func update_process(delta: float) -> bool:
	if not is_crafting or not current_recipe: 
		is_crafting = false
		return false
		
	var parent = get_parent()
	if "is_active" in parent and not parent.is_active: return false
	
	progress += delta * processing_speed_mult
	
	var duration = max(0.1, current_recipe.craft_time)
	var percent = clamp(progress / duration, 0.0, 1.0)
	emit_signal("progress_changed", percent)
	
	if progress >= duration:
		_complete_craft()
		return true
		
	return false

## Checks if the crafter is actively processing an item
func is_busy() -> bool:
	return is_crafting

func start_craft(recipe: RecipeResource):
	current_recipe = recipe
	is_crafting = true
	progress = 0.0
	emit_signal("craft_started", recipe)

func stop_craft():
	is_crafting = false
	progress = 0.0
	emit_signal("progress_changed", 0.0)

func _complete_craft() -> void:
	var finished_recipe = current_recipe
	is_crafting = false
	progress = 0.0
	emit_signal("progress_changed", 1.0)
	emit_signal("craft_finished", finished_recipe)
	
	var parent = get_parent()
	var inv = parent.get_node_or_null("InventoryComponent")
	if inv and finished_recipe:
		for out in finished_recipe.outputs:
			inv.add_item(out.resource, out.count)
