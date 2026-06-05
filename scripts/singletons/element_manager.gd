extends Node

## Manages elemental reactions and application logic.
## Fully data-driven Reaction System guided dynamically via elements.json imports.

var elements: Dictionary = {}

# Spatial Registry for optimization: { "element_id": { Vector2i:[Node] } }
var status_registry: Dictionary = {} 
# Global Count for "Is this element active anywhere?": { "element_id": int }
var global_element_counts: Dictionary = {}

const SPATIAL_ELEMENTS: Array = ["conduct"]

func _ready() -> void:
	_load_elements_cache()

func _load_elements_cache() -> void:
	var dir = DirAccess.open("res://resources/elements/")
	if dir:
		dir.list_dir_begin()
		var file = dir.get_next()
		while file != "":
			if file.ends_with(".tres"):
				var res = load("res://resources/elements/" + file) as ElementResource
				if res:
					elements[res.element_name.to_lower()] = res
			file = dir.get_next()

func get_element(element_name: String) -> ElementResource:
	return elements.get(element_name.to_lower(), null)

func get_reaction_result(id_a: String, id_b: String) -> String:
	var res_a = get_element(id_a)
	if res_a and res_a.reaction_rules.has(id_b):
		return res_a.reaction_rules[id_b]
	
	var res_b = get_element(id_b)
	if res_b and res_b.reaction_rules.has(id_a):
		return res_b.reaction_rules[id_a]
			
	return ""

## --- GLOBAL TRACKING API ---

func track_element_addition(id: String) -> void:
	if not global_element_counts.has(id):
		global_element_counts[id] = 0
	global_element_counts[id] += 1

func track_element_removal(id: String) -> void:
	if global_element_counts.has(id):
		global_element_counts[id] -= 1
		if global_element_counts[id] <= 0:
			global_element_counts.erase(id)

func is_element_active_globally(id: String) -> bool:
	return global_element_counts.has(id)

## --- SPATIAL REGISTRY API ---

func register_spatial_status(id: String, entity: Node, tile: Vector2i) -> void:
	if id not in SPATIAL_ELEMENTS: return
	if not status_registry.has(id): status_registry[id] = {}
	if not status_registry[id].has(tile): status_registry[id][tile] =[]
	
	if entity not in status_registry[id][tile]:
		status_registry[id][tile].append(entity)

func unregister_spatial_status(id: String, entity: Node, tile: Vector2i) -> void:
	if not status_registry.has(id): return
	if not status_registry[id].has(tile): return
	
	if entity in status_registry[id][tile]:
		status_registry[id][tile].erase(entity)
		if status_registry[id][tile].is_empty():
			status_registry[id].erase(tile)
			if status_registry[id].is_empty():
				status_registry.erase(id)

func update_spatial_status_position(id: String, entity: Node, old_tile: Vector2i, new_tile: Vector2i) -> void:
	unregister_spatial_status(id, entity, old_tile)
	register_spatial_status(id, entity, new_tile)

## --- CORE APPLICATION LOGIC ---

