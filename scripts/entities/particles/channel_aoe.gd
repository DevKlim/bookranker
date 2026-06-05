extends Node3D

@onready var particles = $GPUParticles3D

func setup(is_aqua: bool) -> void:
	var mat = particles.process_material as ParticleProcessMaterial
	if mat:
		mat.color = Color(0.2, 0.8, 1.0, 0.9) if is_aqua else Color(0.6, 0.6, 0.6, 0.9)
		
	particles.emitting = true
	get_tree().create_timer(particles.lifetime + 0.1).timeout.connect(queue_free)
