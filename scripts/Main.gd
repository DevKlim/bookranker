extends Node2D

## The main script for the primary game scene. It handles player input for camera
## movement and building, and sets up the initial game environment.

@export var camera_speed: float = 500.0
@export var zoom_step: float = 0.5
@export var min_zoom: float = 1.0
@export var max_zoom: float = 6.0

@export_group("Grid Visual Offsets (Adjusts LaneManager)")
## Adjusts the visual offset for Ore Generation (OreLayer). 
## This is passed to LaneManager at startup.
@export var ore_offset: Vector2 = Vector2(0, 0)

## Adjusts the visual offset for Wires. 
## This is passed to LaneManager at startup.
@export var wire_offset: Vector2 = Vector2(0, 0)

## Adjusts the visual offset for Buildings. 
## This is passed to LaneManager at startup.
@export var building_offset: Vector2 = Vector2(0, 0)


@onready var camera: Camera2D = $Camera2D
@onready var build_preview: AnimatedSprite2D = $BuildPreview
@onready var game_ui: CanvasLayer = $GameUI
@onready var tile_map: TileMapLayer = $TileMapLayer
@onready var buildings_container: Node2D = $Buildings

var _original_modulates: Dictionary = {}
var arrow_indicator: Sprite2D
var input_arrow_indicator: Sprite2D
var selected_mech_coords: Vector2i = Vector2i(-1, -1)
var _hovered_for_deletion: Node2D = null

# Visual configuration cache for the currently selected buildable
var _current_extra_visuals: Array = []

# Dictionary for textures, initialized in _ready to avoid const expression errors
var arrow_textures: Dictionary = {}

func _ready() -> void:
	print("Main scene initialized.")
	
	# Apply offsets to LaneManager
	LaneManager.ore_offset = ore_offset
	LaneManager.wire_offset = wire_offset
	LaneManager.building_offset = building_offset
	
	# Initialize Arrow Textures here to prevent parser errors with Enums
	arrow_textures = {
		BaseBuilding.Direction.DOWN: preload("res://assets/ui/arrowdown.png"),
		BaseBuilding.Direction.LEFT: preload("res://assets/ui/arrowleft.png"),
		BaseBuilding.Direction.UP: preload("res://assets/ui/arrowup.png"),
		BaseBuilding.Direction.RIGHT: preload("res://assets/ui/arrowright.png")
	}
	
	build_preview.visible = false
	
	# Output Arrow (Green/Default)
	arrow_indicator = Sprite2D.new()
	arrow_indicator.z_index = 100 
	arrow_indicator.visible = false
	add_child(arrow_indicator)
	
	# Input Arrow (Red)
	input_arrow_indicator = Sprite2D.new()
	input_arrow_indicator.z_index = 100
	input_arrow_indicator.visible = false
	input_arrow_indicator.modulate = Color(1, 0, 0, 0.8) # Red
	add_child(input_arrow_indicator)
	
	BuildManager.build_mode_changed.connect(_on_build_state_changed)
	BuildManager.selected_buildable_changed.connect(_on_build_state_changed)
	BuildManager.build_rotation_changed.connect(_on_build_rotation_changed)


