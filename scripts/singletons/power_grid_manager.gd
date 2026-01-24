extends Node

## Manages the entire power grid, tracking all providers and consumers.
## Calculates net power and updates consumer status with robust connection checks.

signal grid_updated(total_power, total_demand, net_power)

var providers: Array[PowerProviderComponent] = []
var consumers: Array[PowerConsumerComponent] = []

var total_power_generation: float = 0.0
var total_power_demand: float = 0.0
var net_power: float = 0.0

@onready var wiring_manager = get_node("/root/WiringManager")
@onready var build_manager = get_node("/root/BuildManager")
@onready var lane_manager = get_node("/root/LaneManager") 

func _ready() -> void:
	print("PowerGridManager Initialized.")
	# Respond to wire network changes
	wiring_manager.network_updated.connect(update_grid)

## Updates the power state for all consumers.
func update_grid(_arg = null) -> void:
	if not is_inside_tree(): return
	call_deferred("_process_grid_update")

func _process_grid_update() -> void:
	# 1. Total Generation
	total_power_generation = 0.0
	for provider in providers:
		if is_instance_valid(provider):
			total_power_generation += provider.power_generation

	# 2. Check Connections
	var eligible_consumers: Array[PowerConsumerComponent] = []
	var _disconnected_count = 0
	
	for consumer in consumers:
		if not is_instance_valid(consumer): continue
		
		var is_eligible = true
		
		if consumer.requires_wire_connection:
			var parent = consumer.get_parent()
			if parent and parent is Node3D:
				# Skip if parent hasn't been placed fully (e.g. at 0,0,0 if not intended)
				# But (0,0) is a valid tile, so we trust standard placement flow.
				
				var wire_found = false
				var origin_coord = lane_manager.world_to_tile(parent.global_position)
				
				# Check Multi-block footprints
				if parent.has_method("get_occupied_cells"):
					var offsets = parent.get_occupied_cells()
					for offset in offsets:
						if wiring_manager.is_powered(origin_coord + offset):
							wire_found = true
							break
				else:
					if wiring_manager.is_powered(origin_coord):
						wire_found = true
				
				if not wire_found:
					is_eligible = false
			else:
				is_eligible = false
		
		if is_eligible:
			eligible_consumers.append(consumer)
		else:
			consumer.set_power_status(false)
			_disconnected_count += 1

	# 3. Calculate Demand
	total_power_demand = 0.0
	for consumer in eligible_consumers:
		total_power_demand += consumer.power_consumption

	# 4. Determine Status
	net_power = total_power_generation - total_power_demand
	var has_sufficient_main_power: bool = net_power >= 0
	
	# Apply Status
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
