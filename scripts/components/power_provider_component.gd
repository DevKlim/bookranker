class_name PowerProviderComponent
extends Node

## A component for entities that generate power for the grid.


## Signal emitted when the power output of this provider changes.
signal power_output_changed(new_output)


## The amount of power this entity generates.
@export var power_generation: float = 10.0:
	# When this value changes, emit a signal so the PowerGridManager can update.
	set(value):
		if power_generation != value:
			power_generation = value
			emit_signal("power_output_changed", power_generation)

