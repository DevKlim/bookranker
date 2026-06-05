class_name WindowUtils
extends RefCounted

static func apply_liquid_glass(win: Control, corner_radius: float = 12.0) -> void:
	win.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	
	var bbc = BackBufferCopy.new()
	bbc.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	win.add_child(bbc)
	win.move_child(bbc, 0)
	
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat = ShaderMaterial.new()
	var shader = load("res://shaders/liquid_glass.gdshader")
	if shader:
		mat.shader = shader
		mat.set_shader_parameter("tint", Color(0.9, 0.9, 0.9, 0.25))
		mat.set_shader_parameter("corner_radius", corner_radius)
		mat.set_shader_parameter("bezel_width", 12.0)
	bg.material = mat
	win.add_child(bg)
	win.move_child(bg, 1)
	
	var update_shader = func():
		if is_instance_valid(win) and is_instance_valid(mat) and mat.shader:
			mat.set_shader_parameter("rect_size", win.size)
			
	win.resized.connect(update_shader)
	win.call_deferred("emit_signal", "resized")

static func create_drag_preview(icon: Texture2D) -> Control:
	var preview = Control.new()
	var t = TextureRect.new()
	t.texture = icon
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(64, 64)
	t.size = Vector2(64, 64)
	t.position = -Vector2(32, 32)
	t.texture_filter = Control.TEXTURE_FILTER_NEAREST
	t.z_index = 100
	preview.add_child(t)
	return preview

static func setup_window_resizing(win: Control, scale_wrapper: Control, scale_root: Control, content_node: Control, base_min_size: Vector2) -> void:
	var m = 12
	var configs = [[0, -1, Control.CURSOR_VSIZE],[0, 1, Control.CURSOR_VSIZE],[-1, 0, Control.CURSOR_HSIZE],[1, 0, Control.CURSOR_HSIZE],[-1, -1, Control.CURSOR_FDIAGSIZE],[1, -1, Control.CURSOR_BDIAGSIZE],[-1, 1, Control.CURSOR_BDIAGSIZE],[1, 1, Control.CURSOR_FDIAGSIZE]]
	
	var handles =[]
	var sync_ref =[]
	
	for cfg in configs:
		var handle = Control.new()
		handle.mouse_default_cursor_shape = cfg[2]
		handle.top_level = true
		win.add_child(handle)
		handles.append({"node": handle, "dx": cfg[0], "dy": cfg[1]})
		
		handle.gui_input.connect(func(event):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					win.set_meta("res_drag", true)
					win.set_meta("res_dx", cfg[0])
					win.set_meta("res_dy", cfg[1])
					win.set_meta("res_start_pos", win.global_position)
					win.set_meta("res_start_size", win.size)
					win.set_meta("res_start_mouse", event.global_position)
				else:
					win.set_meta("res_drag", false)
			elif event is InputEventMouseMotion and win.get_meta("res_drag", false):
				var dx = win.get_meta("res_dx")
				var dy = win.get_meta("res_dy")
				var s_pos = win.get_meta("res_start_pos")
				var s_size = win.get_meta("res_start_size")
				var s_mouse = win.get_meta("res_start_mouse")
				
				var delta = event.global_position - s_mouse
				var absolute_min = Vector2(80, 80)
				
				var new_pos = s_pos
				var new_size = s_size
				
				if dx == 1:
					new_size.x = max(absolute_min.x, s_size.x + delta.x)
				elif dx == -1:
					new_size.x = max(absolute_min.x, s_size.x - delta.x)
					new_pos.x = s_pos.x + (s_size.x - new_size.x)
					
				if dy == 1:
					new_size.y = max(absolute_min.y, s_size.y + delta.y)
				elif dy == -1:
					new_size.y = max(absolute_min.y, s_size.y - delta.y)
					new_pos.y = s_pos.y + (s_size.y - new_size.y)
					
				win.global_position = new_pos
				win.size = new_size
				win.custom_minimum_size = new_size
				
				if sync_ref.size() > 0:
					sync_ref[0].call()
		)
		
	var sync_handles = func():
		if not win.is_inside_tree(): return
		
		var c_size = scale_wrapper.size
		if c_size.x < 10 or c_size.y < 10:
			c_size = win.size - Vector2(0, 30)
			
		c_size.x = max(1.0, c_size.x)
		c_size.y = max(1.0, c_size.y)
		
		var target_x = max(1.0, base_min_size.x - 24.0)
		var target_y = max(1.0, base_min_size.y - 54.0)
		
		var s = min(1.0, min(c_size.x / target_x, c_size.y / target_y))
		if s >= 0.99: 
			s = 1.0 
			
		scale_root.scale = Vector2(s, s)
		content_node.size = (c_size / s).ceil()
		content_node.position = Vector2.ZERO
		
		for h in handles:
			var node = h.node
			var dx = h.dx
			var dy = h.dy
			var r_pos = win.global_position
			var r_size = win.size
			
			if dx == 0 and dy == -1:
				node.global_position = r_pos + Vector2(m, -m)
				node.size = Vector2(r_size.x - 2*m, 2*m)
			elif dx == 0 and dy == 1:
				node.global_position = r_pos + Vector2(m, r_size.y - m)
				node.size = Vector2(r_size.x - 2*m, 2*m)
			elif dx == -1 and dy == 0:
				node.global_position = r_pos + Vector2(-m, m)
				node.size = Vector2(2*m, r_size.y - 2*m)
			elif dx == 1 and dy == 0:
				node.global_position = r_pos + Vector2(r_size.x - m, m)
				node.size = Vector2(2*m, r_size.y - 2*m)
			elif dx == -1 and dy == -1:
				node.global_position = r_pos + Vector2(-m, -m)
				node.size = Vector2(2*m, 2*m)
			elif dx == 1 and dy == -1:
				node.global_position = r_pos + Vector2(r_size.x - m, -m)
				node.size = Vector2(2*m, 2*m)
			elif dx == -1 and dy == 1:
				node.global_position = r_pos + Vector2(-m, r_size.y - m)
				node.size = Vector2(2*m, 2*m)
			elif dx == 1 and dy == 1:
				node.global_position = r_pos + Vector2(r_size.x - m, r_size.y - m)
				node.size = Vector2(2*m, 2*m)
				
	sync_ref.append(sync_handles)
	win.resized.connect(sync_handles)
	win.item_rect_changed.connect(sync_handles)
	
	win.visibility_changed.connect(func():
		var is_vis = win.is_visible_in_tree()
		for h in handles:
			if is_instance_valid(h.node):
				h.node.visible = is_vis
		if is_vis:
			if win.is_inside_tree():
				win.call_deferred("emit_signal", "resized")
		else:
			win.set_meta("res_drag", false)
	)
	win.call_deferred("emit_signal", "resized")
