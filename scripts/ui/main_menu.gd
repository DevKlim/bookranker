class_name MainMenu extends Control

enum State { STARTUP, LOGO, INTRO, MENU, LEVEL_SELECT, UNLOCKABLES, OPTIONS, LOADING }
var current_state: State = State.STARTUP

var bg_rect: ColorRect
var hud_rect: ColorRect
var black_screen: ColorRect
var crt_layer: CanvasLayer

var vp_container: SubViewportContainer
var core_pivot: Node3D
var inner_core: MeshInstance3D
var outer_ring: MeshInstance3D

var logo_label: Label
var intro_label: Label

var menu_container: VBoxContainer
var level_container: Control
var level_title: Label
var level_desc: Label

var levels: Array =[]
var selected_level_idx: int = 0
var active_tween: Tween

func _ready() -> void:
	_load_levels()
	_build_scene()
	_set_state(State.STARTUP)

func _process(delta: float) -> void:
	if is_instance_valid(core_pivot):
		core_pivot.rotation.y += delta * 0.5
		core_pivot.rotation.x += delta * 0.2
	if is_instance_valid(inner_core):
		inner_core.rotation.y -= delta * 1.0
		
	if is_instance_valid(hud_rect) and hud_rect.material:
		hud_rect.material.set_shader_parameter("resolution", get_viewport_rect().size)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if current_state == State.LOGO or current_state == State.INTRO:
			_set_state(State.MENU)

# ----------------------- SCENE BUILDER -----------------------

func _build_scene() -> void:
	# 1. Background Chrome Flow (Adjusted to Faded Steel/Chrome palette)
	bg_rect = ColorRect.new()
	bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg_mat = ShaderMaterial.new()
	bg_mat.shader = load("res://shaders/y2k_chromecore_bg.gdshader")
	# Injecting Faded Chrome/Silver Colors
	bg_mat.set_shader_parameter("color_1", Color(0.85, 0.88, 0.9, 1.0)) # Bright Silver
	bg_mat.set_shader_parameter("color_2", Color(0.3, 0.35, 0.45, 1.0)) # Faded Steel Blue
	bg_mat.set_shader_parameter("color_3", Color(0.95, 0.95, 0.95, 1.0)) # Chrome White
	bg_rect.material = bg_mat
	add_child(bg_rect)

	# 2. 3D Viewport for Core
	vp_container = SubViewportContainer.new()
	vp_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp_container.stretch = true
	add_child(vp_container)

	var vp = SubViewport.new()
	vp.transparent_bg = true
	vp_container.add_child(vp)

	var cam = Camera3D.new()
	cam.position = Vector3(0, 0, 5)
	cam.environment = Environment.new()
	vp.add_child(cam)

	var light = DirectionalLight3D.new()
	light.rotation = Vector3(deg_to_rad(-45), deg_to_rad(45), 0)
	vp.add_child(light)

	core_pivot = Node3D.new()
	core_pivot.position = Vector3(-1.5, 0, 0)
	vp.add_child(core_pivot)

	var chrome_mat = ShaderMaterial.new()
	chrome_mat.shader = load("res://shaders/iridescent_chrome.gdshader")

	inner_core = MeshInstance3D.new()
	inner_core.mesh = SphereMesh.new()
	inner_core.mesh.radius = 1.0
	inner_core.mesh.height = 2.0
	inner_core.material_override = chrome_mat
	core_pivot.add_child(inner_core)

	outer_ring = MeshInstance3D.new()
	outer_ring.mesh = TorusMesh.new()
	outer_ring.mesh.inner_radius = 1.2
	outer_ring.mesh.outer_radius = 1.4
	outer_ring.material_override = chrome_mat
	core_pivot.add_child(outer_ring)

	var outer_ring2 = MeshInstance3D.new()
	outer_ring2.mesh = TorusMesh.new()
	outer_ring2.mesh.inner_radius = 1.6
	outer_ring2.mesh.outer_radius = 1.7
	outer_ring2.rotation = Vector3(deg_to_rad(90), 0, 0)
	outer_ring2.material_override = chrome_mat
	core_pivot.add_child(outer_ring2)

	# 3. Y2K HUD Overlay
	hud_rect = ColorRect.new()
	hud_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hud_mat = ShaderMaterial.new()
	hud_mat.shader = load("res://shaders/y2k_hud_overlay.gdshader")
	hud_mat.set_shader_parameter("color", Color(0.6, 0.65, 0.7, 0.4)) # Muted metallic grey
	hud_rect.material = hud_mat
	add_child(hud_rect)
	
	# 4. Cinematic Black Screen Overlay (for startup)
	black_screen = ColorRect.new()
	black_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	black_screen.color = Color.BLACK
	black_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black_screen)

	# 5. CRT Filter Post-Processing
	if ClassDB.class_exists("RetroVisuals") or ResourceLoader.exists("res://scripts/utils/retro_visuals.gd"):
		var rv = load("res://scripts/utils/retro_visuals.gd")
		crt_layer = rv.setup_crt_filter(self, 100)

	# 6. UI Layers
	_build_logo_screen()
	_build_intro_screen()
	_build_main_menu()
	_build_level_select()

