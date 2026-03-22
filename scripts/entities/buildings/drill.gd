@tool
class_name Drill
extends BaseBuilding

@export var storage_cap: int = 100
@export var drill_speed: float = 5.0

@onready var inventory: InventoryComponent = InventoryComponent.new()
var mine_timer: Timer
var _mesh_visual: Node3D

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
	mine_timer.name = "MineTimer"
	mine_timer.wait_time = 2.0
	mine_timer.one_shot = false
	mine_timer.timeout.connect(_on_mine_timer_timeout)
	add_child(mine_timer)
	
	_mesh_visual = get_node_or_null("BlockVisual")
	
	super._ready()
	
	# Initial state check
	_update_mining_state()

func _on_power_status_changed(has_power: bool) -> void:
	# Base class handles is_active flag
	super._on_power_status_changed(has_power)
	_update_mining_state()
	print("Drill %s Power Status Changed: %s" % [name, is_active])

func _update_mining_state() -> void:
	if is_active:
		if mine_timer.is_stopped():
			mine_timer.start()
			print("Drill %s started mining." % name)
	else:
		mine_timer.stop()
		print("Drill %s stopped mining." % name)

func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	
	# Visual Feedback: Spin the drill bit if active
	if is_active and is_instance_valid(_mesh_visual):
		_mesh_visual.rotate_y(drill_speed * delta)
	
	# Output Logic: Continuously try to output if items are available
	if is_active and inventory.has_item():
		try_output_from_inventory(inventory)

func _on_mine_timer_timeout() -> void:
	if not is_active: return
	
	# Mining Logic
	var tile_coord = LaneManager.world_to_tile(global_position)
	var gc = get_node_or_null("GridComponent")
	if gc: tile_coord = gc.tile_coord
	
	# Get center of the tile at Y=0 (floor)
	var floor_pos = LaneManager.tile_to_world(tile_coord)
	
	var ore = LaneManager.get_ore_at_world_pos(floor_pos)
	
	if ore:
		if inventory.has_space_for(ore):
			var remainder = inventory.add_item(ore, 1)
			if remainder == 0:
				LaneManager.consume_ore_at(tile_coord)
				print("Drill mined: %s at %s" %[ore.item_name, str(tile_coord)])
			else:
				print("Drill inventory full.")
	else:
		# Verbose Debugging for "Why isn't it mining?"
		if LaneManager.grid_map:
			var cell_item = LaneManager.grid_map.get_cell_item(Vector3i(tile_coord.x, 0, tile_coord.y))
			print("Drill at %s found GridMap ID: %d. (Expected valid Ore ID)" % [tile_coord, cell_item])
		else:
			print("Drill Error: LaneManager GridMap not assigned.")
