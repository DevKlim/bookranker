extends Node3D

enum State { RISING, HOVERING, HOMING, FADING }

var target: Node3D
var source: Node
var start_pos: Vector3
var sky_pos: Vector3
var f_dmg: float
var units: int

var current_state: State = State.RISING
var wave_time: float = 0.0

var hover_timer: float = 0.5
var homing_dest: Vector3

@onready var visual = $Visual
@onready var trail = $Visual/Trail
@onready var anim_player = $AnimationPlayer
@onready var light = $Visual/Light

func setup(p_target: Node3D, p_source: Node, p_f_dmg: float, p_units: int, p_start_pos: Vector3) -> void:
	target = p_target
	source = p_source
	f_dmg = p_f_dmg
	units = p_units
	start_pos = p_start_pos
	
	sky_pos = start_pos + Vector3(randf_range(-2.0, 2.0), 5.0, randf_range(-2.0, 2.0))
	global_position = start_pos

func _ready() -> void:
	wave_time = randf() * 10.0 
	_build_animations()
	anim_player.play("spawn_color")

func _build_animations() -> void:
	var library = AnimationLibrary.new()
	
	var anim_color = Animation.new()
	anim_color.length = 1.0
	var t_color = anim_color.add_track(Animation.TYPE_VALUE)
	anim_color.track_set_path(t_color, "Visual:modulate")
	anim_color.track_insert_key(t_color, 0.0, Color(0.8, 0.8, 1.0, 0.6))
	anim_color.track_insert_key(t_color, 1.0, Color(0.2, 0.8, 1.0, 0.8))
	library.add_animation("spawn_color", anim_color)
	
	var anim_fade = Animation.new()
	anim_fade.length = 0.5
	var t_fade = anim_fade.add_track(Animation.TYPE_VALUE)
	anim_fade.track_set_path(t_fade, "Visual:modulate:a")
	anim_fade.track_insert_key(t_fade, 0.0, 0.8)
	anim_fade.track_insert_key(t_fade, 0.5, 0.0)
	
	var t_light = anim_fade.add_track(Animation.TYPE_VALUE)
	anim_fade.track_set_path(t_light, "Visual/Light:light_energy")
	anim_fade.track_insert_key(t_light, 0.0, 0.5)
	anim_fade.track_insert_key(t_light, 0.5, 0.0)
	
	library.add_animation("fade_out", anim_fade)
	
	anim_player.add_animation_library("", library)
	anim_player.animation_finished.connect(_on_anim_finished)

func _process(delta: float) -> void:
	if current_state == State.FADING: return

	wave_time += delta * 12.0
	visual.position = Vector3(sin(wave_time) * 0.3, cos(wave_time * 0.6) * 0.2, 0)
	
	# Explicit step-by-step physical processing. More reliable than Tweens!
	if current_state == State.RISING:
		global_position = global_position.move_toward(sky_pos, delta * 15.0)
		if global_position.distance_squared_to(sky_pos) < 0.1:
			current_state = State.HOVERING
			
	elif current_state == State.HOVERING:
		hover_timer -= delta
		if hover_timer <= 0:
			current_state = State.HOMING
			if is_instance_valid(target) and not target.get("is_dead"):
				homing_dest = target.global_position + Vector3(0, 0.5, 0)
			else:
				homing_dest = start_pos + Vector3(randf_range(-3, 3), 0.0, randf_range(-3, 3))
				
	elif current_state == State.HOMING:
		if is_instance_valid(target) and not target.get("is_dead"):
			homing_dest = target.global_position + Vector3(0, 0.5, 0)
			
		var dir = (homing_dest - global_position).normalized()
		if dir.length_squared() > 0.001:
			if abs(dir.y) < 0.99:
				look_at(global_position + dir, Vector3.UP)
			else:
				look_at(global_position + dir, Vector3.RIGHT)
				
		global_position = global_position.move_toward(homing_dest, delta * 18.0)
		
		if global_position.distance_squared_to(homing_dest) < 0.25:
			if is_instance_valid(target):
				_impact(target)
			else:
				_finish()

func _impact(t_node: Node3D) -> void:
	if current_state == State.FADING: return
	var safe_source = source if is_instance_valid(source) else null
	if t_node.has_method("take_damage_no_conduct"):
		t_node.take_damage_no_conduct(f_dmg, safe_source)
	elif t_node.has_node("HealthComponent"):
		t_node.get_node("HealthComponent").take_damage_no_conduct(f_dmg, safe_source)
		
	var em_node = get_tree().root.get_node_or_null("ElementManager")
	var ec_node = t_node.get_node_or_null("ElementalComponent")
	if em_node and ec_node:
		var ghost_res = em_node.get_element("ghost")
		if ghost_res:
			ec_node.add_or_refresh_status(ghost_res, units)
			
	_finish()

func _finish() -> void:
	if current_state == State.FADING: return
	current_state = State.FADING
	if trail: trail.emitting = false
	anim_player.play("fade_out")

func _on_anim_finished(anim_name: String) -> void:
	if anim_name == "fade_out":
		queue_free()
