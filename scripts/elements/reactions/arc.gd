extends RefCounted

static func get_catalysts() -> Array:
	return ["channel"]

class ArcChainHandler extends Node:
	var current_target: Node
	var max_bounces: int
	var current_bounce: int = 0
	var bounce_dmg: float
	var source: Node
	var max_range: float
	var em: Node
	var visited: Dictionary = {}
	var channel_units: int
	var bounce_cooldown: float = 0.4
	
	func _ready() -> void:
		visited[current_target] = true
		_do_bounce()
		
	func _do_bounce() -> void:
		if current_bounce >= max_bounces or not is_instance_valid(current_target):
			queue_free()
			return
			
		var neighbors = em._get_neighbors_in_radius(current_target, max_range)
		var candidates = []
		for n in neighbors:
			if not is_instance_valid(n) or n == current_target or visited.has(n): continue
			var ec = n.get_node_or_null("ElementalComponent")
			if ec and (ec.has_element("aqua") or ec.has_element("magne") or ec.has_element("channel")):
				candidates.append(n)
				
		if candidates.is_empty():
			queue_free()
			return
			
		candidates.sort_custom(func(a, b): return current_target.global_position.distance_squared_to(a.global_position) < current_target.global_position.distance_squared_to(b.global_position))
		var next_target = candidates[0]
		
		# Safely handle the source in case the attacker died while the arc was bouncing
		var safe_source = source if is_instance_valid(source) else null
		
		if next_target.has_node("HealthComponent"):
			next_target.get_node("HealthComponent").take_damage_no_conduct(bounce_dmg, safe_source)
		elif next_target.has_method("take_damage_no_conduct"):
			next_target.take_damage_no_conduct(bounce_dmg, safe_source)
			
		var channel_res = em.get_element("channel")
		if channel_res and next_target.has_node("ElementalComponent"):
			next_target.get_node("ElementalComponent").add_or_refresh_status(channel_res, channel_units)
			
		if em.get_tree().root.has_node("GameManager"):
			var gm = em.get_tree().root.get_node("GameManager")
			if gm.get("vfx_manager"):
				var scene_root = em.get_tree().current_scene
				var arc_scene = load("res://scenes/particles/arc_bounce.tscn")
				if arc_scene:
					var arc_inst = arc_scene.instantiate()
					scene_root.add_child(arc_inst)
					arc_inst.setup(current_target.global_position + Vector3(0,0.5,0), next_target.global_position + Vector3(0,0.5,0))
					
		visited[next_target] = true
		current_target = next_target
		current_bounce += 1
		
		get_tree().create_timer(bounce_cooldown).timeout.connect(_do_bounce)

static func apply_direct(target: Node, source: Node, units: int, dmg: float) -> bool:
	var lux = 0.0
	if is_instance_valid(source) and source.has_method("get_stat"):
		lux = source.get_stat("networking", 0.0)

	var range_tiles = max(int(sqrt(lux + units)), 2)
	var max_bounces = max(int(sqrt(lux + units)), 3)
	var bounce_dmg = (dmg + units) * ((lux + 10.0) / 100.0)

	var em = target.get_tree().root.get_node_or_null("ElementManager")
	if em:
		var handler = ArcChainHandler.new()
		handler.current_target = target
		handler.max_bounces = max_bounces
		handler.bounce_dmg = bounce_dmg
		handler.source = source
		handler.max_range = range_tiles * 2.0
		handler.em = em
		handler.channel_units = units
		em.add_child(handler)
		
	return true