func apply_element(target: Node, element: ElementResource, source_attacker: Node = null, damage_snapshot: float = 0.0, units: int = 1, ignore_cd: bool = false) -> void:
	if not is_instance_valid(target) or not element: return
	
	if target.has_node("AbyssShell") and element.element_name.to_lower() != "abyss" and element.element_name.to_lower() != "asphyxiate":
		target = target.get_node("AbyssShell")
		
	var comp = null
	if "elemental_component" in target and target.elemental_component:
		comp = target.elemental_component
	else:
		comp = target.get_node_or_null("ElementalComponent")
	
	if not comp: return
	
	var incoming_id = element.element_name.to_lower()
	
	if not ignore_cd and comp.is_on_cooldown(incoming_id):
		return
	
	var final_cd = element.application_cooldown
	if ClassDB.class_exists("FormulaHelper") or ResourceLoader.exists("res://scripts/utils/formula_helper.gd"):
		var fh = load("res://scripts/utils/formula_helper.gd")
		if fh and element.cooldown_equation != "":
			var vars = {"base_cooldown": element.application_cooldown}
			for k in element.stat_weights.keys(): vars[k+"_weight"] = element.stat_weights[k]; vars[k] = target.get_stat(k, 0.0) if target.has_method("get_stat") else 0.0
			final_cd = fh.evaluate(element, element.cooldown_equation, vars, element.application_cooldown)

	comp.set_cooldown(incoming_id, final_cd)

	# Initialize dynamic catalyst extension step if this is a fresh application
	# This ensures any base element sets its initial extension scalar to its own duration
	if not comp.has_element(incoming_id):
		target.set_meta(incoming_id + "_ext_step", element.duration)
	
	var reaction_occurred = false
	var incoming_units_for_reaction = units 
	
	if ClassDB.class_exists("FormulaHelper") or ResourceLoader.exists("res://scripts/utils/formula_helper.gd"):
		var fh = load("res://scripts/utils/formula_helper.gd")
		if fh and element.unit_equation != "":
			var vars = {"base_units": units, "damage_snapshot": damage_snapshot}
			for k in element.stat_weights.keys(): vars[k+"_weight"] = element.stat_weights[k]; vars[k] = target.get_stat(k, 0.0) if target.has_method("get_stat") else 0.0
			incoming_units_for_reaction = int(fh.evaluate(element, element.unit_equation, vars, float(units)))
			
	var current_statuses = comp.get_active_element_names().duplicate()
	var aqua_units_before = 0
	if comp.has_element("aqua"):
		aqua_units_before = comp.get_active_data("aqua").units
	
	for active_id in current_statuses:
		var result_id = get_reaction_result(active_id, incoming_id)
		
		if result_id != "":
			var script_path = "res://scripts/elements/reactions/%s.gd" % result_id
			var reaction_script = load(script_path) if ResourceLoader.exists(script_path) else null
			
			var active_units = comp.get_active_data(active_id).units
			var reaction_strength = min(active_units, incoming_units_for_reaction)
			
			var active_consume = reaction_strength
			var incoming_consume = reaction_strength
			
			if reaction_script and reaction_script.has_method("get_catalysts"):
				var catalysts = reaction_script.get_catalysts()
				if active_id in catalysts: active_consume = 0
				if incoming_id in catalysts: incoming_consume = 0
				
				# Generic Data-Driven Duration Extension:
				# Any element identified as a catalyst in this specific reaction gets extended,
				# and sets up its next extension to be halved.
				for catalyst in catalysts:
					if comp.has_element(catalyst):
						var step = target.get_meta(catalyst + "_ext_step", 8.0)
						comp.active_statuses[catalyst].duration += step
						target.set_meta(catalyst + "_ext_step", step * 0.5)
			
			_trigger_reaction(target, active_id, incoming_id, result_id, source_attacker, damage_snapshot, reaction_strength, aqua_units_before)
			
			if comp.has_method("play_reaction_animation"):
				comp.play_reaction_animation(active_id, incoming_id, result_id)
			
			comp.consume_units(active_id, active_consume)
			
			reaction_occurred = true
			
			var result_res = get_element(result_id)
			if result_res:
				apply_element(target, result_res, source_attacker, damage_snapshot, reaction_strength, true)
			
			incoming_units_for_reaction -= incoming_consume
			if incoming_units_for_reaction <= 0:
				break
				
	if reaction_occurred and get_tree().root.has_node("GameManager"):
		var gm = get_tree().root.get_node("GameManager")
		if gm.get("vfx_manager"):
			gm.vfx_manager.play_vfx("y2k_reaction", target.global_position)
	
	if incoming_units_for_reaction > 0:
		var script_path = "res://scripts/elements/reactions/%s.gd" % incoming_id
		var handled_direct = false
		if ResourceLoader.exists(script_path):
			var direct_script = load(script_path)
			if direct_script and direct_script.has_method("apply_direct"):
				var arg_count = 3
				for m in direct_script.get_script_method_list():
					if m.name == "apply_direct":
						arg_count = m.args.size()
						break
						
				if arg_count >= 4:
					handled_direct = direct_script.apply_direct(target, source_attacker, incoming_units_for_reaction, damage_snapshot)
				else:
					handled_direct = direct_script.apply_direct(target, source_attacker, incoming_units_for_reaction)
				
		if not handled_direct:
			var is_aura = true
			if element.duration <= 0.1:
				is_aura = false
			if is_aura:
				comp.add_or_refresh_status(element, incoming_units_for_reaction)
			
	# Delay-propagate elements from host to proxy 1 second later
	if target.has_node("UndineComponent") and target.name != "UndineComponent":
		var undine = target.get_node("UndineComponent")
		var u_ref = undine
		var e_ref = element
		var s_ref = source_attacker
		var snap = damage_snapshot
		var u_val = units
		get_tree().create_timer(1.0).timeout.connect(func():
			if is_instance_valid(u_ref):
				var em = get_tree().root.get_node_or_null("ElementManager")
				if em:
					em.apply_element(u_ref, e_ref, s_ref, snap, u_val, true)
		)

