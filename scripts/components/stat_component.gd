class_name StatComponent
extends Node

## Centralized ECS stat tracker. Dynamically computes, caches, and provides stats
## factoring in Base values, Equipment, Elements, Mod Chips, and Formulas.

signal stats_changed

var target: Node
var _cache: Dictionary = {}
var _is_dirty: bool = true
var _evaluating_stats: Array[String] =[] 

func _ready() -> void:
	target = get_parent()
	call_deferred("_setup_connections")

func _setup_connections() -> void:
	var inv = target.get_node_or_null("InventoryComponent")
	if inv and not inv.inventory_changed.is_connected(_on_dirty_0): inv.inventory_changed.connect(_on_dirty_0)
	
	var mod_h = target.get_node_or_null("ModHandlerComponent")
	if mod_h and not mod_h.mods_updated.is_connected(_on_dirty_0): mod_h.mods_updated.connect(_on_dirty_0)
	
	var elem = target.get_node_or_null("ElementalComponent")
	if elem:
		if not elem.status_applied.is_connected(_on_dirty_2): elem.status_applied.connect(_on_dirty_2)
		if not elem.status_removed.is_connected(_on_dirty_1): elem.status_removed.connect(_on_dirty_1)
		if not elem.status_changed.is_connected(_on_dirty_2): elem.status_changed.connect(_on_dirty_2)

	if is_instance_valid(GameManager):
		if not GameManager.run_data_changed.is_connected(_on_dirty_0):
			GameManager.run_data_changed.connect(_on_dirty_0)

	if target.is_in_group("player") and is_instance_valid(PlayerManager):
		if not PlayerManager.equipped_item_changed.is_connected(_on_dirty_1):
			PlayerManager.equipped_item_changed.connect(_on_dirty_1)

	var res = _get_resource()
	if res and not res.changed.is_connected(_on_dirty_0):
		res.changed.connect(_on_dirty_0)

func _on_dirty_0() -> void: _mark_dirty()
func _on_dirty_1(_a) -> void: _mark_dirty()
func _on_dirty_2(_a, _b) -> void: _mark_dirty()

func _mark_dirty() -> void:
	_is_dirty = true
	emit_signal("stats_changed")

func _get_resource() -> Resource:
	if "stats" in target and target.stats is Resource: return target.stats
	if "enemy_resource" in target and target.enemy_resource is Resource: return target.enemy_resource
	return null

func get_stat(stat_name: String, default_value: float = 0.0) -> float:
	if not is_instance_valid(target): return default_value
	
	if _is_dirty:
		_cache.clear()
		_is_dirty = false
		
	if _cache.has(stat_name):
		return _cache[stat_name]
		
	var val = _calculate_stat(stat_name, default_value)
	_cache[stat_name] = val
	return val

