extends ParticleEffect

var ripples: Array[Sprite3D] =[]

func _ready() -> void:
	super._ready()
	
	# Spawn ground ripples periodically
	for i in range(2):
		var ripple = Sprite3D.new()
		ripple.texture = load("res://assets/textures/particles/circle/circle_03_a.png")
		ripple.pixel_size = 0.0005
		ripple.modulate = Color(0.4, 0.7, 1.0, 0.0)
		ripple.axis = Vector3.AXIS_Y
		ripple.render_priority = 30
		ripple.position.y = 0.05
		add_child(ripple)
		ripples.append(ripple)
		
		# Animate in a loop with staggered delays
		_animate_ripple(ripple, i * 0.3)

func _animate_ripple(ripple: Sprite3D, delay: float) -> void:
	if not is_inside_tree(): return
	var tween = create_tween().set_parallel(true)
	
	ripple.scale = Vector3(0.1, 0.1, 0.1)
	ripple.modulate.a = 0.0
	
	# Randomize position within the tile
	ripple.position.x = randf_range(-0.4, 0.4)
	ripple.position.z = randf_range(-0.4, 0.4)
	
	tween.tween_property(ripple, "modulate:a", 0.6, 0.1).set_delay(delay)
	tween.tween_property(ripple, "scale", Vector3(1.5, 1.5, 1.5), 0.6).set_ease(Tween.EASE_OUT).set_delay(delay)
	tween.tween_property(ripple, "modulate:a", 0.0, 0.5).set_ease(Tween.EASE_IN).set_delay(delay + 0.1)
	
	tween.chain().tween_callback(func(): _animate_ripple(ripple, randf_range(0.1, 0.3)))

