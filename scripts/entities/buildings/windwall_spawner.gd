extends BaseBuilding

func _ready():
	super._ready()
	# Ensure we don't spawn the moving wall while simply holding/previewing the building
	if has_meta("is_preview"): return
	# Detach from grid because we are spawning a moving entity and deleting the static building structure
	call_deferred("_spawn_wall")

func _spawn_wall():
	if get_tree().root.has_node("GameManager"):
		var gm = get_tree().root.get_node("GameManager")
		if gm.get("vfx_manager"):
			gm.vfx_manager.play_vfx("fold_craft", global_position)
			
	var wall = load("res://scripts/entities/windwall_entity.gd").new()
	get_tree().current_scene.add_child(wall)
	wall.global_position = global_position
	
	var fwd = Vector3.FORWARD
	match output_direction:
		Direction.DOWN: fwd = Vector3(0,0,1)
		Direction.LEFT: fwd = Vector3(-1,0,0)
		Direction.UP: fwd = Vector3(0,0,-1)
		Direction.RIGHT: fwd = Vector3(1,0,0)
		   
	wall.initialize(fwd)
	
	if grid_component:
		var tile = LaneManager.world_to_tile(global_position)
		LaneManager.unregister_entity(tile, "building")
		
	queue_free()