func _create_menu_button(text: String) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(300, 50)
	
	# Metallic Snappy Buttons
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = Color(0.65, 0.7, 0.75, 1.0) 
	style_normal.border_color = Color(0.9, 0.95, 1.0, 1.0)
	style_normal.border_width_left = 6
	style_normal.border_width_top = 2
	style_normal.border_width_right = 2
	style_normal.border_width_bottom = 6
	style_normal.corner_radius_top_left = 8
	style_normal.corner_radius_bottom_right = 8
	style_normal.shadow_color = Color(0, 0, 0, 0.8)
	style_normal.shadow_size = 4
	style_normal.shadow_offset = Vector2(4, 4)
	
	var style_hover = style_normal.duplicate()
	style_hover.bg_color = Color(0.85, 0.88, 0.92, 1.0)
	style_hover.border_color = Color.WHITE
	style_hover.shadow_offset = Vector2(6, 6)
	
	var style_pressed = style_normal.duplicate()
	style_pressed.bg_color = Color(0.4, 0.45, 0.5, 1.0)
	style_pressed.border_width_left = 2
	style_pressed.border_width_bottom = 2
	style_pressed.border_width_top = 6
	style_pressed.border_width_right = 6
	style_pressed.shadow_size = 0
	style_pressed.shadow_offset = Vector2(0, 0)
	
	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_pressed)
	
	btn.add_theme_color_override("font_color", Color(0.1, 0.12, 0.15, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(0.05, 0.08, 0.1, 1.0))
	btn.add_theme_font_size_override("font_size", 24)
	
	var font = load("res://assets/fonts/v2-fs-tahoma-8px.otf")
	if font: btn.add_theme_font_override("font", font)
		
	return btn

func _build_logo_screen() -> void:
	logo_label = Label.new()
	logo_label.text = "BASE // ZERO\nSYSTEMS"
	logo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	logo_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	logo_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	logo_label.add_theme_font_size_override("font_size", 72)
	logo_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0, 1.0)) # Chrome white
	logo_label.add_theme_color_override("font_shadow_color", Color(0.3, 0.4, 0.5, 1.0)) # Faded steel shadow
	logo_label.add_theme_constant_override("shadow_offset_x", 6)
	logo_label.add_theme_constant_override("shadow_offset_y", 6)
	var font = load("res://assets/fonts/v2-fs-tahoma-8px.otf")
	if font: logo_label.add_theme_font_override("font", font)
	logo_label.visible = false
	add_child(logo_label)

func _build_intro_screen() -> void:
	intro_label = Label.new()
	intro_label.text = "> Y2K INITIALIZATION...\n\n> Core integrity: CRITICAL\n\n> Soul retrieval protocol: ACTIVE\n\n[ Press any key to execute ]"
	intro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	intro_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	intro_label.add_theme_font_size_override("font_size", 32)
	intro_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8, 1.0)) # Metallic grey
	var font = load("res://assets/fonts/v2-fs-tahoma-8px.otf")
	if font: intro_label.add_theme_font_override("font", font)
	intro_label.visible = false
	add_child(intro_label)

func _build_main_menu() -> void:
	menu_container = VBoxContainer.new()
	menu_container.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_container.add_theme_constant_override("separation", 24)
	menu_container.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	menu_container.offset_left = -450
	menu_container.offset_right = -100
	add_child(menu_container)
	
	var title = Label.new()
	title.text = "BASE // ZERO"
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95, 1.0))
	title.add_theme_color_override("font_shadow_color", Color(0.2, 0.3, 0.4, 1.0)) # Faded blue/grey shadow
	title.add_theme_constant_override("shadow_offset_x", 4)
	title.add_theme_constant_override("shadow_offset_y", 4)
	menu_container.add_child(title)
	
	var btn_start = _create_menu_button("SYSTEM_START")
	btn_start.pressed.connect(func(): _set_state(State.LEVEL_SELECT))
	menu_container.add_child(btn_start)
	
	var btn_db = _create_menu_button("DATABASE")
	btn_db.pressed.connect(func(): print("Unlockables placeholder"))
	menu_container.add_child(btn_db)
	
	var btn_cfg = _create_menu_button("CONFIG")
	btn_cfg.pressed.connect(func(): print("Options placeholder"))
	menu_container.add_child(btn_cfg)
	
	var btn_quit = _create_menu_button("SHUTDOWN")
	btn_quit.pressed.connect(func(): get_tree().quit())
	menu_container.add_child(btn_quit)
	
	menu_container.visible = false

