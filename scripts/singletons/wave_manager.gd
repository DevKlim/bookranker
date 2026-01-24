extends Node

## Manages wave data and enemy spawning logic.
## Reads configuration from 'res://data/waves.json'.

signal wave_started(wave_index)
signal wave_ended
signal wave_cleared

var waves_config: Array = []
var current_wave_idx: int = -1
var active_enemies: Array = []
var is_wave_active: bool = false

# Dictionary to cache loaded EnemyResources
var enemy_cache: Dictionary = {}

func _ready() -> void:
	_load_waves_config()

func _load_waves_config() -> void:
	var file = FileAccess.open("res://data/waves.json", FileAccess.READ)
	if not file:
		printerr("WaveManager: Could not open waves.json")
		return
	
	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	if err == OK:
		var data = json.data
		if data.has("waves"):
			waves_config = data["waves"]
			print("WaveManager: Loaded %d waves." % waves_config.size())
	else:
		printerr("WaveManager: JSON Parse Error: ", json.get_error_message())

func get_total_waves() -> int:
	return waves_config.size()

func start_wave(index: int) -> void:
	if index < 0 or index >= waves_config.size():
		printerr("WaveManager: Invalid wave index %d" % index)
		return
	
	if is_wave_active:
		print("WaveManager: Wave already active.")
		return

	current_wave_idx = index
	is_wave_active = true
	emit_signal("wave_started", index + 1)
	
	var wave_data = waves_config[index]
	var groups = wave_data.get("groups", [])
	
	print("WaveManager: Starting Wave %d..." % (index + 1))
	
	if LaneManager.spawners_by_lane.is_empty():
		printerr("WaveManager: No spawners detected! Cannot spawn enemies.")
		stop_wave()
		return

	# Start processing groups
	_run_wave_sequence(groups)

func stop_wave() -> void:
	is_wave_active = false
	# Clear active enemies immediately
	for e in active_enemies:
		if is_instance_valid(e):
			e.queue_free()
	active_enemies.clear()
	emit_signal("wave_ended")

func _run_wave_sequence(groups: Array) -> void:
	for group in groups:
		if not is_wave_active: break
		
		var enemy_id = group.get("enemy_id", "")
		var count = group.get("count", 1)
		var interval = group.get("interval", 1.0)
		
		var res = _get_enemy_resource(enemy_id)
		if not res:
			printerr("WaveManager: Enemy resource not found for '%s'" % enemy_id)
			continue
			
		# Spawn 'count' enemies, one by one, with 'interval' delay
		for i in range(count):
			if not is_wave_active: break
			
			_spawn_single_random(res)
			
			if interval > 0:
				await get_tree().create_timer(interval).timeout
	
	# Note: Wave doesn't auto-end here; it usually waits for enemies to die.
	# For now, we leave it active until manually stopped or logic added for clear condition.

func _spawn_single_random(res: EnemyResource) -> void:
	# Pick ONE random lane from available spawners
	var lanes = LaneManager.spawners_by_lane.keys()
	if lanes.is_empty(): return
	
	var random_lane = lanes.pick_random()
	var spawn_pos = LaneManager.spawners_by_lane[random_lane]
	
	_spawn_enemy(res, random_lane, spawn_pos)

func _spawn_enemy(res: EnemyResource, lane_id: int, spawn_pos: Vector3) -> void:
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
		
		# Tracking
		active_enemies.append(enemy)
		enemy.tree_exiting.connect(func(): active_enemies.erase(enemy))

func _get_enemy_resource(id: String) -> EnemyResource:
	if enemy_cache.has(id): return enemy_cache[id]
	var path = "res://resources/enemies/%s.tres" % id
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is EnemyResource:
			enemy_cache[id] = res
			return res
	return null
