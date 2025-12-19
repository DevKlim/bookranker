extends Node

## Manages the entire power grid, tracking all providers and consumers.
## It calculates the net power and tells consumers if they have power.


## Signal emitted when the grid's status is updated.
signal grid_updated(total_power, total_demand, net_power)

# Arrays to keep track of all power providers and consumers in the game.
var providers: Array[PowerProviderComponent] = []
var consumers: Array[PowerConsumerComponent] = []

# Variables to store the calculated state of the power grid.
var total_power_generation: float = 0.0
var total_power_demand: float = 0.0
var net_power: float = 0.0

@onready var wiring_manager = get_node("/root/WiringManager")
@onready var build_manager = get_node("/root/BuildManager")


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("PowerGridManager Initialized.")
	wiring_manager.network_updated.connect(update_grid)


## Recalculates the entire power grid's status.
## This should be called whenever a provider or consumer is added, removed, or changed.
func update_grid() -> void:
	# Ensure we have a reference to the tilemap
	if not is_instance_valid(build_manager.tile_map):
		build_manager._initialize_tilemaps()
		if not is_instance_valid(build_manager.tile_map):
			# If still not valid, we can't calculate spatial eligibility yet.
			# But we should still calculate generation.
			pass

	# 1. Calculate total generation from all providers (Core, etc.)
	total_power_generation = 0.0
	for provider in providers:
		if is_instance_valid(provider):
			total_power_generation += provider.power_generation

	# 2. Separate consumers into two groups based on eligibility
	var eligible_consumers: Array[PowerConsumerComponent] = []
	
	for consumer in consumers:
		if not is_instance_valid(consumer): continue
		
		var is_eligible = true
		
		if consumer.requires_wire_connection:
			var parent_building = consumer.get_parent()
			if parent_building and parent_building.is_inside_tree() and is_instance_valid(build_manager.tile_map):
				# The buildings are visually offset (usually 0, -8). 
				# We must find the tile center to check for wires.
				var offset = Vector2(0, 8)
				if "center_offset" in parent_building:
					offset = parent_building.center_offset

				var check_pos = parent_building.global_position + offset
				var tile_coord = build_manager.tile_map.local_to_map(check_pos)
				
				if not wiring_manager.is_powered(tile_coord):
					is_eligible = false
			elif parent_building:
				# If we can't verify connection, assume false to avoid exploits/bugs
				is_eligible = false
		
		if is_eligible:
			eligible_consumers.append(consumer)
		else:
			consumer.set_power_status(false)

	# 3. Calculate demand for the eligible consumers only
	total_power_demand = 0.0
	for consumer in eligible_consumers:
		total_power_demand += consumer.power_consumption

	# 4. Determine power availability
	net_power = total_power_generation - total_power_demand
	var has_sufficient_main_power: bool = net_power >= 0
	
	# 5. Inform each eligible consumer of its status
	for consumer in eligible_consumers:
		consumer.set_power_status(has_sufficient_main_power)
		
	# 6. Emit signal for UI.
	emit_signal("grid_updated", total_power_generation, total_power_demand, net_power)


## Adds a provider to the grid and connects its signals.
func register_provider(provider: PowerProviderComponent) -> void:
	if not providers.has(provider):
		providers.append(provider)
		provider.power_output_changed.connect(update_grid)
		provider.tree_exiting.connect(func(): unregister_provider(provider))
		update_grid()


## Removes a provider from the grid.
func unregister_provider(provider: PowerProviderComponent) -> void:
	if providers.has(provider):
		if provider.is_connected("power_output_changed", update_grid):
			provider.power_output_changed.disconnect(update_grid)
		providers.erase(provider)
		update_grid()


## Adds a consumer to the grid and connects its signals.
func register_consumer(consumer: PowerConsumerComponent) -> void:
	if not consumers.has(consumer):
		consumers.append(consumer)
		consumer.power_demand_changed.connect(update_grid)
		consumer.tree_exiting.connect(func(): unregister_consumer(consumer))
		update_grid()


## Removes a consumer from the grid.
func unregister_consumer(consumer: PowerConsumerComponent) -> void:
	if consumers.has(consumer):
		if consumer.is_connected("power_demand_changed", update_grid):
			consumer.power_demand_changed.disconnect(update_grid)
		consumers.erase(consumer)
		update_grid()