func _build_level_select() -> void:
	level_container = Control.new()
	level_container.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	level_container.offset_left = -600
	level_container.offset_right = -50
	add_child(level_container)
	
	var panel = Panel.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var p_style = StyleBoxFlat.new()
	p_style.bg_color = Color(0.1, 0.12, 0.15, 0.95) # Dark steel
	p_style.border_color = Color(0.6, 0.65, 0.7, 1.0) # Chrome border
	p_style.border_width_left = 4
	p_style.border_width_right = 4
	p_style.border_width_top = 4
	p_style.border_width_bottom = 4
	p_style.corner_radius_top_left = 12
	p_style.corner_radius_bottom_right = 12
	p_style.shadow_size = 8
	p_style.shadow_color = Color(0, 0, 0, 0.8)
	p_style.shadow_offset = Vector2(4, 4)
	panel.add_theme_stylebox_override("panel", p_style)
	level_container.add_child(panel)
	
	var vbox = VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 30
	vbox.offset_top = 30
	vbox.offset_right = -30
	vbox.offset_bottom = -30
	vbox.add_theme_constant_override("separation", 20)
	panel.add_child(vbox)
	
	var header_hbox = HBoxContainer.new()
	header_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(header_hbox)
	
	var btn_prev = _create_menu_button("<")
	btn_prev.custom_minimum_size = Vector2(60, 50)
	btn_prev.pressed.connect(func(): _change_level(-1))
	header_hbox.add_child(btn_prev)
	
	level_title = Label.new()
	level_title.text = "SECTOR 01"
	level_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_title.add_theme_font_size_override("font_size", 32)
	level_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 1))
	level_title.add_theme_constant_override("shadow_offset_x", 3)
	level_title.add_theme_constant_override("shadow_offset_y", 3)
	header_hbox.add_child(level_title)
	
	var btn_next = _create_menu_button(">")
	btn_next.custom_minimum_size = Vector2(60, 50)
	btn_next.pressed.connect(func(): _change_level(1))
	header_hbox.add_child(btn_next)
	
	level_desc = Label.new()
	level_desc.text = "Loading data..."
	level_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	level_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	level_desc.add_theme_font_size_override("font_size", 18)
	level_desc.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8, 1.0)) # Muted metallic grey
	vbox.add_child(level_desc)
	
	var btn_play = _create_menu_button("EXECUTE")
	btn_play.pressed.connect(func(): _start_level())
	vbox.add_child(btn_play)
	
	var btn_back = _create_menu_button("BACK")
	btn_back.pressed.connect(func(): _set_state(State.MENU))
	vbox.add_child(btn_back)
	
	level_container.visible = false

# ----------------------- DATA & LOGIC -----------------------

func _load_levels() -> void:
	levels.clear()
	if not DirAccess.dir_exists_absolute("res://data/levels/"):
		print("MainMenu: No levels folder found.")
		return
		
	var dir = DirAccess.open("res://data/levels/")
	if dir:
		dir.list_dir_begin()
		var file = dir.get_next()
		while file != "":
			if file.ends_with(".json"):
				var path = "res://data/levels/" + file
				var content = FileAccess.get_file_as_string(path)
				var json = JSON.new()
				if json.parse(content) == OK:
					var num_str = file.replace("level_", "").replace(".json", "")
					var num = num_str.to_int()
					levels.append({"file": file, "num": num, "data": json.data})
			file = dir.get_next()
			
	levels.sort_custom(func(a, b): return a.num < b.num)
	
	if levels.is_empty():
		levels.append({"file": "debug", "num": 1, "data": {"name": "Debug Level", "description": "No levels found."}})

func _change_level(dir: int) -> void:
	if levels.is_empty(): return
	selected_level_idx = posmod(selected_level_idx + dir, levels.size())
	_update_level_display()

func _update_level_display() -> void:
	if levels.is_empty(): return
	var lvl = levels[selected_level_idx]
	var data = lvl.data
	level_title.text = data.get("name", "SECTOR %d" % lvl.num)
	level_desc.text = data.get("description", "No description available.\n\nOBJECTIVE: Survive and protect the core.")

