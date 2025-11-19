extends BaseBuilding

@onready var inventory: InventoryComponent = InventoryComponent.new()
var mine_timer: Timer

func _ready() -> void:
	# Add inventory manually since it's new and not in the scene yet
	inventory.name = "InventoryComponent"
	inventory.max_slots = 1
	inventory.slot_capacity = 50
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
	
	# 1. Mine Ore
	var tile_coord = LaneManager.tile_map.local_to_map(global_position)
	var ore = LaneManager.get_ore_at(tile_coord)
	
	if ore and inventory.has_space_for(ore):
		inventory.add_item(ore, 1)
		# print("Drill mined: ", ore.item_name, " Count: ", inventory.slots[0].count)
	
	# 2. Output Ore to neighbor
	_try_output_item()

func _process(_delta: float) -> void:
	# Try outputting frequently, not just on mine tick, in case output was blocked
	if is_active and inventory.has_item():
		_try_output_item()

func _try_output_item():
	var neighbor = get_neighbor(output_direction)
	if neighbor and neighbor.has_method("receive_item"):
		var item = inventory.get_first_item()
		if item:
			if neighbor.receive_item(item):
				inventory.remove_item(item, 1)
