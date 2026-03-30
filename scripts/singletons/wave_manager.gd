extends Node

## Manages wave data and enemy spawning logic.
## Injected by GameManager from the active level config.

signal wave_started(wave_index)
signal wave_ended
signal wave_cleared

var waves_config: Array =[]
var waves_dict: Dictionary = {}

var current_wave_idx: int = -1
var active_enemies: Array =[]
var active_bosses: Array =[]
var is_wave_active: bool = false
var _spawning_done: bool = false
var _wave_has_bosses: bool = false
var _active_spawning_groups: int = 0
var _spawning_sequence_finished: bool = false

# Dictionary to cache loaded EnemyResources
var enemy_cache: Dictionary = {}

func _ready() -> void:
	pass

func _process(_delta: float) -> void:
	if is_wave_active and _spawning_done:
		# Clean up nulls and fallen entities from active enemies
		for i in range(active_enemies.size() - 1, -1, -1):
			var e = active_enemies[i]
			if not is_instance_valid(e) or e.is_queued_for_deletion():
				active_enemies.remove_at(i)
			elif e.global_position.y < -15.0:
				e.queue_free()
				active_enemies.remove_at(i)
				
		for i in range(active_bosses.size() - 1, -1, -1):
			var b = active_bosses[i]
			if not is_instance_valid(b) or b.is_queued_for_deletion():
				active_bosses.remove_at(i)
			elif b.global_position.y < -15.0:
				b.queue_free()
				active_bosses.remove_at(i)
				
		var wave_clear_condition_met = false
		if _wave_has_bosses:
			wave_clear_condition_met = active_bosses.is_empty()
		else:
			wave_clear_condition_met = active_enemies.is_empty()
			
		if wave_clear_condition_met:
			_spawning_done = false
			stop_wave()
			emit_signal("wave_cleared")

func load_waves_from_config(waves: Array) -> void:
	waves_config = waves
	waves_dict.clear()
	for w in waves:
		var id = w.get("id", "")
		if id != "":
			waves_dict[id] = w
	print("WaveManager: Loaded %d waves from level config." % waves_config.size())

func get_total_waves() -> int:
	return waves_config.size()

func get_wave_by_id(id: String) -> Dictionary:
	return waves_dict.get(id, {})

func get_wave_by_index(index: int) -> Dictionary:
	if index >= 0 and index < waves_config.size():
		return waves_config[index]
	return {}

func start_wave_data(wave_data: Dictionary, display_index: int) -> void:
	if is_wave_active:
		print("WaveManager: Wave already active.")
		return

	current_wave_idx = display_index
	is_wave_active = true
	_spawning_done = false
	_spawning_sequence_finished = false
	_wave_has_bosses = false
	active_bosses.clear()
	emit_signal("wave_started", display_index + 1)
	
	var groups = wave_data.get("groups",[])
	
	print("WaveManager: Starting Wave %d..." % (display_index + 1))
	
	if LaneManager.spawners_by_lane.is_empty() and LaneManager.num_lanes <= 0:
		printerr("WaveManager: No spawners or lanes detected! Cannot spawn enemies.")
		_spawning_done = true
		return

	_active_spawning_groups = 0
	_run_wave_sequence(groups)

func start_wave(index: int) -> void:
	var wave = get_wave_by_index(index)
	if wave.is_empty():
		printerr("WaveManager: Invalid wave index %d" % index)
		# Fallback to clear instantly so game doesn't softlock
		_spawning_done = true 
		is_wave_active = true
		return
	start_wave_data(wave, index)

func stop_wave() -> void:
	is_wave_active = false
	# Clear active enemies immediately
	for e in active_enemies:
		if is_instance_valid(e) and not e.is_queued_for_deletion():
			e.queue_free()
	active_enemies.clear()
	active_bosses.clear()
	emit_signal("wave_ended")

func _run_wave_sequence(groups: Array) -> void:
	_active_spawning_groups = 0
	_spawning_sequence_finished = false
	
	if groups.is_empty():
		_spawning_sequence_finished = true
		_check_spawning_done()
		return
		
	for group in groups:
		if not is_wave_active: break
		
		var g_type = group.get("type", "spawn")
		if g_type == "pause":
			var duration = group.get("duration", 1.0)
			if duration > 0:
				await get_tree().create_timer(duration).timeout
		else:
			_active_spawning_groups += 1
			_spawn_group(group)
			
	_spawning_sequence_finished = true
	_check_spawning_done()

