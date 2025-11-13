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


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("PowerGridManager Initialized.")


## Recalculates the entire power grid's status.
## This should be called whenever a provider or consumer is added, removed, or changed.
func update_grid() -> void:
	# Reset and calculate total power generation.
	total_power_generation = 0.0
	for provider in providers:
		# Ensure the provider node is still valid before accessing it.
		if is_instance_valid(provider):
			total_power_generation += provider.power_generation

	# Reset and calculate total power demand.
	total_power_demand = 0.0
	for consumer in consumers:
		if is_instance_valid(consumer):
			total_power_demand += consumer.power_consumption

	# Calculate the net power balance.
	net_power = total_power_generation - total_power_demand

	# Notify any listeners (like the UI) about the grid update.
	emit_signal("grid_updated", total_power_generation, total_power_demand, net_power)

	# Determine if there is enough power for all consumers.
	var has_sufficient_power: bool = net_power >= 0
	
	# Inform each consumer of its power status.
	for consumer in consumers:
		if is_instance_valid(consumer):
			consumer.set_power_status(has_sufficient_power)


## Adds a provider to the grid and connects its signals.
func register_provider(provider: PowerProviderComponent) -> void:
	if not providers.has(provider):
		providers.append(provider)
		# Connect to the provider's signal to know when its output changes.
		provider.power_output_changed.connect(update_grid)
		# Automatically unregister when the node is removed from the scene.
		provider.tree_exiting.connect(func(): unregister_provider(provider))
		update_grid()


## Removes a provider from the grid.
func unregister_provider(provider: PowerProviderComponent) -> void:
	if providers.has(provider):
		# Disconnect the signal to prevent errors.
		if provider.is_connected("power_output_changed", update_grid):
			provider.power_output_changed.disconnect(update_grid)
		providers.erase(provider)
		update_grid()


## Adds a consumer to the grid and connects its signals.
func register_consumer(consumer: PowerConsumerComponent) -> void:
	if not consumers.has(consumer):
		consumers.append(consumer)
		# Connect to the consumer's signal to know when its demand changes.
		consumer.power_demand_changed.connect(update_grid)
		# Automatically unregister when the node is removed from the scene.
		consumer.tree_exiting.connect(func(): unregister_consumer(consumer))
		update_grid()


## Removes a consumer from the grid.
func unregister_consumer(consumer: PowerConsumerComponent) -> void:
	if consumers.has(consumer):
		# Disconnect the signal to prevent errors.
		if consumer.is_connected("power_demand_changed", update_grid):
			consumer.power_demand_changed.disconnect(update_grid)
		consumers.erase(consumer)
		update_grid()