func _trigger_reaction(target: Node, id_a: String, id_b: String, result_id: String, source: Node, dmg: float, reaction_units: int, aqua_units_before: int) -> void:
	if target is AbyssShellComponent:
		target.on_reaction()
	elif target.has_node("AbyssShell"):
		target.get_node("AbyssShell").on_reaction()
		
	if target is UndineComponent:
		target.on_reaction()
	elif target.has_node("UndineComponent"):
		target.get_node("UndineComponent").on_reaction()

	var res_element = get_element(result_id)
	var reaction_dmg = dmg
	if ClassDB.class_exists("FormulaHelper") or ResourceLoader.exists("res://scripts/utils/formula_helper.gd"):
		var fh = load("res://scripts/utils/formula_helper.gd")
		if fh and res_element and res_element.reaction_damage_equation != "":
			var vars = {"base_damage": dmg}
			reaction_dmg = fh.evaluate(res_element, res_element.reaction_damage_equation, vars, dmg)
			
	var ctx = {
		"id_a": id_a,
		"id_b": id_b,
		"damage": dmg,
		"reaction_damage": reaction_dmg,
		"reaction_units": reaction_units,
		"aqua_units_before": aqua_units_before
	}
	
	var script_path = "res://scripts/elements/reactions/%s.gd" % result_id
	if ResourceLoader.exists(script_path):
		var reaction_script = load(script_path)
		if reaction_script and reaction_script.has_method("execute"):
			reaction_script.execute(target, source, ctx)
		elif reaction_script and reaction_script.has_method("apply_direct"):
			var arg_count = 3
			for m in reaction_script.get_script_method_list():
				if m.name == "apply_direct":
					arg_count = m.args.size()
					break
			if arg_count >= 4:
				reaction_script.apply_direct(target, source, reaction_units, reaction_dmg)
			else:
				reaction_script.apply_direct(target, source, reaction_units)

## --- DAMAGE HOOK ---

func on_damage_dealt(victim: Node, amount: float, source: Node) -> void:
	if amount <= 0: return
	
	var victim_ec = null
	if "elemental_component" in victim: victim_ec = victim.elemental_component
	else: victim_ec = victim.get_node_or_null("ElementalComponent")
	
	if not victim_ec: return

	# Conduct Check
	if status_registry.has("conduct"):
		var victim_tile = LaneManager.world_to_tile(victim.global_position)
		var conduct_neighbors = _get_registered_neighbors(victim_tile, "conduct")
		
		for neighbor in conduct_neighbors:
			if is_instance_valid(neighbor) and neighbor != victim:
				if neighbor.has_node("HealthComponent"):
					neighbor.get_node("HealthComponent").take_damage_no_conduct(amount * 0.2, source)

## --- PUBLIC UTILITIES ---

