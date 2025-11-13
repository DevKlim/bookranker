class_name PowerConsumerComponent
extends Node

## A component for entities that consume power from the grid.


## Signal emitted when the power requirement changes.
signal power_demand_changed(new_demand)


## The amount of power this entity requires to operate.
@export var power_consumption: float = 5.0:
	# When this value changes, emit a signal so the PowerGridManager can update.
	set(value):
		if power_consumption != value:
			power_consumption = value
			emit_signal("power_demand_changed", power_consumption)


## Tracks whether this component is currently receiving power from the grid.
var has_power: bool = false


## Called by the PowerGridManager to update the power status of the parent entity.
func set_power_status(is_powered: bool) -> void:
	if has_power != is_powered:
		has_power = is_powered
		var parent = get_parent()
		# If the parent entity has a function to react to power changes, call it.
		# This allows entities to turn on/off based on power availability.
		if parent and parent.has_method("_on_power_status_changed"):
			parent._on_power_status_changed(has_power)