func _start_level() -> void:
	if levels.is_empty() or levels[selected_level_idx].file == "debug": return
	GameManager.pending_level = levels[selected_level_idx].num
	_set_state(State.LOADING)

# ----------------------- STATE MACHINE -----------------------

func _set_state(new_state: State) -> void:
	if active_tween and active_tween.is_valid():
		active_tween.kill()
		
	current_state = new_state
	active_tween = create_tween()
	
	# Snappy slide-out transitions
	var snap_dur = 0.2
	var p = active_tween.parallel()
	
	if menu_container.visible: 
		p.tween_property(menu_container, "offset_left", -100, snap_dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		p.tween_property(menu_container, "offset_right", 250, snap_dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	
	if level_container.visible: 
		p.tween_property(level_container, "offset_left", 100, snap_dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		p.tween_property(level_container, "offset_right", 650, snap_dur).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	
	if logo_label.visible:
		p.tween_property(logo_label, "scale", Vector2(1.2, 1.2), snap_dur).set_trans(Tween.TRANS_EXPO)
		p.tween_property(logo_label, "modulate:a", 0.0, snap_dur)
	
	if intro_label.visible:
		p.tween_property(intro_label, "modulate:a", 0.0, snap_dur)

	active_tween.chain().tween_callback(func():
		menu_container.visible = false
		level_container.visible = false
		logo_label.visible = false
		intro_label.visible = false
		_start_state_logic(new_state)
	)

func _start_state_logic(state: State) -> void:
	match state:
		State.STARTUP:
			black_screen.visible = true
			get_tree().create_timer(0.5).timeout.connect(func(): if current_state == State.STARTUP: _set_state(State.LOGO))
			
		State.LOGO:
			black_screen.visible = true
			logo_label.visible = true
			logo_label.modulate.a = 1.0
			logo_label.scale = Vector2(0.8, 0.8)
			logo_label.pivot_offset = logo_label.size / 2.0
			
			var t = create_tween()
			t.tween_property(logo_label, "scale", Vector2(1.0, 1.0), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.tween_interval(2.0)
			t.tween_callback(func(): if current_state == State.LOGO: _set_state(State.INTRO))
			
		State.INTRO:
			black_screen.visible = true
			intro_label.visible = true
			intro_label.modulate.a = 1.0
			intro_label.visible_ratio = 0.0
			
			var t = create_tween()
			# Typewriter effect snap
			t.tween_property(intro_label, "visible_ratio", 1.0, 1.0).set_trans(Tween.TRANS_LINEAR)
			t.tween_interval(2.0)
			t.tween_callback(func(): if current_state == State.INTRO: _set_state(State.MENU))
			
		State.MENU:
			# Instant flash removing black screen
			black_screen.visible = false
			
			var flash = ColorRect.new()
			flash.set_anchors_preset(Control.PRESET_FULL_RECT)
			flash.color = Color(0.9, 0.9, 1.0, 1.0)
			flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(flash)
			var flash_tween = create_tween()
			flash_tween.tween_property(flash, "modulate:a", 0.0, 0.2)
			flash_tween.tween_callback(flash.queue_free)
			
			# Snappy slide in from right
			menu_container.visible = true
			menu_container.offset_left = 100
			menu_container.offset_right = 450
			var t = create_tween().set_parallel(true)
			t.tween_property(menu_container, "offset_left", -450, 0.35).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
			t.tween_property(menu_container, "offset_right", -100, 0.35).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
			
		State.LEVEL_SELECT:
			_update_level_display()
			level_container.visible = true
			level_container.offset_left = 100
			level_container.offset_right = 650
			var t = create_tween().set_parallel(true)
			t.tween_property(level_container, "offset_left", -600, 0.35).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
			t.tween_property(level_container, "offset_right", -50, 0.35).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
			
		State.LOADING:
			# Snappy zoom and white-out for execute
			var flash = ColorRect.new()
			flash.set_anchors_preset(Control.PRESET_FULL_RECT)
			flash.color = Color.WHITE
			flash.modulate.a = 0.0
			add_child(flash)
			
			var t = create_tween().set_parallel(true)
			t.tween_property(flash, "modulate:a", 1.0, 0.4).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
			t.tween_property(vp_container, "scale", Vector2(1.5, 1.5), 0.4).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
			
			t.chain().tween_callback(func(): get_tree().change_scene_to_file("res://scenes/Main.tscn"))