func apply_chain_damage(start_node: Node, damage: float, source: Node, bounce_range: float, max_bounces: int, exclude_previous: bool = true, exclude_visited: bool = false) -> void:
	var current = start_node
	var previous = null
	var visited = {} 
	
	if exclude_visited:
		visited[start_node] = true
	
	for i in range(max_bounces):
		var neighbors = _get_neighbors_in_radius(current, bounce_range)
		var candidates =[]
		for n in neighbors:
			if not is_instance_valid(n): continue
			if n == current: continue
			if exclude_previous and n == previous: continue 
			if exclude_visited and visited.has(n): continue
			candidates.append(n)
			
		if candidates.is_empty():
			break
			
		candidates.sort_custom(func(a, b):
			return current.global_position.distance_squared_to(a.global_position) < \
				   current.global_position.distance_squared_to(b.global_position)
		)
		
		var next_target = candidates[0]
		
		if next_target.has_node("HealthComponent"):
			next_target.get_node("HealthComponent").take_damage_no_conduct(damage, source)
		elif next_target.has_method("take_damage_no_conduct"):
			next_target.take_damage_no_conduct(damage, source)
		
		if exclude_visited:
			visited[next_target] = true
			
		previous = current
		current = next_target

func apply_aoe_damage(center_node: Node, radius: float, damage: float, source: Node, falloff: bool = false, impulse: float = 0.0) -> void:
	var center_pos = center_node.global_position
	var victims = _get_neighbors_in_radius(center_node, radius)
	
	if is_instance_valid(center_node) and not victims.has(center_node):
		victims.append(center_node)
	
	for v in victims:
		if not is_instance_valid(v): continue
		
		var applied_damage = damage
		if falloff and radius > 0.0:
			var dist = center_pos.distance_to(v.global_position)
			var t = clamp(dist / radius, 0.0, 1.0)
			applied_damage = damage * (1.0 - t)
			
		if applied_damage > 0:
			if v.has_method("take_damage"):
				v.take_damage(applied_damage, null, source)
			elif v.has_node("HealthComponent"):
				v.get_node("HealthComponent").take_damage(applied_damage, null, source)
		
		if impulse > 0:
			var dir = (v.global_position - center_pos).normalized()
			dir.y = 0.5 
			if v.has_method("apply_impulse"):
				v.apply_impulse(dir.normalized() * impulse)
			elif v.has_node("EnemyMovementComponent"):
				v.get_node("EnemyMovementComponent").apply_displacement(dir.normalized() * impulse)

func get_closest_enemies_behind(reference_entity: Node, limit: int = 1) -> Array:
	if not is_instance_valid(reference_entity): return[]
	
	var target_lane = -1
	if reference_entity.has_method("get_lane_id"):
		target_lane = reference_entity.get_lane_id()
	
	if target_lane == -1: return[]

	var enemies = LaneManager.get_enemies_in_lane(target_lane)
	var ref_x = reference_entity.global_position.x
	var candidates =[]
	
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy == reference_entity: continue
		var ex = enemy.global_position.x
		if ex > ref_x: 
			var dist = ex - ref_x
			candidates.append({ "node": enemy, "dist": dist })
	
	candidates.sort_custom(func(a, b): return a.dist < b.dist)
	
	var result =[]
	for i in range(min(limit, candidates.size())):
		result.append(candidates[i].node)
		
	return result

func _get_neighbors_in_radius(center: Node, radius: float) -> Array:
	var found =[]
	var center_pos = center.global_position
	var tile = LaneManager.world_to_tile(center_pos)
	var r_int = int(ceil(radius))
	
	for x in range(-r_int, r_int + 1):
		for y in range(-r_int, r_int + 1):
			var t = tile + Vector2i(x, y)
			var enemies = LaneManager.get_enemies_at(t)
			for enemy in enemies:
				if is_instance_valid(enemy) and enemy != center:
					if center_pos.distance_squared_to(enemy.global_position) <= (radius * radius):
						found.append(enemy)
	return found

func _get_registered_neighbors(tile: Vector2i, status_id: String) -> Array:
	var found =[]
	if not status_registry.has(status_id): return found
	
	var registry = status_registry[status_id]
	for x in range(-1, 2):
		for y in range(-1, 2):
			var t = tile + Vector2i(x, y)
			if registry.has(t):
				found.append_array(registry[t])
	return found
