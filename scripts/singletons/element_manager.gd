extends Node

## Manages elemental statuses and reactions.

# Status definition
var status_effects: Dictionary = {
	"Fire": {
		"damage_per_second": 5.0,
		"duration": 3.0,
		"color": Color(1, 0.34, 0.13, 1)
	},
	"Shock": {
		"damage_per_second": 2.0,
		"duration": 2.0,
		"color": Color(0.2, 0.2, 1.0, 1),
		"stun": true
	},
	"Wet": {
		"damage_per_second": 0.0,
		"duration": 5.0,
		"color": Color(0.2, 0.4, 0.8, 1)
	},
	"Chem": {
		"damage_per_second": 3.0,
		"duration": 4.0,
		"color": Color(0.4, 0.8, 0.2, 1)
	}
}

# Reaction Rules: Source Element (being applied) -> { Existing Status -> Reaction Name }
var reactions: Dictionary = {
	"Fire": {
		"Chem": "Explosion",
		"Wet": "Steam"
	},
	"Chem": {
		"Fire": "Explosion"
	},
	"Shock": {
		"Wet": "Electrocute"
	},
	"Wet": {
		"Fire": "Steam",
		"Shock": "Electrocute"
	}
}


## Called from a source (like a projectile) to apply an element to a target.
func apply_element(target: Node, element: ElementResource) -> void:
	if not is_instance_valid(target) or not element:
		return
		
	var elemental_component = target.get_node_or_null("ElementalComponent")
	if not elemental_component:
		return
		
	var new_status = element.element_name
	
	# 1. Check for Reactions with existing statuses
	for active_status in elemental_component.active_statuses.keys():
		if reactions.has(new_status) and reactions[new_status].has(active_status):
			var reaction_name = reactions[new_status][active_status]
			_trigger_reaction(target, reaction_name)
			# Consume the existing status
			elemental_component.remove_status(active_status)
			# Consuming the new status (return) effectively reacts them together
			return 

	# 2. Apply Status if no reaction consumed it
	if status_effects.has(new_status):
		var effect_data = status_effects[new_status]
		elemental_component.apply_status(new_status, effect_data)


func _trigger_reaction(target: Node, reaction_name: String) -> void:
	print("Elemental Reaction: %s on %s" % [reaction_name, target.name])
	
	match reaction_name:
		"Explosion":
			# Immediate high damage
			if target.has_method("take_damage"):
				target.take_damage(50.0)
			# Visual effect could be spawned here
			
		"Steam":
			# Minor damage + visual
			if target.has_method("take_damage"):
				target.take_damage(10.0)
				
		"Electrocute":
			# High damage + maybe stun logic
			if target.has_method("take_damage"):
				target.take_damage(30.0)