func _process(delta: float) -> void:
	handle_camera_movement(delta)
	handle_debug_display()
	
	if BuildManager.is_building:
		update_build_preview()
		_handle_delete_highlight()
		
		var buildable = BuildManager.selected_buildable
		if buildable:
			if buildable.layer == BuildableResource.BuildLayer.TOOL:
				if Input.is_action_just_pressed("build_place"):
					if not _is_mouse_over_ui():
						var mouse_pos = get_global_mouse_position()
						BuildManager.place_buildable(mouse_pos)
			else:
				if Input.is_action_pressed("build_place"):
					if not _is_mouse_over_ui():
						var mouse_pos = get_global_mouse_position()
						# We now calculate the target offset within BuildManager.place_buildable 
						# using logic based on the buildable type, so we pass raw visual pos 
						# but snapped to the grid visually for the user experience.
						
						var offset = _get_offset_for_current_buildable()
						var logical_tile = LaneManager.world_to_tile(mouse_pos - offset)
						var visual_snap_pos = LaneManager.tile_to_world(logical_tile) + offset
						
						BuildManager.place_buildable(visual_snap_pos)
	else:
		_clear_delete_highlight()
		# Selection Logic
		if Input.is_action_just_pressed("build_place"): # Left click to select
			if not _is_mouse_over_ui():
				var mouse_pos = get_global_mouse_position()
				# Account for building offset when selecting
				var tile_coord = LaneManager.world_to_tile(mouse_pos - LaneManager.get_layer_offset("building"))
				var mech = BuildManager.get_mech_at(tile_coord)
				
				if mech:
					selected_mech_coords = tile_coord
					
					var inventory = mech.get("inventory")
					if not inventory:
						inventory = mech.get("input_inventory")
						
					if inventory and inventory is InventoryComponent:
						var title = mech.name.rstrip("0123456789")
						game_ui.open_inventory(inventory, title, mech)
					else:
						game_ui.close_inventory()
						
				else:
					selected_mech_coords = Vector2i(-1, -1)
					game_ui.close_inventory()
	
	if selected_mech_coords != Vector2i(-1, -1):
		# Inventory tracks visual position of the building
		var world_pos = LaneManager.tile_to_world(selected_mech_coords) + LaneManager.get_layer_offset("building")
		world_pos.y -= 16
		var screen_pos = get_viewport().get_canvas_transform() * world_pos
		game_ui.set_inventory_screen_position(screen_pos)

	update_arrow_indicator()

func _input(event: InputEvent) -> void:
	if get_viewport().is_input_handled():
		return

	if event is InputEventMouseButton:
		var zoom_changed = false
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			var target_zoom = camera.zoom + Vector2(zoom_step, zoom_step)
			camera.zoom = target_zoom.clamp(Vector2(min_zoom, min_zoom), Vector2(max_zoom, max_zoom))
			zoom_changed = true
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			var target_zoom = camera.zoom - Vector2(zoom_step, zoom_step)
			camera.zoom = target_zoom.clamp(Vector2(min_zoom, min_zoom), Vector2(max_zoom, max_zoom))
			zoom_changed = true
		
		if zoom_changed:
			camera.force_update_scroll()

	if Input.is_action_just_pressed("build_cancel"):
		if BuildManager.is_building:
			BuildManager.exit_build_mode()
		selected_mech_coords = Vector2i(-1, -1)
		game_ui.close_inventory()
		get_viewport().set_input_as_handled()

	elif BuildManager.is_building and Input.is_action_just_pressed("build_rotate"):
		BuildManager.rotate_buildable()
		get_viewport().set_input_as_handled()


func handle_camera_movement(delta: float) -> void:
	var move_vector = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if move_vector != Vector2.ZERO:
		camera.position += move_vector * camera_speed * delta
		camera.force_update_scroll()

func handle_debug_display() -> void:
	var mouse_pos = get_global_mouse_position()
	# Debug assumes looking at the building layer for tile logic
	var tile_coord = LaneManager.world_to_tile(mouse_pos - LaneManager.get_layer_offset("building"))
	var logical_coord = LaneManager.get_logical_from_tile(tile_coord)
	var ore = LaneManager.get_ore_at_world_pos(mouse_pos)
	
	var debug_str = "Tile: %s" % str(tile_coord)
	if logical_coord.x != -1:
		debug_str += "\nLogical: %s" % str(logical_coord)
	if ore:
		debug_str += "\nOre: %s" % ore.item_name
	
	if game_ui:
		game_ui.set_debug_text(debug_str)

func _get_offset_for_current_buildable() -> Vector2:
	if not BuildManager.is_building or not BuildManager.selected_buildable:
		return Vector2.ZERO
	if BuildManager.selected_buildable.layer == BuildableResource.BuildLayer.MECH:
		return LaneManager.get_layer_offset("building")
	if BuildManager.selected_buildable.layer == BuildableResource.BuildLayer.WIRING:
		return LaneManager.get_layer_offset("wire")
	return Vector2.ZERO

