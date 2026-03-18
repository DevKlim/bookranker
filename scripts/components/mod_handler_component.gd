class_name ModHandlerComponent
extends Node

var target: Node
var mod_inventory: InventoryComponent

signal mods_updated

func initialize(target_node: Node, inv: InventoryComponent) -> void:
	target = target_node
	mod_inventory = inv
	mod_inventory.inventory_changed.connect(_on_inventory_changed)

func _on_inventory_changed() -> void:
	var changed = false
	for i in range(mod_inventory.slots.size()):
		var slot_name = "ModSlot_" + str(i)
		var existing_mod = get_node_or_null(slot_name)
		
		var slot_data = mod_inventory.slots[i]
		var incoming_id = ""
		if slot_data and slot_data.item:
			incoming_id = slot_data.item.resource_path.get_file().get_basename()
		
		# If the current slot has a different mod than what's equipped
		if existing_mod and existing_mod.get_meta("mod_id", "") != incoming_id:
			existing_mod.queue_free()
			existing_mod = null
			changed = true
			
		# If there's an incoming mod and we don't have it instantiated
		if incoming_id != "" and not existing_mod:
			var script_path = "res://scripts/modchips/" + incoming_id + ".gd"
			if ResourceLoader.exists(script_path):
				var script = load(script_path)
				var mod_node = Node.new()
				mod_node.set_script(script)
				mod_node.name = slot_name
				mod_node.set_meta("mod_id", incoming_id)
				add_child(mod_node)
				changed = true
			else:
				print("Mod script not found: ", script_path)
				
	if changed:
		emit_signal("mods_updated")

## Gathers the cumulative modifier from all active mod scripts.
func get_stat_modifier(stat_name: String) -> float:
	var total = 0.0
	for child in get_children():
		if child.has_method("get_stat_modifier"):
			total += child.get_stat_modifier(stat_name)
	return total

