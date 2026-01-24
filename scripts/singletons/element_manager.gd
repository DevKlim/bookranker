extends Node

## Manages elemental reactions and application logic.
## Handles Fuse (Cleanse + AoE), Conduct (Lightning Rod), and other complex reactions.

var elements: Dictionary = {}

# Spatial Registry for optimization: { "element_id": { Vector2i: [Node] } }
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
	if not status_registry[id].has(tile): status_registry[id][tile] = []
	
	if entity not in status_registry[id][tile]:
		status_registry[id][tile].append(entity)

func unregister_spatial_status(id: String, entity: Node, tile: Vector2i) -> void:
	if not status_registry.has(id): return
	if not status_registry[id].has(tile): return
	
	if entity in status_registry[id][tile]:
		status_registry[id][tile].erase(entity)
		# Clean up empty tiles
		if status_registry[id][tile].is_empty():
			status_registry[id].erase(tile)
			# Clean up empty IDs (OPTIMIZATION: Allows O(1) check if element exists spatially)
			if status_registry[id].is_empty():
				status_registry.erase(id)

func update_spatial_status_position(id: String, entity: Node, old_tile: Vector2i, new_tile: Vector2i) -> void:
	unregister_spatial_status(id, entity, old_tile)
	register_spatial_status(id, entity, new_tile)

## --- CORE APPLICATION LOGIC ---

func apply_element(target: Node, element: ElementResource, source_attacker: Node = null, damage_snapshot: float = 0.0, units: int = 1, ignore_cd: bool = false) -> void:
	if not is_instance_valid(target) or not element: return
	
	var comp = null
	if "elemental_component" in target and target.elemental_component:
		comp = target.elemental_component
	else:
		comp = target.get_node_or_null("ElementalComponent")
	
	if not comp: return
	
	var incoming_id = element.element_name.to_lower()
	
	if not ignore_cd and comp.is_on_cooldown(incoming_id):
		return
	
	comp.set_cooldown(incoming_id, element.application_cooldown)
	
	var reaction_occurred = false
	var incoming_units_for_reaction = units 
	var current_statuses = comp.get_active_element_names().duplicate()
	
	for active_id in current_statuses:
		var result_id = ""
		if element.reaction_rules.has(active_id):
			result_id = element.reaction_rules[active_id]
		
		if result_id == "":
			if not comp.has_element(active_id): continue
			var active_res = comp.get_active_data(active_id).resource
			if active_res.reaction_rules.has(incoming_id):
				result_id = active_res.reaction_rules[incoming_id]
		
		if result_id != "":
			var active_units = comp.get_active_data(active_id).units
			var reaction_strength = min(active_units, incoming_units_for_reaction)
			
			_trigger_reaction(target, active_id, incoming_id, result_id, source_attacker, damage_snapshot)
			
			comp.consume_units(active_id, reaction_strength)
			reaction_occurred = true
			
			var result_res = get_element(result_id)
			if result_res:
				apply_element(target, result_res, source_attacker, damage_snapshot, reaction_strength, true)
			
			incoming_units_for_reaction -= reaction_strength
			if incoming_units_for_reaction <= 0:
				break
	
	if incoming_units_for_reaction > 0 and not reaction_occurred:
		# Check for direct application of immediate-effect elements (like Fuse from a Bomb)
		if incoming_id == "fuse":
			_handle_fuse_reaction(target, source_attacker)
		else:
			comp.add_or_refresh_status(element, units)

func _trigger_reaction(target: Node, _id_a: String, _id_b: String, result_id: String, source: Node, _dmg: float) -> void:
	match result_id:
		"fuse": _handle_fuse_reaction(target, source)
		"extinguish": _handle_extinguish(target)
		"ground": _handle_ground(target)
		"tailwind": _handle_tailwind(target, _id_a, _id_b, source) 

## --- DAMAGE HOOK ---

func on_damage_dealt(victim: Node, amount: float, source: Node) -> void:
	if amount <= 0: return
	
	var victim_ec = null
	if "elemental_component" in victim: victim_ec = victim.elemental_component
	else: victim_ec = victim.get_node_or_null("ElementalComponent")
	
	if not victim_ec: return
	
	# 1. Ripple Check (Uses Generic Chain Logic)
	# Config: Range 2.0, Dmg 3.0, Max 4 bounces
	# Rule: exclude_previous=true (Standard Ripple), exclude_visited=false (Can revisit old targets)
	if victim_ec.has_element("ripple"):
		apply_chain_damage(victim, 3.0, source, 2.0, 4, true, false)

	# 2. Conduct Check (OPTIMIZED)
	if status_registry.has("conduct"):
		var victim_tile = LaneManager.world_to_tile(victim.global_position)
		var conduct_neighbors = _get_registered_neighbors(victim_tile, "conduct")
		
		for neighbor in conduct_neighbors:
			if is_instance_valid(neighbor) and neighbor != victim:
				if neighbor.has_node("HealthComponent"):
					neighbor.get_node("HealthComponent").take_damage_no_conduct(amount * 0.2, source)

## --- INTERNAL HANDLERS ---