func update_arrow_indicator() -> void:
	arrow_indicator.visible = false
	input_arrow_indicator.visible = false
	
	var out_dir = -1
	var in_dir = -1
	var base_pos = Vector2.ZERO
	var show_arrows = false
	var show_input = false
	var show_output = false
	
	if BuildManager.is_building and build_preview.visible and BuildManager.selected_buildable:
		if BuildManager.selected_buildable.layer == BuildableResource.BuildLayer.MECH:
			base_pos = build_preview.global_position
			var display_offset = BuildManager.selected_buildable.display_offset
			base_pos -= display_offset
			
			show_arrows = true
			show_input = BuildManager.selected_buildable.has_input
			show_output = BuildManager.selected_buildable.has_output
			
			var anim_name = build_preview.animation
			match anim_name:
				&"idle_down": 
					out_dir = BaseBuilding.Direction.DOWN
					in_dir = BaseBuilding.Direction.UP
				&"idle_left": 
					out_dir = BaseBuilding.Direction.LEFT
					in_dir = BaseBuilding.Direction.RIGHT
				&"idle_up":   
					out_dir = BaseBuilding.Direction.UP
					in_dir = BaseBuilding.Direction.DOWN
				&"idle_right":
					out_dir = BaseBuilding.Direction.RIGHT
					in_dir = BaseBuilding.Direction.LEFT

	elif selected_mech_coords != Vector2i(-1, -1):
		var mech = BuildManager.get_mech_at(selected_mech_coords)
		if is_instance_valid(mech):
			base_pos = LaneManager.tile_to_world(selected_mech_coords) + LaneManager.get_layer_offset("building")
			show_arrows = true
			
			if "has_input" in mech: show_input = mech.has_input
			if "has_output" in mech: show_output = mech.has_output
			
			if "output_direction" in mech:
				out_dir = mech.output_direction
			if "input_direction" in mech:
				in_dir = mech.input_direction
		else:
			selected_mech_coords = Vector2i(-1, -1)

	if show_arrows:
		if show_output and out_dir != -1 and arrow_textures.has(out_dir):
			arrow_indicator.texture = arrow_textures[out_dir]
			arrow_indicator.global_position = base_pos
			arrow_indicator.visible = true
			
		if show_input and in_dir != -1 and arrow_textures.has(in_dir):
			input_arrow_indicator.texture = arrow_textures[in_dir]
			input_arrow_indicator.global_position = base_pos
			input_arrow_indicator.visible = true


func _on_build_state_changed(_arg = null) -> void:
	build_preview.visible = false
	_clear_delete_highlight()
	_clear_preview_children() 
	selected_mech_coords = Vector2i(-1, -1) 
	game_ui.close_inventory()
	
	if BuildManager.is_building and BuildManager.selected_buildable:
		var buildable = BuildManager.selected_buildable
		
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
			
			if temp_instance.has_method("get_visual_configuration"):
				var initial_anim = &"idle_down"
				_current_extra_visuals = temp_instance.get_visual_configuration(initial_anim)
				_update_preview_extras()
			else:
				_current_extra_visuals = []

			temp_instance.queue_free()

		elif buildable.layer == BuildableResource.BuildLayer.TOOL:
			var frames = build_preview.sprite_frames
			if not frames or not frames is SpriteFrames:
				frames = SpriteFrames.new()
				build_preview.sprite_frames = frames
			
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
			_current_extra_visuals = []

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
	
	if BuildManager.selected_buildable and BuildManager.selected_buildable.scene:
		var temp_instance = BuildManager.selected_buildable.scene.instantiate()
		if temp_instance.has_method("get_visual_configuration"):
			_current_extra_visuals = temp_instance.get_visual_configuration(anim_name)
			_update_preview_extras()
		temp_instance.queue_free()


func _update_preview_extras() -> void:
	_clear_preview_children()
	
	for config in _current_extra_visuals:
		var sprite = AnimatedSprite2D.new()
		sprite.sprite_frames = build_preview.sprite_frames
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		
		var anim = config.get("animation", "idle_down")
		if sprite.sprite_frames.has_animation(anim):
			sprite.play(anim)
			
		var tile_offset = config.get("offset", Vector2i.ZERO)
		sprite.set_meta("tile_offset", tile_offset)
		
		build_preview.add_child(sprite)

