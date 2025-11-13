class_name ElementalComponent
extends Node

## Manages active elemental statuses on its parent node.

signal status_applied(status_name, effect_data)
signal status_removed(status_name)

var active_statuses: Dictionary = {} # { "status_name": Timer }


func _process(delta: float) -> void:
	# Handle ongoing effects, like damage over time.
	var parent = get_parent()
	if not is_instance_valid(parent): return
	
	for status_name in active_statuses:
		var effect = ElementManager.status_effects.get(status_name)
		if effect and effect.has("damage_per_second"):
			# The parent must have a take_damage method for this to work.
			if parent.has_method("take_damage"):
				var dps = effect["damage_per_second"]
				parent.take_damage(dps * delta)


func apply_status(status_name: String, effect_data: Dictionary) -> void:
	# If status is already active, just reset its timer.
	if active_statuses.has(status_name):
		active_statuses[status_name].start(effect_data["duration"])
	else:
		# Create a new timer for the status duration.
		var timer = Timer.new()
		timer.one_shot = true
		timer.wait_time = effect_data["duration"]
		# When timer times out, remove the status. Connect with bind to pass status_name.
		timer.timeout.connect(_on_status_expired.bind(status_name))
		add_child(timer)
		timer.start()
		
		active_statuses[status_name] = timer
		emit_signal("status_applied", status_name, effect_data)


func _on_status_expired(status_name: String) -> void:
	if active_statuses.has(status_name):
		var timer = active_statuses.get(status_name)
		active_statuses.erase(status_name)
		timer.queue_free() # Clean up the timer node.
		emit_signal("status_removed", status_name)


func has_status(status_name: String) -> bool:
	return active_statuses.has(status_name)