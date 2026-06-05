extends Node3D

@onready var anim_player = $AnimationPlayer

func _ready() -> void:
	var tex1 = load("res://assets/textures/particles/smokes/smoke_07_a.png")
	var tex2 = load("res://assets/textures/particles/smokes/smoke_04_a.png")
	var active_tex = tex1 if tex1 else tex2
	
	# Create sprite cluster dynamically to allow randomized local offsets
	for i in range(5):
		var p = Sprite3D.new()
		p.name = "Smoke" + str(i)
		p.texture = active_tex
		p.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		p.modulate = Color(0.0627, 0.1686, 0.1882, 1.0000)
		p.pixel_size = 0.005
		p.render_priority = 60
		p.no_depth_test = true
		add_child(p)
		
	# Build the robust animation natively to guarantee execution
	var anim = Animation.new()
	anim.length = 0.6
	
	for i in range(3):
		var target_node = "Smoke" + str(i)
		var rand_offset = Vector3(randf_range(-2.0, 2.0), randf_range(0.0, 2.5), randf_range(-2.0, 2.0))
		
		# Position Track
		var t_pos = anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(t_pos, target_node + ":position")
		anim.track_insert_key(t_pos, 0.0, Vector3.ZERO)
		anim.track_insert_key(t_pos, 0.6, rand_offset)
		anim.track_set_interpolation_type(t_pos, Animation.INTERPOLATION_CUBIC)
		
		# Scale Track
		var t_scale = anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(t_scale, target_node + ":scale")
		anim.track_insert_key(t_scale, 0.0, Vector3.ONE)
		anim.track_insert_key(t_scale, 0.3, Vector3(4.0, 4.0, 4.0))
		anim.track_set_interpolation_type(t_scale, Animation.INTERPOLATION_CUBIC)
		
		# Rotation Track
		var t_rot = anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(t_rot, target_node + ":rotation_degrees:z")
		anim.track_insert_key(t_rot, 0.0, 0.0)
		anim.track_insert_key(t_rot, 0.6, randf_range(-180, 180))
		
		# Fade Track
		var t_fade = anim.add_track(Animation.TYPE_VALUE)
		anim.track_set_path(t_fade, target_node + ":modulate:a")
		anim.track_insert_key(t_fade, 0.0, 0.9)
		anim.track_insert_key(t_fade, 0.4, 0.9)
		anim.track_insert_key(t_fade, 0.6, 0.0)
		
	var library = AnimationLibrary.new()
	library.add_animation("poof", anim)
	anim_player.add_animation_library("", library)
	
	anim_player.play("poof")
	anim_player.animation_finished.connect(func(_anim_name): queue_free())
