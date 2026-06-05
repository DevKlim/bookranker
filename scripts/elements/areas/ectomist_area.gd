class_name EctomistArea
extends Node3D

var tile: Vector2i
var timer: float = 8.0
var source: Node
var dmg_amp: float = 10.0
var _affected_enemies: Array[Node] =[]

func setup(p_tile: Vector2i, p_source: Node) -> void:
	tile = p_tile
	source = p_source
	
	if is_instance_valid(source) and source.has_method("get_stat"):
		dmg_amp = (source.get_stat("lux_stat", 0.0) * 0.5) + 10.0
		
	global_position = LaneManager.tile_to_world(tile)
	
	var p = load("res://scenes/particles/ectomist_particles.tscn")
	if p:
		var inst = p.instantiate()
		add_child(inst)
		inst.position.y = 1.0

func _process(delta: float) -> void:
	timer -= delta
	if timer <= 0:
		_cleanup_metas()
		queue_free()
		return
		
	var lm = get_tree().root.get_node_or_null("LaneManager")
	if not lm: return
	
	var current_enemies: Array[Node] =[]
	for x in range(-1, 2):
		for y in range(-1, 2):
			var t = tile + Vector2i(x, y)
			var enemies = lm.get_enemies_at(t)
			for e in enemies:
				if is_instance_valid(e):
					current_enemies.append(e)
			
	for e in current_enemies:
		if not _affected_enemies.has(e):
			_affected_enemies.append(e)
			e.set_meta("ectomist_vulnerability", dmg_amp)
			
			var em = get_tree().root.get_node_or_null("ElementManager")
			var ec = e.get_node_or_null("ElementalComponent")
			if em and ec:
				var ghost = em.get_element("ghost")
				if ghost:
					# Apply as aura purely, prevents ghost from popping endlessly inside fog
					ec.add_or_refresh_status(ghost, 1)
					
	for i in range(_affected_enemies.size() - 1, -1, -1):
		var e = _affected_enemies[i]
		if not is_instance_valid(e):
			_affected_enemies.remove_at(i)
		elif not current_enemies.has(e):
			if e.has_meta("ectomist_vulnerability"):
				e.remove_meta("ectomist_vulnerability")
			_affected_enemies.remove_at(i)

func _cleanup_metas() -> void:
	for e in _affected_enemies:
		if is_instance_valid(e) and e.has_meta("ectomist_vulnerability"):
			e.remove_meta("ectomist_vulnerability")
	_affected_enemies.clear()

func _exit_tree() -> void:
	_cleanup_metas()
