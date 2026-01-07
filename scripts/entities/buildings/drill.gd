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
	# Global position is typically centered on X/Z for buildings due to snap
	var check_pos = global_position
	
	# Query LaneManager for ore using world coordinates.
	var ore = LaneManager.get_ore_at_world_pos(check_pos)
	
	if ore:
		if inventory.has_space_for(ore):
			inventory.add_item(ore, 1)
	
	if inventory.has_item():
		try_output_from_inventory(inventory)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint(): return
	
	# Continuously try to output if items are available
	if is_active and inventory.has_item():
		try_output_from_inventory(inventory)
