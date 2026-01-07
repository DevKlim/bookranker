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
@onready var lane_manager = get_node("/root/LaneManager") 

func _ready() -> void:
	print("PowerGridManager Initialized.")
	wiring_manager.network_updated.connect(update_grid)

func update_grid(_arg = null) -> void:
	# 1. Calculate total generation
	total_power_generation = 0.0
	for provider in providers:
		if is_instance_valid(provider):
			total_power_generation += provider.power_generation

	# 2. Check Consumer Eligibility (Wire Connection)
	var eligible_consumers: Array[PowerConsumerComponent] = []
	var disconnected_count = 0
	
	for consumer in consumers:
		if not is_instance_valid(consumer): continue
		
		var is_eligible = true
		
		if consumer.requires_wire_connection:
			var parent = consumer.get_parent()
			if parent and parent is Node3D:
				# Use LaneManager to get the logical tile of the building
				var logic_coord = lane_manager.world_to_tile(parent.global_position)
				
				# Check if the wire at this coordinate is powered (connected to source)
				if not wiring_manager.is_powered(logic_coord):
					is_eligible = false
					# Optional: Debug only if we suspect issues
					# print("PowerGrid: %s at %s is disconnected from power source." % [parent.name, logic_coord])
			else:
				is_eligible = false
		
		if is_eligible:
			eligible_consumers.append(consumer)
		else:
			consumer.set_power_status(false)
			disconnected_count += 1

	# 3. Calculate Demand
	total_power_demand = 0.0
	for consumer in eligible_consumers:
		total_power_demand += consumer.power_consumption

	# 4. Determine Grid Status
	net_power = total_power_generation - total_power_demand
	var has_sufficient_main_power: bool = net_power >= 0
	
	print("--- Power Grid Update ---")
	print("Gen: %.1f | Demand: %.1f | Net: %.1f" % [total_power_generation, total_power_demand, net_power])
	print("Consumers: %d Total | %d Eligible | %d Disconnected" % [consumers.size(), eligible_consumers.size(), disconnected_count])

	# 5. Apply Status
	for consumer in eligible_consumers:
		consumer.set_power_status(has_sufficient_main_power)
		
	emit_signal("grid_updated", total_power_generation, total_power_demand, net_power)

func register_provider(provider: PowerProviderComponent) -> void:
	if not providers.has(provider):
		providers.append(provider)
		if not provider.power_output_changed.is_connected(update_grid):
			provider.power_output_changed.connect(update_grid)
		provider.tree_exiting.connect(func(): unregister_provider(provider))
		update_grid()

func unregister_provider(provider: PowerProviderComponent) -> void:
	if providers.has(provider):
		if provider.is_connected("power_output_changed", update_grid):
			provider.power_output_changed.disconnect(update_grid)
		providers.erase(provider)
		update_grid()

func register_consumer(consumer: PowerConsumerComponent) -> void:
	if not consumers.has(consumer):
		consumers.append(consumer)
		if not consumer.power_demand_changed.is_connected(update_grid):
			consumer.power_demand_changed.connect(update_grid)
		consumer.tree_exiting.connect(func(): unregister_consumer(consumer))
		update_grid()

func unregister_consumer(consumer: PowerConsumerComponent) -> void:
	if consumers.has(consumer):
		if consumer.is_connected("power_demand_changed", update_grid):
			consumer.power_demand_changed.disconnect(update_grid)
		consumers.erase(consumer)
		update_grid()
