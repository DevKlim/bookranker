extends Node

## Central manager for global game state, recipe database, and unlocks.
## Also manages natural field spawning of enemies and Day/Night progression.
## Expanded to handle Roguelike Meta-Progression and Run Data.

enum GameState {
	IDLE,
	DAY_PLANNING,
	NIGHT_WAVE,
	LEVEL_COMPLETE
}

signal state_changed(new_state)
signal time_updated(time_left, is_day)
signal run_data_changed
signal shop_requested(wave_index)

var current_state: GameState = GameState.IDLE
var current_level_config: Dictionary = {}
var current_scene_id: String = ""
var random_events_config: Array =[]

var game_data: Dictionary = {
	"level": 1,
	"wave": 1,
	"max_waves": 3,
	"currency": 0,
	"explored_depth": 15
}

# Roguelike Run Foundation
var run_data: Dictionary = {
	"artifacts":[],
	"global_stat_multipliers": {},
	"meta_currency": 0
}

var day_timer: float = 0.0
var day_duration: float = 300.0 # 5 minutes planning by default

var _recipes: Array[RecipeResource] =[]
var _field_enemies: Array =[] # Array of Dictionaries {resource: EnemyResource, config: Dictionary}
var _field_spawn_timers: Dictionary = {} 
var _active_field_spawns: Dictionary = {} 

var event_manager: Node

func _ready() -> void:
	event_manager = load("res://scripts/singletons/event_manager.gd").new()
	event_manager.name = "EventManager"
	add_child(event_manager)
	
	load_level(1)
	WaveManager.wave_cleared.connect(_on_wave_cleared)
	# Deferred to ensure PlayerManager finishes initializing its inventory first
	call_deferred("_connect_inventory")

func _connect_inventory() -> void:
	if PlayerManager.game_inventory:
		PlayerManager.game_inventory.inventory_changed.connect(_on_inventory_changed)

func _on_inventory_changed() -> void:
	emit_signal("run_data_changed")

