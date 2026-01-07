extends Node

## Manages the spawning of enemy waves defined in data/waves.json.

signal wave_started(wave_index)
signal wave_cleared(wave_index)

# References
var _enemies_container: Node3D

# Data
var _enemy_registry: Dictionary = {} # Map "id" -> EnemyResource
var _waves_config: Array = [] # Array of Dictionary (Wave Data)

# State
var current_wave_index: int = 0 # 0-based index matching _waves_config array
var enemies_alive: int = 0
var is_wave_active: bool = false
var _abort_wave: bool = false

func _ready() -> void:
	call_deferred("_initialize")

func _initialize() -> void:
	var main_scene = get_tree().current_scene
	if main_scene:
		_enemies_container = main_scene.get_node_or_null("Enemies")
	
	if not _enemies_container:
		printerr("WaveManager: 'Enemies' node not found in Main scene.")
		
	_load_enemy_registry()
	_load_waves_config()
	print("WaveManager: Initialized with %d waves and %d enemy types." % [_waves_config.size(), _enemy_registry.size()])

func _load_enemy_registry() -> void:
	_enemy_registry.clear()
	var dir_path = "res://resources/enemies"
	var dir = DirAccess.open(dir_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var res = load(dir_path + "/" + file_name)
				if res is EnemyResource:
					# Use filename as ID (e.g. "basic_robot.tres" -> "basic_robot")
					var id = file_name.get_basename()
					_enemy_registry[id] = res
			file_name = dir.get_next()
	else:
		printerr("WaveManager: Could not open resources/enemies.")

func _load_waves_config() -> void:
	var file = FileAccess.open("res://data/waves.json", FileAccess.READ)
	if file:
		var json = JSON.new()
		var error = json.parse(file.get_as_text())
		if error == OK:
			var data = json.get_data()
			if data.has("waves"):
				_waves_config = data["waves"]
		else:
			printerr("WaveManager: Failed to parse waves.json.")
	else:
		printerr("WaveManager: waves.json not found.")

## Starts a specific wave by index (0-based).
func start_wave(index: int) -> void:
	if is_wave_active:
		print("WaveManager: Wave already in progress.")
		return
		
	if index < 0 or index >= _waves_config.size():
		printerr("WaveManager: Invalid wave index %d." % index)
		return

	current_wave_index = index
	var wave_data = _waves_config[index]
	
	GameManager.current_state = GameManager.GameState.WAVE_IN_PROGRESS
	is_wave_active = true
	_abort_wave = false
	enemies_alive = 0
	
	emit_signal("wave_started", current_wave_index + 1) # Display as 1-based
	print("WaveManager: Starting Wave %d (ID: %s)" % [current_wave_index + 1, wave_data.get("id")])
	
	_spawn_wave_routine(wave_data)

## Stops the current wave and clears enemies.
func stop_wave() -> void:
	if not is_wave_active: return
	
	_abort_wave = true
	is_wave_active = false
	
	if is_instance_valid(_enemies_container):
		for child in _enemies_container.get_children():
			child.queue_free()
			
	enemies_alive = 0
	GameManager.current_state = GameManager.GameState.PRE_WAVE
	print("WaveManager: Wave stopped manually.")

# Correction for wave completion logic
var _spawning_finished: bool = false

func _spawn_wave_routine(wave_data: Dictionary) -> void:
	_spawning_finished = false
	var groups = wave_data.get("groups", [])
	
	for group in groups:
		if _abort_wave: return
		
		var enemy_id = group.get("enemy_id", "")
		var count = group.get("count", 0)
		var interval = group.get("interval", 1.0)
		
		if not _enemy_registry.has(enemy_id):
			printerr("WaveManager: Unknown enemy_id '%s'" % enemy_id)
			continue
			
		var res = _enemy_registry[enemy_id]
		
		for i in range(count):
			if _abort_wave: return
			
			_spawn_enemy(res)
			
			# Wait interval
			await get_tree().create_timer(interval).timeout

	_spawning_finished = true
	# Finished spawning all groups. Check immediately in case everything died already.
	if enemies_alive == 0:
		_complete_wave()
	else:
		print("WaveManager: All enemies spawned for Wave %d. Waiting for clear." % (current_wave_index + 1))

func _spawn_enemy(res: EnemyResource) -> void:
	if not res.scene: return
	
	# Determine Spawn Point
	var start_pos = Vector3.ZERO
	var lane_id = -1
	
	# 1. Check for Map Spawners (Debug GridMap)
	if not LaneManager.spawn_points.is_empty():
		start_pos = LaneManager.spawn_points.pick_random()
		
		# Attempt to detect lane from spawn position
		var tile = LaneManager.world_to_tile(start_pos)
		var estimated_lane = tile.y - LaneManager.generation_offset.y
		# Verify if this matches a valid lane index
		if estimated_lane >= 0 and estimated_lane < LaneManager.NUM_LANES:
			lane_id = estimated_lane
		else:
			lane_id = -1 # Free roam
			
	# 2. Fallback to Lane Paths
	elif not LaneManager.lane_paths.keys().is_empty():
		lane_id = LaneManager.lane_paths.keys().pick_random()
		start_pos = LaneManager.get_lane_end_world_pos(lane_id)
	else:
		printerr("WaveManager: No spawn points available.")
		return
		
	var enemy = res.scene.instantiate()
	if not enemy is CharacterBody3D:
		printerr("WaveManager: Enemy scene root is not CharacterBody3D. Skipping.")
		enemy.queue_free()
		return
		
	_enemies_container.add_child(enemy)
	enemies_alive += 1
	
	if enemy.has_method("initialize"):
		enemy.initialize(res, start_pos, lane_id)
		enemy.died.connect(_on_enemy_died)

func _on_enemy_died() -> void:
	enemies_alive -= 1
	if enemies_alive <= 0 and _spawning_finished and is_wave_active and not _abort_wave:
		_complete_wave()

func _complete_wave() -> void:
	if not is_wave_active: return
	is_wave_active = false
	GameManager.current_state = GameManager.GameState.POST_WAVE
	emit_signal("wave_cleared", current_wave_index + 1)
	print("WaveManager: Wave %d Cleared!" % (current_wave_index + 1))

func get_total_waves() -> int:
	return _waves_config.size()
