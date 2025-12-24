extends Node

## Manages elemental statuses and reactions.

# Default dictionary fallback, mainly for legacy support or missing JSON data
var status_effects: Dictionary = {
	"Fire": { "damage_per_second": 5.0, "duration": 3.0 },
	"Shock": { "damage_per_second": 2.0, "duration": 2.0, "stun": true },
	"Wet": { "damage_per_second": 0.0, "duration": 5.0 },
	"Chem": { "damage_per_second": 3.0, "duration": 4.0 }
}

## Called from a source (like a projectile) to apply an element to a target.
func apply_element(target: Node, element: ElementResource) -> void:
	if not is_instance_valid(target) or not element:
		return
		
	var elemental_component = target.get_node_or_null("ElementalComponent")
	if not elemental_component:
		return
		
	var new_status_id = element.element_name.to_lower()
	
	# 1. Check for Reactions defined in the ElementResource
	for active_status_id in elemental_component.active_statuses.keys():
		if element.reaction_rules.has(active_status_id):
			var reaction_name = element.reaction_rules[active_status_id]
			_trigger_reaction(target, reaction_name)
			elemental_component.remove_status(active_status_id)
			return # Reaction consumes the application

	# 2. Apply Status
	# Prioritize effect data from the Resource (JSON), fall back to hardcoded dict
	var effect_data = element.effect_data
	if effect_data.is_empty() and status_effects.has(element.element_name):
		effect_data = status_effects[element.element_name]
	
	# Fallback default if nothing is defined
	if effect_data.is_empty():
		effect_data = {"duration": 3.0, "damage_per_second": 0}
		
	elemental_component.apply_status(new_status_id, effect_data)

func _trigger_reaction(target: Node, reaction_name: String) -> void:
	print("Elemental Reaction: %s on %s" % [reaction_name, target.name])
	
	match reaction_name:
		"explosion":
			if target.has_method("take_damage"): target.take_damage(50.0)
		"steam":
			if target.has_method("take_damage"): target.take_damage(10.0)
		"electrocute":
			if target.has_method("take_damage"): target.take_damage(30.0)
		"conduct":
			# Example of chaining reactions or applying buff logic could go here
			pass
		"melt":
			if target.has_method("take_damage"): target.take_damage(20.0)
