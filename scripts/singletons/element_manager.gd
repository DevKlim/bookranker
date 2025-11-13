extends Node

## Manages elemental statuses and reactions.

# A dictionary defining what status effects do.
# Each key is a status name. The value is a dictionary defining its effects.
# This is where you can easily add new statuses like "Frozen", "Wet", "Electrified".
var status_effects: Dictionary = {
	"Fire": {
		"damage_per_second": 5.0,
		"duration": 3.0,
		"color": Color(1, 0.341176, 0.133333, 1)
	}
}


## Called from a source (like a projectile) to apply an element to a target.
func apply_element(target: Node, element: ElementResource) -> void:
	if not is_instance_valid(target) or not element:
		return
		
	var elemental_component = target.get_node_or_null("ElementalComponent")
	if not elemental_component:
		# If the target can't have elements, do nothing.
		return
		
	# This is a simple system where applying an element applies its corresponding status.
	# A more complex system could check existing elements on the target to cause a reaction.
	# For example: if target has "Wet" and we apply "Electric", trigger "Superconduct" reaction.
	var status_name = element.element_name
	if status_effects.has(status_name):
		var effect_data = status_effects[status_name]
		elemental_component.apply_status(status_name, effect_data)