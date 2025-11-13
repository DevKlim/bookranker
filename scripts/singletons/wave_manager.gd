extends Node

## Manages the spawning of enemy waves using Enemy Resources.

signal wave_started(wave_number)
signal wave_cleared(wave_number)

# References to scene nodes
var _tile_map: TileMapLayer
var _enemies_container: Node2D

# This array will be populated by loading all EnemyResource files.
var _enemy_types: Array[EnemyResource] = []

# Hardcoded tile coordinates for the 5 lanes on the top-right path
var _lane_definitions: Array[Dictionary] = [
	{"start": Vector2i(14, -39), "end": Vector2i(-1, -9)},
	{"start": Vector2i(15, -38), "end": Vector2i(0, -8)},
	{"start": Vector2i(15, -37), "end": Vector2i(0, -7)},
	{"start": Vector2i(16, -36), "end": Vector2i(1, -6)},
	{"start": Vector2i(16, -35), "end": Vector2i(1, -5)},
]

var wave_number: int = 0
var enemies_remaining: int = 0
var _enemies_to_spawn_this_wave: int = 0
var _spawn_timer: Timer


func _ready() -> void:
	print("WaveManager Initialized.")
	_spawn_timer = Timer.new()
	_spawn_timer.one_shot = false
	_spawn_timer.wait_time = 0.5
	_spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(_spawn_timer)
	
	call_deferred("_initialize")


func _initialize() -> void:
	var main_scene = get_tree().current_scene
	if main_scene:
		_tile_map = main_scene.get_node_or_null("TileMapLayer")
		_enemies_container = main_scene.get_node_or_null("Enemies")
	
	if not is_instance_valid(_tile_map):
		printerr("WaveManager could not find 'TileMapLayer' node.")
	if not is_instance_valid(_enemies_container):
		printerr("WaveManager could not find 'Enemies' node.")
		
	_load_enemy_types()


## Automatically loads all .tres files from the enemy resources folder.
func _load_enemy_types() -> void:
	var dir = DirAccess.open("res://resources/enemies")
	if not dir:
		printerr("Could not open directory res://resources/enemies. No enemies will spawn.")
		return
	
	for file_name in dir.get_files():
		if file_name.ends_with(".tres"):
			var resource = load("res://resources/enemies/" + file_name)
			if resource is EnemyResource:
				_enemy_types.append(resource)
	
	print("WaveManager loaded %d enemy types." % _enemy_types.size())


func start_wave() -> void:
	if GameManager.current_state == GameManager.GameState.WAVE_IN_PROGRESS:
		print("WaveManager: A wave is already in progress.")
		return

	if _enemy_types.is_empty() or not is_instance_valid(_tile_map):
		printerr("WaveManager: Cannot start wave. No enemy types loaded or scene setup is incorrect.")
		return

	wave_number += 1
	_enemies_to_spawn_this_wave = 5 + (wave_number * 2)
	enemies_remaining = _enemies_to_spawn_this_wave
	
	GameManager.current_state = GameManager.GameState.WAVE_IN_PROGRESS
	emit_signal("wave_started", wave_number)
	print("Wave %d started. Spawning %d enemies." % [wave_number, enemies_remaining])
	_spawn_timer.start()


func stop_wave() -> void:
	if GameManager.current_state != GameManager.GameState.WAVE_IN_PROGRESS:
		return
		
	_spawn_timer.stop()
	for enemy in _enemies_container.get_children():
		enemy.queue_free()
		
	enemies_remaining = 0
	_enemies_to_spawn_this_wave = 0
	GameManager.current_state = GameManager.GameState.PRE_WAVE
	print("Wave %d stopped by user." % wave_number)


func _on_spawn_timer_timeout() -> void:
	if _enemies_to_spawn_this_wave > 0:
		_spawn_enemy()
		_enemies_to_spawn_this_wave -= 1
	else:
		_spawn_timer.stop()
		print("All enemies for wave %d have been spawned." % wave_number)


func _spawn_enemy() -> void:
	var enemy_resource = _enemy_types.pick_random()
	if not enemy_resource or not enemy_resource.scene:
		printerr("WaveManager: Invalid EnemyResource selected for spawning.")
		return
		
	var lane_index = randi() % _lane_definitions.size()
	var lane_def = _lane_definitions[lane_index]
	var start_pos = _tile_map.map_to_local(lane_def.start)
	var end_pos = _tile_map.map_to_local(lane_def.end)
	
	var enemy_instance: CharacterBody2D = enemy_resource.scene.instantiate()
	_enemies_container.add_child(enemy_instance)
	
	enemy_instance.initialize(enemy_resource, start_pos, end_pos, lane_index)
	enemy_instance.died.connect(on_enemy_defeated)


func on_enemy_defeated() -> void:
	enemies_remaining -= 1
	
	if enemies_remaining <= 0 and _spawn_timer.is_stopped():
		emit_signal("wave_cleared", wave_number)
		GameManager.current_state = GameManager.GameState.PRE_WAVE
		print("Wave %d cleared! Ready for next wave." % wave_number)