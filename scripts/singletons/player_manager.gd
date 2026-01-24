extends Node

## Manages the local player's global state, primarily Inventory and Game Mode.

signal mode_changed(is_creative)
signal equipped_item_changed(item)

var player_inventory: InventoryComponent
var crafter: CrafterComponent

var equipped_item: ItemResource = null:
	set(value):
		if equipped_item != value:
			equipped_item = value
			emit_signal("equipped_item_changed", equipped_item)

var is_creative_mode: bool = false:
	set(value):
		# Only act if the state is actually changing
		if is_creative_mode != value:
			# Inventory is now preserved when toggling modes.
			is_creative_mode = value
			emit_signal("mode_changed", is_creative_mode)

func _ready() -> void:
	# Initialize a persistent inventory for the player
	player_inventory = InventoryComponent.new()
	player_inventory.name = "PlayerInventory"
	player_inventory.max_slots = 40 # 10 Hotbar + 30 Storage
	player_inventory.slot_capacity = 99
	player_inventory.can_receive = true
	player_inventory.can_output = true
	add_child(player_inventory)
	
	# Initialize Player Crafter
	crafter = CrafterComponent.new()
	crafter.name = "PlayerCrafter"
	add_child(crafter)
	crafter.craft_finished.connect(_on_craft_finished)

func request_craft(recipe: RecipeResource) -> void:
	if crafter.is_busy(): return
	
	if is_creative_mode:
		_award_recipe_outputs(recipe)
		return

	# Take away resources immediately
	if player_inventory.consume_ingredients_for(recipe):
		crafter.start_craft(recipe)

func _on_craft_finished(recipe: RecipeResource) -> void:
	_award_recipe_outputs(recipe)

func _award_recipe_outputs(recipe: RecipeResource) -> void:
	if recipe.outputs.is_empty(): return
	for out_entry in recipe.outputs:
		if out_entry.get("resource") and out_entry.get("count", 0) > 0:
			player_inventory.add_item(out_entry.resource, out_entry.count)

func set_equipped_item(item: ItemResource) -> void:
	self.equipped_item = item

func has_resources_to_build(buildable: BuildableResource) -> bool:
	if is_creative_mode: return true
	# For simplicity in this factory phase, the "Item" required to build
	# is the BuildableResource itself.
	return player_inventory.has_item_count(buildable, 1)

func consume_build_resource(buildable: BuildableResource) -> void:
	if is_creative_mode: return
	player_inventory.remove_item(buildable, 1)

## Internal helper to wipe inventory (kept for manual use/resets)
func _clear_all_items() -> void:
	if player_inventory:
		player_inventory.slots.fill(null)
		player_inventory.emit_signal("inventory_changed")
	
	# Also clear the hand to prevent holding a deleted item
	set_equipped_item(null)
