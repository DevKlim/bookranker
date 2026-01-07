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
## Accepts optional argument to satisfy signal connections that pass values (like property setters).
func update_grid(_arg = null) -> void:
	# 1. Calculate total generation from all providers (Core, etc.)
	total_power_generation = 0.0
	for provider in providers:
		if is_instance_valid(provider):
			total_power_generation += provider.power_generation

	# 2. Separate consumers into two groups based on eligibility
	var eligible_consumers: Array[PowerConsumerComponent] = []
	var grid_valid = is_instance_valid(build_manager.grid_map)
	
	for consumer in consumers:
		if not is_instance_valid(consumer): continue
		
		var is_eligible = true
		
		if consumer.requires_wire_connection:
			if grid_valid:
				var parent = consumer.get_parent()
				if parent:
					# Use GridMap to determine the cell
					var local_pos = build_manager.grid_map.to_local(parent.global_position)
					var cell = build_manager.grid_map.local_to_map(local_pos)
					# Convert to logical grid (Vector2i) for WiringManager
					var logic_coord = Vector2i(cell.x, cell.z)
					
					if not wiring_manager.is_powered(logic_coord):
						is_eligible = false
			else:
				# If grid is not ready yet, we can't verify connection.
				# Default to false to prevent free power before init.
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
		# Ensure we don't double connect
		if not provider.power_output_changed.is_connected(update_grid):
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
		if not consumer.power_demand_changed.is_connected(update_grid):
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
