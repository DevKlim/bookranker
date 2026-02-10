extends Node

## Central manager for global game state, recipe database, and unlocks.
## Also manages natural field spawning of enemies.

enum GameState {
	IDLE,
	PRE_WAVE,
	WAVE_IN_PROGRESS,
	POST_WAVE
}

var current_state: GameState = GameState.IDLE

var game_data: Dictionary = {
	"wave": 0,
	"currency": 0
}

var _recipes: Array[RecipeResource] = []
var _field_enemies: Array[EnemyResource] = []
var _field_spawn_timers: Dictionary = {} # { "enemy_id": float (time_accumulator) }
var _active_field_spawns: Dictionary = {} # { "enemy_id": int (count) }

func _ready() -> void:
	_load_field_enemies()

func _process(delta: float) -> void:
	_process_field_spawns(delta)

func reset_state() -> void:
	_recipes.clear()
	game_data = { "wave": 0, "currency": 0 }
	current_state = GameState.IDLE
	
	# Re-initialize field spawn counters
	_active_field_spawns.clear()
	_field_spawn_timers.clear()
	for res in _field_enemies:
		_active_field_spawns[res.resource_path] = 0
		_field_spawn_timers[res.resource_path] = 0.0

func register_recipes(list: Array[RecipeResource]) -> void:
	_recipes = list

func get_available_recipes() -> Array[RecipeResource]:
	return _recipes

# --- Field Spawning Logic ---

func _load_field_enemies() -> void:
	_field_enemies.clear()
	_active_field_spawns.clear()
	_field_spawn_timers.clear()
	
	var dir_path = "res://resources/enemies/"
	var dir = DirAccess.open(dir_path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".tres"):
				var full_path = dir_path + file_name
				if ResourceLoader.exists(full_path):
					var res = load(full_path) as EnemyResource
					if res and res.is_field_enemy:
						_field_enemies.append(res)
						_field_spawn_timers[res.resource_path] = 0.0
						_active_field_spawns[res.resource_path] = 0
			file_name = dir.get_next()
	print("GameManager: Loaded %d field enemy resources." % _field_enemies.size())

func _process_field_spawns(delta: float) -> void:
	if current_state == GameState.WAVE_IN_PROGRESS: 
		# Optional: Pause natural spawns during waves? For now, we let them coexist.
		pass
		
	for enemy_res in _field_enemies:
		var id = enemy_res.resource_path
		
		# Check spawn limit
		if _active_field_spawns.get(id, 0) >= enemy_res.max_field_spawns:
			continue
			
		if not _field_spawn_timers.has(id):
			_field_spawn_timers[id] = 0.0
			
		_field_spawn_timers[id] += delta
		
		if _field_spawn_timers[id] >= enemy_res.field_spawn_interval:
			_field_spawn_timers[id] = 0.0
			if randf() <= enemy_res.field_spawn_chance:
				_try_spawn_field_enemy(enemy_res)

func _try_spawn_field_enemy(res: EnemyResource) -> void:
	if not res.scene: return
	
	# Determine valid position
	# Safe buffer = 10 blocks away from furthest building
	var spawn_pos = LaneManager.get_valid_field_spawn_pos(res.field_spawn_min_depth, res.field_spawn_max_depth, 10)
	
	if spawn_pos == Vector3.ZERO:
		return 
	
	# ADJUST HEIGHT: Spawn at a safe height (0.5) to prevent immediate floor collision
	spawn_pos.y = 0.5 
		
	var enemy = res.scene.instantiate()
	if enemy is Enemy:
		var container = get_tree().current_scene.get_node_or_null("Enemies")
		if not container: container = get_tree().current_scene
		
		container.add_child(enemy)
		enemy.global_position = spawn_pos
		enemy.initialize_from_resource(res)
		
		var id = res.resource_path
		
		if not _active_field_spawns.has(id):
			_active_field_spawns[id] = 0
			
		_active_field_spawns[id] += 1
		
		enemy.tree_exiting.connect(func(): 
			if _active_field_spawns.has(id): 
				_active_field_spawns[id] -= 1
				if _active_field_spawns[id] < 0: _active_field_spawns[id] = 0
		)