func load_level(level_num: int) -> void:
	var path = "res://data/levels/level_%d.json" % level_num
	if FileAccess.file_exists(path):
		var file = FileAccess.open(path, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			current_level_config = json.data
			print("GameManager: Loaded level config for Level ", level_num)
	
	game_data["level"] = level_num
	game_data["wave"] = 1
	game_data["currency"] = current_level_config.get("starting_currency", 0)
	day_duration = current_level_config.get("day_duration", 300.0)
	current_scene_id = current_level_config.get("scene_id", "")
	random_events_config = current_level_config.get("random_events",[])
	
	if current_scene_id != "":
		print("GameManager: Level represents scene -> ", current_scene_id)
	
	_setup_field_enemies()
	
	if WaveManager:
		WaveManager.load_waves_from_config(current_level_config.get("waves",[]))
		var phases = current_level_config.get("day_phases",[])
		if not phases.is_empty():
			game_data["max_waves"] = phases.size()
		else:
			game_data["max_waves"] = WaveManager.get_total_waves()
	
	call_deferred("_grant_starting_items")
	call_deferred("_initial_shop_prompt")

func _initial_shop_prompt() -> void:
	# Wait for 1 frame so items are registered into inventory before shop requests values
	await get_tree().process_frame
	emit_signal("shop_requested", 0)

func _grant_starting_items() -> void:
	if current_level_config.has("starting_items"):
		for item_data in current_level_config["starting_items"]:
			var res_path = "res://resources/items/%s.tres" % item_data["id"]
			if ResourceLoader.exists(res_path):
				PlayerManager.game_inventory.add_item(load(res_path), item_data.get("count", 1))
				
	var start_byts = current_level_config.get("starting_currency", 0)
	if start_byts > 0:
		add_currency(start_byts)

func _process(delta: float) -> void:
	if current_state == GameState.DAY_PLANNING:
		day_timer -= delta
		emit_signal("time_updated", max(0, day_timer), true)
		if day_timer <= 0:
			start_night_phase()

	_process_field_spawns(delta)

# --- Roguelike ECS Systems ---

func add_artifact(artifact: ArtifactResource) -> void:
	if not artifact: return
	run_data["artifacts"].append(artifact)
	
	for stat in artifact.stat_multipliers.keys():
		if not run_data["global_stat_multipliers"].has(stat):
			run_data["global_stat_multipliers"][stat] = 1.0
		# Multiplicative stacking for roguelike elements
		run_data["global_stat_multipliers"][stat] *= artifact.stat_multipliers[stat]
		
	emit_signal("run_data_changed")

func get_stat_multiplier(stat_name: String) -> float:
	return run_data["global_stat_multipliers"].get(stat_name, 1.0)

func get_global_stat(stat_name: String, default_val: float = 0.0) -> float:
	return run_data["global_stat_multipliers"].get(stat_name, default_val)

func set_global_stat(stat_name: String, val: float) -> void:
	run_data["global_stat_multipliers"][stat_name] = val
	emit_signal("run_data_changed")

# --- Currency System ---

func get_currency() -> int:
	var byt_res = load("res://resources/items/byt.tres")
	if not byt_res: return game_data.get("currency", 0)
	var total = 0
	for slot in PlayerManager.game_inventory.slots:
		if slot and slot.item == byt_res:
			total += slot.count
	return total

func add_currency(amount: int) -> void:
	var byt_res = load("res://resources/items/byt.tres")
	if byt_res:
		PlayerManager.game_inventory.add_item(byt_res, amount)
	else:
		game_data["currency"] += amount
	emit_signal("run_data_changed")

func spend_currency(amount: int) -> bool:
	if get_currency() >= amount:
		var byt_res = load("res://resources/items/byt.tres")
		if byt_res:
			PlayerManager.game_inventory.remove_item(byt_res, amount)
		else:
			game_data["currency"] -= amount
		emit_signal("run_data_changed")
		return true
	return false

# --- Pools / Events ---

func get_item_pool(pool_name: String) -> Array:
	var pools = current_level_config.get("item_pools", {})
	if pools.has(pool_name):
		return pools[pool_name]
	return[]

func pick_from_weighted_pool(pool: Array) -> Dictionary:
	if pool.is_empty(): return {}
	var total_weight = 0.0
	for entry in pool:
		total_weight += float(entry.get("weight", 1.0))
	var roll = randf() * total_weight
	for entry in pool:
		var w = float(entry.get("weight", 1.0))
		if roll <= w:
			return entry
		roll -= w
	return pool.back()

func trigger_event(event_id: String) -> void:
	if event_manager:
		event_manager.trigger_event(event_id)

# --- Game Flow ---

func start_day_phase() -> void:
	current_state = GameState.DAY_PLANNING
	
	var phases = current_level_config.get("day_phases", [])
	var w_idx = game_data["wave"] - 1
	if w_idx >= 0 and w_idx < phases.size():
		var phase_data = phases[w_idx]
		if typeof(phase_data) == TYPE_DICTIONARY:
			day_duration = float(phase_data.get("duration", 300.0))
		else:
			day_duration = float(phase_data)
	else:
		day_duration = current_level_config.get("day_duration", 300.0)
		
	day_timer = day_duration
	emit_signal("state_changed", current_state)
	print("GameManager: Day Planning Started. Level %d, Wave %d" % [game_data["level"], game_data["wave"]])

func start_night_phase() -> void:
	current_state = GameState.NIGHT_WAVE
	emit_signal("state_changed", current_state)
	emit_signal("time_updated", 0.0, false)
	print("GameManager: Night Wave Started!")
	
	var wave_index = game_data["wave"] - 1
	var wave_to_play: Dictionary = {}
	var event_to_play: String = ""
	
	var phases = current_level_config.get("day_phases",[])
	if wave_index >= 0 and wave_index < phases.size():
		var phase_data = phases[wave_index]
		if typeof(phase_data) == TYPE_DICTIONARY:
			var pool_name = phase_data.get("pool", "")
			if pool_name != "":
				var pools = current_level_config.get("wave_pools", {})
				if pools.has(pool_name):
					var pool = pools[pool_name]
					var pick = pick_from_weighted_pool(pool)
					if pick:
						wave_to_play = WaveManager.get_wave_by_id(pick.get("wave_id", ""))
						event_to_play = pick.get("event_id", "")
	
	if wave_to_play.is_empty():
		var max_idx = WaveManager.get_total_waves() - 1
		var safe_idx = clamp(wave_index, 0, max_idx)
		if safe_idx >= 0:
			wave_to_play = WaveManager.get_wave_by_index(safe_idx)
			
	if not wave_to_play.is_empty():
		if event_to_play != "":
			trigger_event(event_to_play)
		WaveManager.start_wave_data(wave_to_play, wave_index)

func _on_wave_cleared() -> void:
	if current_state == GameState.NIGHT_WAVE:
		print("GameManager: Wave %d Cleared!" % game_data["wave"])
		game_data["wave"] += 1
		
		if game_data["wave"] > game_data["max_waves"]:
			current_state = GameState.LEVEL_COMPLETE
			emit_signal("state_changed", current_state)
			print("GameManager: Level %d Complete! Configure export." % game_data["level"])
		else:
			emit_signal("shop_requested", game_data["wave"] - 1)

func reset_state() -> void:
	_recipes.clear()
	game_data = { "level": 1, "wave": 1, "max_waves": 3, "currency": 0, "explored_depth": 15 }
	run_data["artifacts"].clear()
	run_data["global_stat_multipliers"].clear()
	current_state = GameState.IDLE
	
	_active_field_spawns.clear()
	_field_spawn_timers.clear()
	if event_manager:
		event_manager.clear_active_events()
	
	for entry in _field_enemies:
		var id = entry["config"]["id"]
		_active_field_spawns[id] = 0
		_field_spawn_timers[id] = 0.0

func register_recipes(list: Array[RecipeResource]) -> void:
	_recipes = list

func get_available_recipes() -> Array[RecipeResource]:
	return _recipes

func end_game(player_won: bool) -> void:
	current_state = GameState.IDLE
	print("Game Ended. Player Won: ", player_won)

func _setup_field_enemies() -> void:
	_field_enemies.clear()
	_active_field_spawns.clear()
	_field_spawn_timers.clear()
	
	var f_enemies = current_level_config.get("field_enemies",[])
	for e_config in f_enemies:
		var res_path = "res://resources/enemies/%s.tres" % e_config["id"]
		if ResourceLoader.exists(res_path):
			var res = load(res_path) as EnemyResource
			if res:
				_field_enemies.append({
					"resource": res,
					"config": e_config
				})
				_active_field_spawns[e_config["id"]] = 0
				_field_spawn_timers[e_config["id"]] = 0.0

func _process_field_spawns(delta: float) -> void:
	if current_state == GameState.NIGHT_WAVE: 
		pass
		
	for entry in _field_enemies:
		var res = entry["resource"]
		var config = entry["config"]
		var id = config["id"]
		
		if _active_field_spawns.get(id, 0) >= config.get("max_spawns", 5):
			continue
			
		_field_spawn_timers[id] += delta
		
		if _field_spawn_timers[id] >= config.get("spawn_interval", 10.0):
			_field_spawn_timers[id] = 0.0
			if randf() <= config.get("spawn_chance", 0.5):
				_try_spawn_field_enemy(res, config)

func _try_spawn_field_enemy(res: EnemyResource, config: Dictionary) -> void:
	if not res.scene: return
	var spawn_pos = LaneManager.get_valid_field_spawn_pos(config.get("min_depth", 15), config.get("max_depth", 60), 10)
	
	if spawn_pos == Vector3.ZERO:
		return 
	
	spawn_pos.y = 0.5 
		
	var enemy = res.scene.instantiate()
	if enemy is Enemy:
		var container = get_tree().current_scene.get_node_or_null("Enemies")
		if not container: container = get_tree().current_scene
		
		container.add_child(enemy)
		enemy.global_position = spawn_pos
		enemy.initialize_from_resource(res, config)
		
		var id = config["id"]
		_active_field_spawns[id] += 1
		
		enemy.tree_exiting.connect(func(): 
			if _active_field_spawns.has(id): 
				_active_field_spawns[id] -= 1
				if _active_field_spawns[id] < 0: _active_field_spawns[id] = 0
		)