func _clear_preview_children() -> void:
	for child in build_preview.get_children():
		child.queue_free()


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

	var has_visuals = build_preview.sprite_frames or (buildable.layer == BuildableResource.BuildLayer.TOOL and buildable.icon)
	build_preview.visible = has_visuals
	if not has_visuals:
		return

	# Determine applicable offset
	var offset = _get_offset_for_current_buildable()

	# Map mouse (minus visual offset) to tile
	var tile_coord = LaneManager.world_to_tile(mouse_pos - offset)
	
	# Map tile back to world + visual offset
	var snapped_pos = LaneManager.tile_to_world(tile_coord) + offset

	build_preview.global_position = snapped_pos + buildable.display_offset

	for child in build_preview.get_children():
		if child.has_meta("tile_offset"):
			var child_offset_coord = child.get_meta("tile_offset")
			var pixel_pos = _get_dynamic_preview_offset(tile_coord, child_offset_coord)
			child.position = pixel_pos

	if buildable.layer == BuildableResource.BuildLayer.MECH or buildable.layer == BuildableResource.BuildLayer.WIRING:
		# can_build_at expects position. We pass the snapped visual position which BuildManager will un-offset.
		var can_build = BuildManager.can_build_at(snapped_pos)
		var col = Color(0.435, 1, 0.498, 0.5) if can_build else Color(1, 0.435, 0.435, 0.5)
		build_preview.modulate = col
		for child in build_preview.get_children():
			child.modulate = col
			
	elif buildable.layer == BuildableResource.BuildLayer.TOOL:
		build_preview.modulate = Color(1, 0.5, 0.5, 0.7) if BuildManager.has_removable_at(mouse_pos) else Color(0.5, 0.5, 0.5, 0.5)

func _get_dynamic_preview_offset(origin: Vector2i, offset: Vector2i) -> Vector2:
	# Use LaneManager for consistency
	var p0 = LaneManager.tile_to_world(Vector2i.ZERO)
	var p1 = LaneManager.tile_to_world(offset)
	var std_vec = p1 - p0 
	
	var log_origin = LaneManager.get_logical_from_tile(origin)
	if log_origin == Vector2i(-1, -1):
		return std_vec
		
	var target_log = log_origin
	var valid_logic = false
	
	if offset == Vector2i(0, -1): 
		target_log.y += 1
		valid_logic = true
	elif offset == Vector2i(0, 1): 
		target_log.y -= 1
		valid_logic = true
	elif offset == Vector2i(1, 0): 
		target_log.x -= 1
		valid_logic = true
	elif offset == Vector2i(-1, 0): 
		target_log.x += 1
		valid_logic = true
		
	if valid_logic:
		var target_phys = LaneManager.get_tile_from_logical(target_log.x, target_log.y)
		if target_phys != Vector2i(-1, -1):
			var p_origin = LaneManager.tile_to_world(origin)
			var p_target = LaneManager.tile_to_world(target_phys)
			return p_target - p_origin
			
	return std_vec

func _handle_delete_highlight() -> void:
	if not BuildManager.is_building or \
	   not BuildManager.selected_buildable or \
	   BuildManager.selected_buildable.layer != BuildableResource.BuildLayer.TOOL:
		_clear_delete_highlight()
		return

	var mouse_pos = get_global_mouse_position()
	# Check wires first (usually on wire offset) then buildings
	var wire_tile = LaneManager.world_to_tile(mouse_pos - LaneManager.get_layer_offset("wire"))
	var build_tile = LaneManager.world_to_tile(mouse_pos - LaneManager.get_layer_offset("building"))
	
	var target = BuildManager.get_mech_at(build_tile)
	if not target:
		target = BuildManager.wiring_manager.get_wire_instance(wire_tile)

	if target != _hovered_for_deletion:
		_clear_delete_highlight()
		_hovered_for_deletion = target
		
		if is_instance_valid(_hovered_for_deletion):
			_hovered_for_deletion.modulate = Color(1, 0.3, 0.3, 1)

func _clear_delete_highlight() -> void:
	if is_instance_valid(_hovered_for_deletion):
		_hovered_for_deletion.modulate = Color.WHITE 
		
		if _hovered_for_deletion.has_method("_on_power_status_changed") and "is_active" in _hovered_for_deletion:
			_hovered_for_deletion._on_power_status_changed(_hovered_for_deletion.is_active)
			
	_hovered_for_deletion = null