func _spawn_group(group: Dictionary) -> void:
	var enemy_id = group.get("enemy_id", "")
	var total_count = group.get("count", 1)
	var interval = group.get("interval", 1.0)
	var interval_max = group.get("interval_max", interval)
	var is_boss = group.get("is_boss", false)
	if is_boss: _wave_has_bosses = true
	var spawn_lane = group.get("spawn_lane", "random")
	var capacity = group.get("capacity", -1)
	
	var res = _get_enemy_resource(enemy_id)
	if not res:
		printerr("WaveManager: Enemy resource not found for '%s'" % enemy_id)
		_active_spawning_groups -= 1
		_check_spawning_done()
		return
		
	var spawned = 0
	var active_in_group =[]
	
	while spawned < total_count:
		if not is_wave_active: break
		
		# Clean up dead entities from tracked group
		for i in range(active_in_group.size() - 1, -1, -1):
			if not is_instance_valid(active_in_group[i]) or active_in_group[i].is_queued_for_deletion():
				active_in_group.remove_at(i)
				
		# Respect capacity cap
		if capacity > 0 and active_in_group.size() >= capacity:
			await get_tree().create_timer(0.5).timeout
			continue
			
		var enemy = _spawn_single_with_lane(res, spawn_lane, is_boss)
		if enemy:
			active_in_group.append(enemy)
			
		spawned += 1
		
		if spawned < total_count:
			var wait_time = randf_range(interval, interval_max)
			if wait_time > 0:
				await get_tree().create_timer(wait_time).timeout
				
	_active_spawning_groups -= 1
	_check_spawning_done()

func _check_spawning_done() -> void:
	if _spawning_sequence_finished and _active_spawning_groups <= 0 and is_wave_active:
		_spawning_done = true

func _spawn_single_with_lane(res: EnemyResource, spawn_lane: Variant, is_boss: bool) -> Node:
	var num_lanes = LaneManager.num_lanes
	if num_lanes <= 0: return null
	
	var available_lanes = range(num_lanes)
	var chosen_lane = available_lanes[0]
	
	if typeof(spawn_lane) == TYPE_STRING:
		if spawn_lane == "center":
			chosen_lane = num_lanes / 2
		else:
			chosen_lane = available_lanes.pick_random()
	elif typeof(spawn_lane) == TYPE_FLOAT or typeof(spawn_lane) == TYPE_INT:
		chosen_lane = int(spawn_lane)
		if not available_lanes.has(chosen_lane):
			chosen_lane = available_lanes.pick_random()
			
	var spawn_pos = Vector3.ZERO
	if LaneManager.spawners_by_lane.has(chosen_lane):
		spawn_pos = LaneManager.spawners_by_lane[chosen_lane]
		spawn_pos.y = max(spawn_pos.y, 1.0) # Elevated to prevent floor intersecting immediately on spawn
	else:
		var tile = Vector2i(LaneManager.LANE_LENGTH - 1 + LaneManager.generation_offset.x, chosen_lane + LaneManager.generation_offset.y)
		spawn_pos = LaneManager.tile_to_world(tile)
		spawn_pos.y = 1.0 
		
	return _spawn_enemy(res, chosen_lane, spawn_pos, is_boss)

func _spawn_enemy(res: EnemyResource, lane_id: int, spawn_pos: Vector3, is_boss: bool = false) -> Node:
	if not res.scene: return null
	
	var enemy = res.scene.instantiate()
	if enemy is Enemy:
		var container = get_tree().current_scene.get_node_or_null("Enemies")
		if container:
			container.add_child(enemy)
		else:
			get_tree().current_scene.add_child(enemy)
		
		# Position
		enemy.global_position = spawn_pos
		
		# Pathfinding
		var path = LaneManager.get_path_for_enemy(lane_id, spawn_pos)
		enemy.set_path(path)
		
		# Stats
		enemy.initialize_from_resource(res)
		
		# Override their mode to wave enemy so they walk straight down the lane and do not use field AStar logic
		enemy.set_as_wave_enemy()
		
		# Tracking
		active_enemies.append(enemy)
		if is_boss:
			active_bosses.append(enemy)
			enemy.tree_exiting.connect(func(): if active_bosses.has(enemy): active_bosses.erase(enemy))
			
		enemy.tree_exiting.connect(func(): if active_enemies.has(enemy): active_enemies.erase(enemy))
		return enemy
		
	return null

func _get_enemy_resource(id: String) -> EnemyResource:
	if enemy_cache.has(id): return enemy_cache[id]
	var path = "res://resources/enemies/%s.tres" % id
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is EnemyResource:
			enemy_cache[id] = res
			return res
	return null
