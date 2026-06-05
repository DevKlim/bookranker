extends ParticleEffect

func _ready() -> void:
	super._ready()
	# Randomize the pivot rotation so the slash happens at a random angle
	if has_node("Pivot"):
		var rot = randf_range(-45.0, 45.0)
		$Pivot.rotation_degrees.z = rot
