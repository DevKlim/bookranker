class_name ModHandlerComponent
extends Node

var target: Node
var mod_inventory: Node
var _last_slot_hashes: Array = []

signal mods_updated

func initialize(target_node: Node, inv: Node) -> void:
	print("[MOD-HANDLER] Initializing for target: ", target_node.name)
	target = target_node
	mod_inventory = inv
	if not mod_inventory.inventory_changed.is_connected(_on_inventory_changed):
		mod_inventory.inventory_changed.connect(_on_inventory_changed)
		print("[MOD-HANDLER] Connected to inventory_changed for: ", target.name)
		
	# Instantly evaluate existing mods immediately upon script attachment
	_on_inventory_changed()

func _process(_delta: float) -> void:
	# Active polling using item_name instead of resource_path to bypass instancing issues
	if not is_instance_valid(mod_inventory): return
	
	var current_hashes = []
	for slot_data in mod_inventory.slots:
		var res = _extract_resource(slot_data)
		if res:
			current_hashes.append(res.item_name)
		else:
			current_hashes.append("")
			
	if current_hashes != _last_slot_hashes:
		_last_slot_hashes = current_hashes.duplicate()
		print("[MOD-HANDLER] Active polling detected inventory mutation! Forcing sync.")
		_on_inventory_changed()

func _extract_resource(slot_data) -> Resource:
	if slot_data != null:
		if typeof(slot_data) == TYPE_DICTIONARY:
			return slot_data.get("item")
		elif typeof(slot_data) == TYPE_OBJECT:
			if slot_data is Resource:
				return slot_data
			elif "item" in slot_data and slot_data.item != null:
				return slot_data.item
	return null

func _on_inventory_changed() -> void:
	if not is_instance_valid(mod_inventory): 
		return
		
	print("[MOD-HANDLER] Syncing Mod Slots for: ", target.name)
	var changed = false
	
	for i in range(mod_inventory.slots.size()):
		var slot_name = "ModSlot_" + str(i)
		var existing_mod = get_node_or_null(slot_name)
		var item_res = _extract_resource(mod_inventory.slots[i])
					
		var incoming_id = ""
		if item_res != null:
			# Safely determine the mod_id even if resource_path was stripped during copy
			if item_res.resource_path != "":
				incoming_id = item_res.resource_path.get_file().get_basename()
			else:
				incoming_id = item_res.item_name.to_lower().replace(" ", "_")
				if not incoming_id.begins_with("mod_"):
					incoming_id = "mod_" + incoming_id
		
		# If the current slot has a different mod than what's equipped
		if existing_mod and existing_mod.get_meta("mod_id", "") != incoming_id:
			print("[MOD-HANDLER] Removing old mod: ", existing_mod.get_meta("mod_id", ""))
			if existing_mod.has_method("_on_remove"):
				existing_mod._on_remove()
			existing_mod.queue_free()
			existing_mod = null
			changed = true
			
		# If there's an incoming mod and we don't have it instantiated
		if incoming_id != "" and not existing_mod:
			var script_path = "res://scripts/modchips/" + incoming_id + ".gd"
			print("[MOD-HANDLER] Applying mod script: ", script_path)
			
			if ResourceLoader.exists(script_path):
				var script = load(script_path)
				var mod_node = Node.new()
				mod_node.set_script(script)
				mod_node.name = slot_name
				mod_node.set_meta("mod_id", incoming_id)
				mod_node.set("target", target)
				add_child(mod_node)
				
				print("[MOD-HANDLER] Core mod equipped successfully: ", incoming_id)
				
				# Wait a frame before triggering apply so it is safely initialized in the tree
				if mod_node.has_method("_on_apply"):
					mod_node.call_deferred("_on_apply")
				else:
					printerr("[MOD-HANDLER-WARNING] _on_apply method missing in script!")
					
				changed = true
			else:
				printerr("[MOD-HANDLER-ERROR] Mod script not found: ", script_path)
				
	if changed:
		emit_signal("mods_updated")

## Gathers the cumulative modifier from all active mod scripts.
func get_stat_modifier(stat_name: String) -> float:
	var total = 0.0
	for child in get_children():
		if child.has_method("get_stat_modifier"):
			total += child.get_stat_modifier(stat_name)
	return total
