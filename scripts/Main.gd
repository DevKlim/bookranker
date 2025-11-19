extends Node2D

## The main script for the primary game scene. It handles player input for camera
## movement and building, and sets up the initial game environment.

@export var camera_speed: float = 500.0
@export var zoom_step: float = 0.5
@export var min_zoom: float = 1.0
@export var max_zoom: float = 6.0

@onready var camera: Camera2D = $Camera2D
@onready var build_preview: AnimatedSprite2D = $BuildPreview
@onready var game_ui: CanvasLayer = $GameUI
@onready var tile_map: TileMapLayer = $TileMapLayer
@onready var buildings_container: Node2D = $Buildings

var _original_modulates: Dictionary = {}


func _ready() -> void:
	print("Main scene initialized.")
	build_preview.visible = false
	BuildManager.build_mode_changed.connect(_on_build_state_changed)
	BuildManager.selected_buildable_changed.connect(_on_build_state_changed)
	BuildManager.build_rotation_changed.connect(_on_build_rotation_changed)


func _process(delta: float) -> void:
	handle_camera_movement(delta)
	handle_debug_display()
	
	if BuildManager.is_building:
		update_build_preview()
		
		var buildable = BuildManager.selected_buildable
		if not buildable: return

		# --- CORRECTED LOGIC ---
		# Check if the selected item is a tool (like the remover).
		if buildable.layer == BuildableResource.BuildLayer.TOOL:
			# Tools should only activate once per click.
			if Input.is_action_just_pressed("build_place"):
				if not _is_mouse_over_ui():
					BuildManager.place_buildable(get_global_mouse_position())
		else:
			# Placing actual buildings/wires can be held down.
			if Input.is_action_pressed("build_place"):
				if not _is_mouse_over_ui():
					BuildManager.place_buildable(get_global_mouse_position())


func _input(event: InputEvent) -> void:
	if get_viewport().is_input_handled():
		return

	# Handle Zoom
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			var target_zoom = camera.zoom + Vector2(zoom_step, zoom_step)
			camera.zoom = target_zoom.clamp(Vector2(min_zoom, min_zoom), Vector2(max_zoom, max_zoom))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			var target_zoom = camera.zoom - Vector2(zoom_step, zoom_step)
			camera.zoom = target_zoom.clamp(Vector2(min_zoom, min_zoom), Vector2(max_zoom, max_zoom))

	# Handle right-click ("build_cancel") for deleting or canceling build mode. This is single-click.
	if Input.is_action_just_pressed("build_cancel"):
		var mouse_pos = get_global_mouse_position()
		# If the mouse is over something that can be removed, remove it.
		if BuildManager.has_removable_at(mouse_pos) and not _is_mouse_over_ui():
			BuildManager.remove_buildable_at(mouse_pos)
		# Otherwise, if in build mode, exit build mode.
		elif BuildManager.is_building:
			BuildManager.exit_build_mode()
		get_viewport().set_input_as_handled()

	# Handle build-mode specific actions (that aren't cancel/delete). This is single-click.
	elif BuildManager.is_building and Input.is_action_just_pressed("build_rotate"):
		BuildManager.rotate_buildable()
		get_viewport().set_input_as_handled()


func handle_camera_movement(delta: float) -> void:
	var move_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	camera.position += move_vector * camera_speed * delta

func handle_debug_display() -> void:
	var mouse_pos = get_global_mouse_position()
	var tile_coord = tile_map.local_to_map(mouse_pos)
	var logical_coord = LaneManager.get_logical_from_tile(tile_coord)
	
	if game_ui and game_ui.has_method("update_debug_coords"):
		game_ui.update_debug_coords(tile_coord, logical_coord)


func _on_build_state_changed(_arg = null) -> void:
	build_preview.visible = false
	
	if BuildManager.is_building and BuildManager.selected_buildable:
		var buildable = BuildManager.selected_buildable
		
		# For buildables that spawn a scene (MECH and WIRING)
		if buildable.scene:
			var temp_instance = buildable.scene.instantiate()
			if temp_instance.has_method("get_sprite_frames"):
				var frames = temp_instance.get_sprite_frames()
				if frames:
					build_preview.sprite_frames = frames.duplicate(true)
					var initial_anim = &"idle_down"
					if buildable.layer == BuildableResource.BuildLayer.WIRING:
						initial_anim = &"off_0"
					
					if build_preview.sprite_frames.has_animation(initial_anim):
						build_preview.play(initial_anim)
						build_preview.visible = true
			temp_instance.queue_free()
		# For tools like the remover that don't have a scene
		elif buildable.layer == BuildableResource.BuildLayer.TOOL:
			var frames = build_preview.sprite_frames
			if not frames or not frames is SpriteFrames:
				frames = SpriteFrames.new()
				build_preview.sprite_frames = frames
			
			# Ensure we only have the 'default' animation for the tool
			for anim in frames.get_animation_names():
				if anim != &"default":
					frames.remove_animation(anim)
			
			if not frames.has_animation(&"default"):
				frames.add_animation(&"default")
			
			frames.clear(&"default")
			if buildable.icon:
				frames.add_frame(&"default", buildable.icon)

			build_preview.play(&"default")
			build_preview.visible = true

	var in_wire_mode = BuildManager.is_building and BuildManager.selected_buildable and \
		BuildManager.selected_buildable.layer == BuildableResource.BuildLayer.WIRING
	
	if in_wire_mode:
		for building in buildings_container.get_children():
			if building is CanvasItem and not _original_modulates.has(building):
				_original_modulates[building] = building.modulate
				var transparent_color = building.modulate
				transparent_color.a = 0.4
				building.modulate = transparent_color
	else:
		for building in _original_modulates:
			if is_instance_valid(building): building.modulate = _original_modulates[building]
		_original_modulates.clear()


func _on_build_rotation_changed(anim_name: StringName) -> void:
	if build_preview.sprite_frames and build_preview.sprite_frames.has_animation(anim_name):
		build_preview.play(anim_name)


func _is_mouse_over_ui() -> bool:
	var mouse_viewport_pos = get_viewport().get_mouse_position()
	for ui_rect in game_ui.get_ui_rects():
		if ui_rect.has_point(mouse_viewport_pos):
			return true
	return false


func update_build_preview():
	var mouse_pos = get_global_mouse_position()
	
	if _is_mouse_over_ui():
		build_preview.visible = false
		return
	
	var buildable = BuildManager.selected_buildable
	if not buildable or not BuildManager.is_building:
		build_preview.visible = false
		return

	# Only show preview if there is something to show
	var has_visuals = build_preview.sprite_frames or (buildable.layer == BuildableResource.BuildLayer.TOOL and buildable.icon)
	build_preview.visible = has_visuals
	if not has_visuals:
		return

	var tile_coord = tile_map.local_to_map(mouse_pos)
	var snapped_pos = tile_map.map_to_local(tile_coord)
	var vertical_offset = Vector2(0, -tile_map.tile_set.tile_size.y / 2.0)
	build_preview.global_position = snapped_pos + vertical_offset

	if buildable.layer == BuildableResource.BuildLayer.MECH or buildable.layer == BuildableResource.BuildLayer.WIRING:
		build_preview.modulate = Color(0.435, 1, 0.498, 0.5) if BuildManager.can_build_at(mouse_pos) else Color(1, 0.435, 0.435, 0.5)
	elif buildable.layer == BuildableResource.BuildLayer.TOOL:
		build_preview.modulate = Color(1, 0.5, 0.5, 0.7) if BuildManager.has_removable_at(mouse_pos) else Color(0.5, 0.5, 0.5, 0.5)
