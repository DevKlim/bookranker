extends Node2D

## The main script for the primary game scene. It handles player input for camera
## movement and building, and sets up the initial game environment.

@export var camera_speed: float = 500.0

@onready var camera: Camera2D = $Camera2D
@onready var build_preview: Sprite2D = $BuildPreview
@onready var game_ui: CanvasLayer = $GameUI
@onready var tile_map: TileMapLayer = $TileMapLayer
@onready var buildings_container: Node2D = $Buildings


func _ready() -> void:
	print("Main scene initialized.")
	build_preview.visible = false
	BuildManager.build_mode_changed.connect(_on_build_mode_changed)
	BuildManager.build_rotation_changed.connect(_on_build_rotation_changed)


func _process(delta: float) -> void:
	handle_camera_movement(delta)
	handle_debug_display()
	
	if BuildManager.is_building:
		update_build_preview()

func _input(event: InputEvent) -> void:
	# If a UI element has already processed this input, do nothing.
	# This prevents us from building when clicking on a UI button.
	if get_viewport().is_input_handled():
		return

	if BuildManager.is_building:
		# Check for left-click to place a buildable.
		if event.is_action_pressed("build_place"): 
			BuildManager.place_buildable(get_global_mouse_position())
			get_viewport().set_input_as_handled()
		# Check for right-click to cancel building.
		elif event.is_action_pressed("build_cancel"):
			BuildManager.exit_build_mode()
			get_viewport().set_input_as_handled()
		# Check for 'R' key to rotate.
		elif event.is_action_pressed("build_rotate"):
			BuildManager.rotate_buildable()
			get_viewport().set_input_as_handled()
	else: 
		# If not in build mode, handle deconstruction with right-click.
		if event.is_action_pressed("build_cancel"):
			BuildManager.remove_buildable_at(get_global_mouse_position())
			get_viewport().set_input_as_handled()


func handle_camera_movement(delta: float) -> void:
	var move_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	camera.position += move_vector * camera_speed * delta

func handle_debug_display() -> void:
	var mouse_pos = get_global_mouse_position()
	var tile_coord = tile_map.local_to_map(mouse_pos)
	if game_ui and game_ui.has_method("update_debug_coords"):
		game_ui.update_debug_coords(tile_coord)

func _on_build_mode_changed(is_building: bool) -> void:
	build_preview.visible = is_building
	if is_building and BuildManager.selected_buildable:
		# For wiring, don't show the preview sprite, as the tilemap handles it.
		if BuildManager.selected_buildable.layer == BuildableResource.BuildLayer.MECH:
			build_preview.texture = BuildManager.selected_buildable.icon
			# Reset offset, as we will handle alignment via global_position
			build_preview.offset = Vector2.ZERO
			build_preview.visible = true
		else:
			build_preview.visible = false


func _on_build_rotation_changed(new_rotation_degrees: float) -> void:
	if is_instance_valid(build_preview):
		build_preview.rotation_degrees = new_rotation_degrees


func update_build_preview():
	if not build_preview.visible:
		return

	var mouse_pos = get_global_mouse_position()
	
	if not is_instance_valid(BuildManager.tile_map):
		return
		
	var tile_coord = BuildManager.tile_map.local_to_map(mouse_pos)
	var snapped_pos = BuildManager.tile_map.map_to_local(tile_coord)
	
	# Apply the same vertical offset to the preview as the placed asset
	# to correctly align its base with the tile center.
	var vertical_offset = Vector2(0, -tile_map.tile_set.tile_size.y / 2.0)
	build_preview.global_position = snapped_pos + vertical_offset
	
	if BuildManager.can_build_at(mouse_pos):
		build_preview.modulate = Color(0.435, 1, 0.498, 0.5) # Greenish tint
	else:
		build_preview.modulate = Color(1, 0.435, 0.435, 0.5) # Reddish tint