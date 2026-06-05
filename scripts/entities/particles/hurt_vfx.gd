extends ParticleEffect

func _ready() -> void:
	super._ready()
	# Randomize the angles so repeated hits aren't identical
	if has_node("Pivot"):
		$Pivot.rotation_degrees.z = randf_range(0, 360)
		if $Pivot.has_node("Hit"):
			$Pivot/Hit.rotation_degrees.z = randf_range(0, 360)
		if $Pivot.has_node("Hit2"):
			$Pivot/Hit2.rotation_degrees.z = randf_range(0, 360)
