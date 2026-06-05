extends BaseBuilding

enum State { IDLE, CHARGING, CHARGE_IDLE, ATTACKING }
var current_state: State = State.IDLE

var life_timer: float = 25.0
var anim_player: AnimationPlayer

var attack_cooldown: float = 2.0
var timer: float = 0.0

var active_attack_dir: String = ""

func _ready():
	grid_layer = "addon"
	if has_meta("is_preview"):
		return
		
	super._ready()
	call_deferred("_verify_placement")

	var export_node = get_node_or_null("MystapusModel")
	if export_node:
		anim_player = _find_anim_player(export_node)
		
	_ensure_animations_exist()
	
	if anim_player:
		anim_player.animation_finished.connect(_on_anim_finished)
		anim_player.play("idle")
		
	is_active = true

func _find_anim_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer: return node
	for child in node.get_children():
		var found = _find_anim_player(child)
		if found: return found
	return null

func _verify_placement():
	var tile = LaneManager.world_to_tile(global_position)
	var b = LaneManager.get_entity_at(tile, "building")
	if not b or not b.is_in_group("stream"):
		queue_free()
		
func _ensure_animations_exist():
	if not anim_player: return
	var lib: AnimationLibrary = null
	if anim_player.has_animation_library(""):
		lib = anim_player.get_animation_library("")
	else:
		lib = AnimationLibrary.new()
		anim_player.add_animation_library("", lib)
		
	# Inject empty dummy animations so the state machine operates safely
	var req_anims = ["idle", "charges", "charge_idle", "attack_forward", "attack_left", "attack_right"]
	for anim_name in req_anims:
		if not lib.has_animation(anim_name):
			var anim = Animation.new()
			anim.length = 2.5
			lib.add_animation(anim_name, anim)
			
	# Enforce looping for idle states
	if anim_player.has_animation("idle"):
		anim_player.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
	if anim_player.has_animation("charge_idle"):
		anim_player.get_animation("charge_idle").loop_mode = Animation.LOOP_LINEAR

func _physics_process(delta):
	super._physics_process(delta)
	life_timer -= delta
	if life_timer <= 0:
		queue_free()
		return
		
	match current_state:
		State.IDLE:
			timer -= delta
			if timer <= 0:
				current_state = State.CHARGING
				if anim_player: anim_player.play("charges")
				
		State.CHARGE_IDLE:
			var target_dir = _check_for_enemies()
			if target_dir != "":
				current_state = State.ATTACKING
				active_attack_dir = target_dir
				if anim_player: anim_player.play("attack_" + target_dir)
				
				# Delayed damage trigger mimicking the animation strike frame
				get_tree().create_timer(0.4).timeout.connect(_apply_smash_damage)

func _get_valid_enemies() -> Array[Node]:
	var valid_enemies: Array[Node] = []
	if is_instance_valid(LaneManager):
		for lane_array in LaneManager.enemies_by_lane.values():
			for e in lane_array:
				if is_instance_valid(e) and not e.get("is_dead"):
					valid_enemies.append(e)
					
	if valid_enemies.is_empty():
		var all_enemies = get_tree().get_nodes_in_group("enemies")
		for e in all_enemies:
			if is_instance_valid(e) and not e.get("is_dead"):
				valid_enemies.append(e)
				
	return valid_enemies

func _check_for_enemies() -> String:
	var my_tile = LaneManager.world_to_tile(global_position)
	var fwd_tile = Vector2i.ZERO
	match output_direction:
		Direction.DOWN: fwd_tile = Vector2i(0, 1)
		Direction.LEFT: fwd_tile = Vector2i(-1, 0)
		Direction.UP: fwd_tile = Vector2i(0, -1)
		Direction.RIGHT: fwd_tile = Vector2i(1, 0)
		
	var dirs = {
		"forward": fwd_tile,
		"left": Vector2i(fwd_tile.y, -fwd_tile.x),
		"right": Vector2i(-fwd_tile.y, fwd_tile.x)
	}
	
	var valid_enemies = _get_valid_enemies()
	
	for dir_name in dirs.keys():
		var dir_vec = dirs[dir_name]
		for dist in range(1, 3):
			var check_tile = my_tile + (dir_vec * dist)
			
			for e in valid_enemies:
				var e_tile = LaneManager.world_to_tile(e.global_position)
				if e_tile == check_tile:
					return dir_name
					
	return ""

func _on_anim_finished(anim_name: String):
	if anim_name == "charges":
		current_state = State.CHARGE_IDLE
		if anim_player and anim_player.has_animation("charge_idle"):
			anim_player.play("charge_idle")
	elif anim_name.begins_with("attack_"):
		current_state = State.IDLE
		timer = attack_cooldown
		if anim_player and anim_player.has_animation("idle"):
			anim_player.play("idle")

func _apply_smash_damage():
	if not is_inside_tree() or current_state != State.ATTACKING: return
	
	var fwd = Vector3.FORWARD
	match output_direction:
		Direction.DOWN: fwd = Vector3(0,0,1)
		Direction.LEFT: fwd = Vector3(-1,0,0)
		Direction.UP: fwd = Vector3(0,0,-1)
		Direction.RIGHT: fwd = Vector3(1,0,0)
		
	var attack_vec = fwd
	if active_attack_dir == "left": attack_vec = Vector3(fwd.z, 0, -fwd.x)
	elif active_attack_dir == "right": attack_vec = Vector3(-fwd.z, 0, fwd.x)
		
	var valid_enemies = _get_valid_enemies()
	var hit_enemies = {}
	var dmg = 8.0
	var aqua = ElementManager.get_element("aqua")
		
	for dist in range(1, 3):
		var hit_pos = global_position + attack_vec * (LaneManager.GRID_SCALE * dist)
		var hit_flat = Vector2(hit_pos.x, hit_pos.z)
		
		if get_tree().root.has_node("GameManager"):
			var gm = get_tree().root.get_node("GameManager")
			if gm.get("vfx_manager"):
				gm.vfx_manager.play_vfx("mystapus_splash", hit_pos)
		
		for e in valid_enemies:
			if hit_enemies.has(e): continue
			
			var e_flat = Vector2(e.global_position.x, e.global_position.z)
			if e_flat.distance_to(hit_flat) <= LaneManager.GRID_SCALE * 0.8:
				if e.has_method("take_damage"): e.take_damage(dmg, aqua, self)
				ElementManager.apply_element(e, aqua, self, dmg, 2)
				hit_enemies[e] = true
