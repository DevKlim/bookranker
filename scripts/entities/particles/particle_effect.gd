class_name ParticleEffect
extends Node3D

@export var dynamic_direction: bool = false
@export var base_speed_min: float = 1.0
@export var base_speed_max: float = 3.0

var _emitters: Array[Node] = []
var _lights: Array[Light3D] = []
var _light_start_energies: Array[float] =[]
var _finished_count: int = 0
var _destroy_on_finish: bool = true
var _max_lifetime: float = 0.0
var _timer: float = 0.0

func _ready() -> void:
	var has_anim = false
	var anim = get_node_or_null("AnimationPlayer")
	if anim:
		has_anim = true
		anim.animation_finished.connect(func(_name):
			_finished_count += 1
			_check_destroy()
		)
		_emitters.append(anim)

	for child in get_children():
		if child is GPUParticles3D:
			_emitters.append(child)
			if child.lifetime > _max_lifetime:
				_max_lifetime = child.lifetime
			if child.one_shot:
				child.finished.connect(_on_emitter_finished)
			else:
				_destroy_on_finish = false
			child.emitting = true
			
		elif child is Light3D:
			_lights.append(child)
			_light_start_energies.append(child.light_energy)
			
	if _emitters.is_empty() and _destroy_on_finish:
		queue_free()

func _process(delta: float) -> void:
	if _max_lifetime > 0.0 and _lights.size() > 0:
		_timer += delta
		var t = clamp(_timer / _max_lifetime, 0.0, 1.0)
		var fade_curve = 1.0 - pow(t, 3.0) 
		
		for i in range(_lights.size()):
			if is_instance_valid(_lights[i]):
				_lights[i].light_energy = _light_start_energies[i] * fade_curve

func _on_emitter_finished() -> void:
	_finished_count += 1
	_check_destroy()

func _check_destroy() -> void:
	if _destroy_on_finish and _finished_count >= _emitters.size():
		queue_free()

func initialize(target_pos: Vector3) -> void:
	if dynamic_direction and target_pos != Vector3.INF:
		var dir = (target_pos - global_position).normalized()
		
		for emitter in _emitters:
			if emitter is GPUParticles3D:
				var p_mat = emitter.process_material as ParticleProcessMaterial
				if p_mat:
					p_mat.direction = dir
					p_mat.initial_velocity_min = base_speed_min
					p_mat.initial_velocity_max = base_speed_max
					p_mat.gravity = Vector3.ZERO
