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
	# 1. Calculate total generation from all providers (Core, etc.)
	total_power_generation = 0.0
	for provider in providers:
		if is_instance_valid(provider):
			total_power_generation += provider.power_generation

	# 2. Separate consumers into two groups: main grid and wire grid
	var main_grid_consumers: Array[PowerConsumerComponent] = []
	for consumer in consumers:
		if not is_instance_valid(consumer): continue
		
		var parent_building = consumer.get_parent()
		var tile_coord = build_manager.tile_map.local_to_map(parent_building.global_position)
		
		if wiring_manager.has_wire(tile_coord):
			# This consumer is on the wire grid. Power it based on the wire's state.
			consumer.set_power_status(wiring_manager.is_powered(tile_coord))
		else:
			# This consumer is on the main grid. Add it to list for demand calculation.
			main_grid_consumers.append(consumer)
	
	# 3. Calculate demand for the main grid only
	total_power_demand = 0.0
	for consumer in main_grid_consumers:
		total_power_demand += consumer.power_consumption

	# 4. Determine power availability for the main grid
	net_power = total_power_generation - total_power_demand
	var has_sufficient_main_power: bool = net_power >= 0
	
	# 5. Inform each main grid consumer of its status
	for consumer in main_grid_consumers:
		consumer.set_power_status(has_sufficient_main_power)
		
	# 6. Emit signal for UI. Note: this shows total demand from main grid only.
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
