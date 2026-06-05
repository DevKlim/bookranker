class_name RainArea
extends Node3D

var tile: Vector2i
var timer: float = 30.0
var tick_timer: float = 2.0
var source: Node

func setup(p_tile: Vector2i, duration: float, p_source: Node) -> void:
	tile = p_tile
	timer = duration
	source = p_source
	
	global_position = LaneManager.tile_to_world(tile)
	
	var p = load("res://scenes/particles/rain_particles.tscn")
	if p:
		var inst = p.instantiate()
		add_child(inst)
		inst.position = Vector3(0, 5, 0)

func refresh(duration: float) -> void:
	timer = duration

func _process(delta: float) -> void:
	timer -= delta
	if timer <= 0:
		queue_free()
		return
		
	tick_timer -= delta
	if tick_timer <= 0:
		tick_timer = 2.0
		_apply_aqua()

func _apply_aqua() -> void:
	var enemies = LaneManager.get_enemies_at(tile)
	var em = get_tree().root.get_node_or_null("ElementManager")
	if not em: return
	
	var aqua_res = em.get_element("aqua")
	if not aqua_res: return
	
	# Prevent crash if the source was destroyed (e.g. boss died)
	var safe_source = source if is_instance_valid(source) else null
	
	for e in enemies:
		if is_instance_valid(e):
			em.apply_element(e, aqua_res, safe_source, 0.0, 1, true)
