class_name FogManager extends Node

var lm: Node
var current_fog_depth: int = -1
var fog_volume: FogVolume
var fog_volume_rear: FogVolume

func setup(lane_manager: Node) -> void:
	lm = lane_manager
	process_mode = Node.PROCESS_MODE_ALWAYS # Ensure fog can animate while game is paused
	
	# Material for the front moving fog
	var mat_front = FogMaterial.new()
	mat_front.density = 5.0 
	mat_front.albedo = Color(0.95, 0.95, 0.95)
	mat_front.emission = Color(0.02, 0.02, 0.03)
	mat_front.edge_fade = 5.0
	
	# Material strictly for the rear boundary fog
	var mat_rear = FogMaterial.new()
	mat_rear.density = 5.0
	mat_rear.albedo = Color(0.0, 0.0, 0.0) # Absolute darkness
	mat_rear.emission = Color(0.0, 0.0, 0.0)
	mat_rear.edge_fade = 5.0
	
	# 1. Front dynamic fog (Progresses forward with waves)
	fog_volume = FogVolume.new()
	fog_volume.size = Vector3(200, 20, 200)
	fog_volume.material = mat_front
	add_child(fog_volume)
	fog_volume.global_position = Vector3(1000, 1.0, 0)
	
	# 2. Rear static fog (Permanently covers X=-50 to X=-5 to frame the Core base)
	fog_volume_rear = FogVolume.new()
	# Huge Z size to make it extend infinitely side-to-side
	fog_volume_rear.size = Vector3(200, 20, 100) 
	fog_volume_rear.material = mat_rear
	add_child(fog_volume_rear)
	fog_volume_rear.global_position = Vector3(-105.0, 1.0, (lm.num_lanes * lm.GRID_SCALE) / 2.0)
	
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
	var middle_z = (lm.num_lanes * lm.GRID_SCALE) / 2.0
	
	# Rear fog re-centering in case lanes were dynamically added
	if is_instance_valid(fog_volume_rear):
		fog_volume_rear.global_position = Vector3(-105.0, 1.0, middle_z)
	
	# Fog volume center adjusted to smother entirely forward
	# Raised Y coordinate ensures consistency with the blocks generating below
	var final_pos = Vector3(target_x + 100.0 - 5.0, 1.0, middle_z)
	
	if is_instance_valid(GameManager) and GameManager.current_state == GameManager.GameState.IDLE:
		fog_volume.global_position = final_pos
	else:
		var tween = create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS) # Allow movement backwards during the shop pause!
		tween.tween_property(fog_volume, "global_position", final_pos, 3.0).set_trans(Tween.TRANS_SINE)
	
	for lane in range(lm.num_lanes):
		var spawn_tile = Vector2i(depth, lane + lm.generation_offset.y)
		lm.spawners_by_lane[lane] = lm.tile_to_world(spawn_tile)
