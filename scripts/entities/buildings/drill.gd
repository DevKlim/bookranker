@tool
class_name Drill
extends BaseBuilding

@export var storage_cap: int = 100

@onready var inventory: InventoryComponent = InventoryComponent.new()
var mine_timer: Timer

func _init() -> void:
	has_input = false
	has_output = true

func _ready() -> void:
	if Engine.is_editor_hint(): return

	inventory.name = "InventoryComponent"
	inventory.max_slots = 1
	inventory.slot_capacity = storage_cap
	add_child(inventory)
	
	mine_timer = Timer.new()
	mine_timer.wait_time = 2.0
	mine_timer.one_shot = false
	mine_timer.timeout.connect(_on_mine_timer_timeout)
	add_child(mine_timer)
	
	super._ready()

func _on_power_status_changed(has_power: bool) -> void:
	super._on_power_status_changed(has_power)
	if has_power:
		mine_timer.start()
	else:
		mine_timer.stop()

func _on_mine_timer_timeout() -> void:
	if not is_active: return
	
	# Determine logical center of the tile this drill sits on
	var tile_center_pos = global_position + center_offset
	
	# Query LaneManager for ore using world coordinates.
	# Now expects ore data to be aligned with visual tiles.
	var ore = LaneManager.get_ore_at_world_pos(tile_center_pos)
	
	# Debugging block to troubleshoot coordinate mismatch
	var build_offset = LaneManager.get_layer_offset("building")
	var building_tile = LaneManager.world_to_tile(global_position - build_offset)
	
	var visual_ore_tile = LaneManager.world_to_tile(tile_center_pos)
	
	var log_msg = "[Drill %s] at GlobalPos: %s (Tile: %s) searching at WorldPos: %s (Visual Ore Tile: %s)" % [
		get_instance_id(), 
		global_position, 
		building_tile, 
		tile_center_pos, 
		visual_ore_tile
	]
	
	if ore:
		if inventory.has_space_for(ore):
			inventory.add_item(ore, 1)
			print(log_msg + " -> MINED: " + ore.item_name)
		else:
			print(log_msg + " -> FOUND " + ore.item_name + " (Inventory Full)")
	else:
		print(log_msg + " -> NO ORE FOUND")
	
	if inventory.has_item():
		try_output_from_inventory(inventory)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint(): return
	
	if is_active and inventory.has_item():
		try_output_from_inventory(inventory)
