extends Node

## Manages wave data and enemy spawning logic.
## Injected by GameManager from the active level config.

signal wave_started(wave_index)
signal wave_ended
signal wave_cleared

var waves_config: Array =[]
var current_wave_idx: int = -1
var active_enemies: Array =[]
var active_bosses: Array =[]
var is_wave_active: bool = false
var _spawning_done: bool = false
var _wave_has_bosses: bool = false

# Dictionary to cache loaded EnemyResources
var enemy_cache: Dictionary = {}

func _ready() -> void:
	pass

func _process(_delta: float) -> void:
	if is_wave_active and _spawning_done:
		# Clean up nulls from active enemies
		for i in range(active_enemies.size() - 1, -1, -1):
			if not is_instance_valid(active_enemies[i]) or active_enemies[i].is_queued_for_deletion():
				active_enemies.remove_at(i)
				
		for i in range(active_bosses.size() - 1, -1, -1):
			if not is_instance_valid(active_bosses[i]) or active_bosses[i].is_queued_for_deletion():
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
	print("WaveManager: Loaded %d waves from level config." % waves_config.size())

func get_total_waves() -> int:
	return waves_config.size()

func start_wave(index: int) -> void:
	if index < 0 or index >= waves_config.size():
		printerr("WaveManager: Invalid wave index %d" % index)
		# Fallback to clear instantly so game doesn't softlock
		_spawning_done = true 
		is_wave_active = true
		return
	
	if is_wave_active:
		print("WaveManager: Wave already active.")
		return

	current_wave_idx = index
	is_wave_active = true
	_spawning_done = false
	_wave_has_bosses = false
	active_bosses.clear()
	emit_signal("wave_started", index + 1)
	
	var wave_data = waves_config[index]
	var groups = wave_data.get("groups",[])
	
	print("WaveManager: Starting Wave %d..." % (index + 1))
	
	if LaneManager.spawners_by_lane.is_empty():
		printerr("WaveManager: No spawners detected! Cannot spawn enemies.")
		_spawning_done = true
		return

	# Start processing groups
	_run_wave_sequence(groups)

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
	for group in groups:
		if not is_wave_active: break
		
		var enemy_id = group.get("enemy_id", "")
		var count = group.get("count", 1)
		var interval = group.get("interval", 1.0)
		var is_boss = group.get("is_boss", false)
		if is_boss: _wave_has_bosses = true
		var spawn_lane = group.get("spawn_lane", "random")
		
		var res = _get_enemy_resource(enemy_id)
		if not res:
			printerr("WaveManager: Enemy resource not found for '%s'" % enemy_id)
			continue
			
		# Spawn 'count' enemies, one by one, with 'interval' delay
		for i in range(count):
			if not is_wave_active: break
			
			_spawn_single_with_lane(res, spawn_lane, is_boss)
			
			if interval > 0:
				await get_tree().create_timer(interval).timeout
				
	if is_wave_active:
		_spawning_done = true

func _spawn_single_with_lane(res: EnemyResource, spawn_lane: Variant, is_boss: bool) -> void:
	var lanes = LaneManager.spawners_by_lane.keys()
	if lanes.is_empty(): return
	
	var chosen_lane = lanes[0]
	if typeof(spawn_lane) == TYPE_STRING:
		if spawn_lane == "center":
			var sorted_lanes = lanes.duplicate()
			sorted_lanes.sort()
			chosen_lane = sorted_lanes[sorted_lanes.size() / 2]
		else:
			chosen_lane = lanes.pick_random()
	elif typeof(spawn_lane) == TYPE_FLOAT or typeof(spawn_lane) == TYPE_INT:
		chosen_lane = int(spawn_lane)
		if not lanes.has(chosen_lane):
			chosen_lane = lanes.pick_random()
			
	var spawn_pos = LaneManager.spawners_by_lane[chosen_lane]
	_spawn_enemy(res, chosen_lane, spawn_pos, is_boss)

func _spawn_enemy(res: EnemyResource, lane_id: int, spawn_pos: Vector3, is_boss: bool = false) -> void:
	if not res.scene: return
	
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

func _get_enemy_resource(id: String) -> EnemyResource:
	if enemy_cache.has(id): return enemy_cache[id]
	var path = "res://resources/enemies/%s.tres" % id
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is EnemyResource:
			enemy_cache[id] = res
			return res
	return null