## Modular function for chain/bounce reactions.
## @param start_node: The entity where the chain starts.
## @param damage: Fixed damage per bounce.
## @param source: The entity credited with damage.
## @param bounce_range: Search radius for the next target.
## @param max_bounces: Maximum number of hops.
## @param exclude_previous: If true, prevents bouncing immediately back to the node that just hit (A->B->A blocked).
## @param exclude_visited: If true, a node can only be hit once in the entire chain.
func apply_chain_damage(start_node: Node, damage: float, source: Node, bounce_range: float, max_bounces: int, exclude_previous: bool = true, exclude_visited: bool = false) -> void:
	var current = start_node
	var previous = null
	var visited = {} # Used only if exclude_visited is true
	
	if exclude_visited:
		visited[start_node] = true
	
	for i in range(max_bounces):
		# Find neighbors
		var neighbors = _get_neighbors_in_radius(current, bounce_range)
		
		# Filter valid next targets
		var candidates = []
		for n in neighbors:
			if not is_instance_valid(n): continue
			if n == current: continue
			
			# Logic Rule: Bounce Back Check
			if exclude_previous and n == previous: 
				continue 
			
			# Logic Rule: Unique Targets Check
			if exclude_visited and visited.has(n):
				continue
				
			candidates.append(n)
			
		if candidates.is_empty():
			break
			
		# Sort by distance (closest first) to simulate arcing/jumping
		candidates.sort_custom(func(a, b):
			return current.global_position.distance_squared_to(a.global_position) < \
				   current.global_position.distance_squared_to(b.global_position)
		)
		
		var next_target = candidates[0]
		
		# Deal Fixed Damage
		if next_target.has_node("HealthComponent"):
			next_target.get_node("HealthComponent").take_damage(damage, null, source)
		elif next_target.has_method("take_damage"):
			next_target.take_damage(damage, null, source)
		
		# Update State
		if exclude_visited:
			visited[next_target] = true
			
		previous = current
		current = next_target

func _handle_fuse_reaction(target: Node, source: Node) -> void:
	# Cleanse statuses for Fuse
	var ec = target.get_node_or_null("ElementalComponent")
	if ec: ec.remove_all_statuses()
	
	# Apply standard Fuse explosion (50 damage, 2.5 radius, 300 impulse) using generic AoE
	apply_aoe_damage(target, 2.5, 50.0, source, false, 300.0)

## New Generic AoE Function for modular reaction damage
func apply_aoe_damage(center_node: Node, radius: float, damage: float, source: Node, falloff: bool = false, impulse: float = 0.0) -> void:
	var center_pos = center_node.global_position
	# Fetch neighbors using existing optimized grid lookup
	var victims = _get_neighbors_in_radius(center_node, radius)
	
	# Ensure the center target is included if it exists (neighbor lookup might skip self)
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
		
		if impulse > 0 and v.has_method("apply_impulse"):
			var dir = (v.global_position - center_pos).normalized()
			dir.y = 0.5 # Add upward pop
			v.apply_impulse(dir.normalized() * impulse)

func _handle_extinguish(target: Node) -> void:
	var ec = target.get_node_or_null("ElementalComponent")
	if ec:
		ec.remove_status("igni")
		ec.remove_status("aqua")

func _handle_ground(target: Node) -> void:
	var ec = target.get_node_or_null("ElementalComponent")
	if ec: ec.remove_status("volt")

func _handle_tailwind(target: Node, id1: String, id2: String, source: Node) -> void:
	var ec = target.get_node_or_null("ElementalComponent")
	if ec: ec.remove_status("aero")
	
	var primitive_id = id1 if id1 != "aero" else id2
	if primitive_id == "aero": return
	
	var targets = get_closest_enemies_behind(target, 1)
	
	if not targets.is_empty():
		var primitive_res = get_element(primitive_id)
		for t in targets:
			if not is_instance_valid(t): continue
			if primitive_res:
				apply_element(t, primitive_res, source, 0.0, 1)
			if t.has_method("take_damage"):
				t.take_damage(5.0, null, source)
			elif t.has_node("HealthComponent"):
				t.get_node("HealthComponent").take_damage(5.0, null, source)

## --- PUBLIC UTILITIES ---

func get_closest_enemies_behind(reference_entity: Node, limit: int = 1) -> Array:
	if not is_instance_valid(reference_entity): return []
	
	var target_lane = -1
	if reference_entity.has_method("get_lane_id"):
		target_lane = reference_entity.get_lane_id()
	
	if target_lane == -1: return []

	var enemies = LaneManager.get_enemies_in_lane(target_lane)
	var ref_x = reference_entity.global_position.x
	var candidates = []
	
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy == reference_entity: continue
		var ex = enemy.global_position.x
		if ex > ref_x: 
			var dist = ex - ref_x
			candidates.append({ "node": enemy, "dist": dist })
	
	candidates.sort_custom(func(a, b): return a.dist < b.dist)
	
	var result = []
	for i in range(min(limit, candidates.size())):
		result.append(candidates[i].node)
		
	return result

func _get_neighbors_in_radius(center: Node, radius: float) -> Array:
	var found = []
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
	var found = []
	if not status_registry.has(status_id): return found
	
	var registry = status_registry[status_id]
	for x in range(-1, 2):
		for y in range(-1, 2):
			var t = tile + Vector2i(x, y)
			if registry.has(t):
				found.append_array(registry[t])
	return found
