extends ParticleEffect

func _ready() -> void:
	super._ready()
	# Give the entire reaction a slight random spin to make each unique
	if has_node("Pivot"):
		$Pivot.rotation_degrees.z = randf_range(0, 360)