func _calculate_stat(stat_name: String, default_value: float) -> float:
	if stat_name in _evaluating_stats: return default_value
	_evaluating_stats.append(stat_name)
	
	var val = default_value
	var res = _get_resource()
	
	# Map "scale" to "entity_scale" to avoid native Godot Node3D scale Vector3 conflicts
	var internal_target_name = "entity_scale" if stat_name == "scale" else stat_name
	
	# 1. Base property strictly from Resource or Parent
	var resource_found = false
	if res:
		var has_prop = false
		if stat_name in res:
			has_prop = true
		else:
			for p in res.get_property_list():
				if p.name == stat_name:
					has_prop = true
					break
		
		if has_prop:
			val = float(res.get(stat_name))
			if stat_name == "speed" and "SPEED_SCALE" in target:
				val *= float(target.get("SPEED_SCALE"))
			resource_found = true
			
	if not resource_found and internal_target_name in target:
		var t_val = target.get(internal_target_name)
		if typeof(t_val) in [TYPE_INT, TYPE_FLOAT]: val = float(t_val)

	# 2. Equipment / Inventory Items
	var items_to_check =[]
	var inv = target.get_node_or_null("InventoryComponent")
	if inv and target.is_in_group("allies"):
		for i in range(min(4, inv.slots.size())):
			var slot = inv.slots[i]
			if slot and slot != null:
				items_to_check.append(slot.item if typeof(slot) == TYPE_DICTIONARY else slot)
				
	if target.is_in_group("player") and is_instance_valid(PlayerManager):
		if PlayerManager.equipped_item:
			items_to_check.append(PlayerManager.equipped_item)
			
	var item_mult = 0.0
	var item_flat = 0.0
			
	for it in items_to_check:
		if it and it is Resource:
			if stat_name + "_bonus" in it: val += float(it.get(stat_name + "_bonus"))
			if stat_name in it: val += float(it.get(stat_name))
			var it_stats = it.get("stats")
			if it_stats is Dictionary and it_stats.has(stat_name): val += float(it_stats[stat_name])
			var it_mods = it.get("modifiers")
			if it_mods is Dictionary:
				if it_mods.has(stat_name): val += float(it_mods[stat_name])
				# Properly parse flat and multiplier modifications inside equipment
				if it_mods.has(stat_name + "_mult"): item_mult += float(it_mods[stat_name + "_mult"])
				if it_mods.has(stat_name + "_flat"): item_flat += float(it_mods[stat_name + "_flat"])

	# 3. Modifiers (Elements & Mod Chips)
	var mult = item_mult
	var flat = item_flat
	
	var mod_h = target.get_node_or_null("ModHandlerComponent")
	if mod_h:
		mult += mod_h.get_stat_modifier(stat_name + "_mult")
		flat += mod_h.get_stat_modifier(stat_name + "_flat")
		
	var elem = target.get_node_or_null("ElementalComponent")
	if elem:
		mult += elem.get_stat_modifier(stat_name + "_mult")
		flat += elem.get_stat_modifier(stat_name + "_flat")

	# 4. Global Modifiers
	var glob_mult = 1.0
	if is_instance_valid(GameManager):
		if target.is_in_group("allies") or target.is_in_group("player"):
			if stat_name == "health": glob_mult = GameManager.get_stat_multiplier("ally_health")
			elif stat_name == "speed": glob_mult = GameManager.get_stat_multiplier("ally_speed")
			elif stat_name == "attack_speed_mult": flat += GameManager.get_global_stat("ally_attack_speed_mult", 0.0)
			elif stat_name == "damage_mult": flat += GameManager.get_global_stat("ally_damage_mult", 0.0)
		elif target.is_in_group("buildings"):
			if stat_name == "health": glob_mult = GameManager.get_stat_multiplier("building_health")

	var final_val = (val * glob_mult) * (1.0 + mult) + flat
	
	# 5. Core Global ECS Inheritance (The Core grants ALL its stats directly to all Allies and Buildings)
	if target != null and not target.is_in_group("core") and target.is_inside_tree():
		var core_node = target.get_tree().get_first_node_in_group("core")
		if is_instance_valid(core_node) and core_node.has_node("StatComponent"):
			var core_stats = core_node.get_node("StatComponent")
			# We ignore scale and space to prevent physics/rendering glitches globally
			if stat_name != "scale" and stat_name != "space":
				final_val += core_stats.get_stat(stat_name, 0.0)

	# 6. Formula Evaluation (Uses weights from other natively computed stats flawlessly)
	var eq_prop = stat_name + "_equation"
	var eq = ""
	if eq_prop in target: eq = target.get(eq_prop)
	elif res and eq_prop in res: eq = res.get(eq_prop)
		
	if eq != "":
		var w_prop = "stat_weights"
		var weights = {}
		if w_prop in target: weights = target.get(w_prop)
		elif res and w_prop in res: weights = res.get(w_prop)
			
		var vars = {"base_" + stat_name: val, "final_" + stat_name: final_val}
		for k in weights.keys():
			vars[k+"_weight"] = weights[k]
			vars[k] = get_stat(k, 0.0)
			
		if ClassDB.class_exists("FormulaHelper") or ResourceLoader.exists("res://scripts/utils/formula_helper.gd"):
			var fh = load("res://scripts/utils/formula_helper.gd")
			if fh: final_val = fh.evaluate(target, eq, vars, final_val)

	_evaluating_stats.erase(stat_name)
	return max(0.0, final_val)
