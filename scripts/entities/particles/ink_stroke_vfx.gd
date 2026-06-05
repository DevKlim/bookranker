extends Node3D

@onready var anim_sprite: AnimatedSprite3D = $AnimatedSprite3D
@onready var splat_particles: CPUParticles3D = $GPUParticles3D

func setup(number: int, duration: float) -> void:
	var anim_name = "stroke_" + str(number)
	
	if anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation(anim_name):
		# Calculate the required FPS to play the frames precisely over the 'duration'
		var frames = anim_sprite.sprite_frames.get_frame_count(anim_name)
		if frames > 0:
			var fps = float(frames) / duration
			anim_sprite.sprite_frames.set_animation_speed(anim_name, fps)
			anim_sprite.play(anim_name)
		else:
			print("[Picasso VFX] Warning: Animation ", anim_name, " exists but has 0 frames.")
	else:
		print("[Picasso VFX] Warning: Missing animation: ", anim_name, " in SpriteFrames.")

	if splat_particles:
		splat_particles.emitting = true

	# Float upwards very slowly while animating
	var tween = create_tween()
	tween.tween_property(self, "position:y", position.y + 0.8, duration + 0.5).set_trans(Tween.TRANS_SINE)
	
	if anim_sprite:
		tween.parallel().tween_property(anim_sprite, "modulate:a", 0.0, 0.4).set_delay(duration)
		
	# Auto destroy cleanly
	get_tree().create_timer(duration + 1.0).timeout.connect(queue_free)
