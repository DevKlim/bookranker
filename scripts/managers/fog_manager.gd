class_name FogManager extends Node

var lm: Node
var current_fog_depth: int = -1
var fog_volume: FogVolume

func setup(lane_manager: Node) -> void:
	lm = lane_manager
	process_mode = Node.PROCESS_MODE_ALWAYS # Ensure fog can animate while game is paused
	
	fog_volume = FogVolume.new()
	fog_volume.size = Vector3(200, 20, 200)
	
	var mat = FogMaterial.new()
	mat.density = 5.0 
	mat.albedo = Color(0.95, 0.95, 0.95)
	mat.emission = Color(0.02, 0.02, 0.03)
	mat.edge_fade = 5.0
	fog_volume.material = mat
	add_child(fog_volume)
	
	fog_volume.global_position = Vector3(1000, 10, 0)
	
	# Use is_instance_valid for GDScript Autoloads (Engine.has_singleton is for C++ modules)
	if is_instance_valid(GameManager):
		GameManager.state_changed.connect(_on_state_changed)
	if is_instance_valid(WaveManager):
		WaveManager.wave_cleared.connect(_on_wave_cleared)

func _on_state_changed(new_state) -> void:
	if new_state == GameManager.GameState.DAY_PLANNING or new_state == GameManager.GameState.NIGHT_WAVE:
		_update_fog_for_current_phase()

func _on_wave_cleared() -> void:
	# Call deferred ensures wave integer increments before we read it
	call_deferred("_update_fog_for_current_phase")

func _update_fog_for_current_phase() -> void:
	var wave_idx = 0
	if is_instance_valid(GameManager):
		wave_idx = GameManager.game_data.get("wave", 1) - 1
		
	var phases =[]
	if is_instance_valid(GameManager):
		phases = GameManager.current_level_config.get("day_phases",[])
		
	if wave_idx >= 0 and wave_idx < phases.size():
		var phase_data = phases[wave_idx]
		if typeof(phase_data) == TYPE_DICTIONARY and phase_data.has("fog_depth"):
			set_fog_depth(int(phase_data.get("fog_depth")))

func set_fog_depth(depth: int) -> void:
	if current_fog_depth == depth: return
	
	current_fog_depth = depth
	var target_x = lm.tile_to_world(Vector2i(depth, 0)).x
	# Fog volume center adjusted to smother entirely forward 
	var final_pos = Vector3(target_x + 100.0 - 5.0, 0, (lm.num_lanes * lm.GRID_SCALE) / 2.0)
	
	if is_instance_valid(GameManager) and GameManager.current_state == GameManager.GameState.IDLE:
		fog_volume.global_position = final_pos
	else:
		var tween = create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS) # Allow movement backwards during the shop pause!
		tween.tween_property(fog_volume, "global_position", final_pos, 3.0).set_trans(Tween.TRANS_SINE)
	
	for lane in range(lm.num_lanes):
		var spawn_tile = Vector2i(depth, lane + lm.generation_offset.y)
		lm.spawners_by_lane[lane] = lm.tile_to_world(spawn_tile)
