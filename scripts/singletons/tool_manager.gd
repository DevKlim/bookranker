class_name ToolManager
extends Node

## Manages tool interactions (Hand Drill, Wrench, etc).
## instantiated by Main.gd to handle tool logic.

var current_action_time: float = 0.0
var active_target_coord: Vector2i = Vector2i(-1, -1)
var is_mining: bool = false
var current_mining_ore: ItemResource = null

# Reference to GameUI for notifications (injected or found)
var _game_ui: GameUI

func _ready() -> void:
	_game_ui = get_node_or_null("/root/Main/GameUI")

func _process(delta: float) -> void:
	if not PlayerManager.equipped_item: 
		_reset_action()
		return
	
	if not PlayerManager.equipped_item.is_tool: 
		return
	
	if PlayerManager.equipped_item.tool_type == "drill":
		_process_drill(delta)

func _process_drill(delta: float) -> void:
	# Only work if clicking "place" (LMB)
	if Input.is_action_pressed("build_place"):
		var mouse_pos = get_viewport().get_mouse_position()
		var cam = get_viewport().get_camera_3d()
		if not cam: return
		
		# Perform Raycast to find tile
		var from = cam.project_ray_origin(mouse_pos)
		var to = from + cam.project_ray_normal(mouse_pos) * 1000.0
		var space = get_viewport().world_3d.direct_space_state
		var query = PhysicsRayQueryParameters3D.create(from, to)
		var result = space.intersect_ray(query)
		
		var hit_pos = Vector3.ZERO
		
		if result:
			hit_pos = result.position
		else:
			# Plane intersection fallback
			var plane = Plane(Vector3.UP, 0)
			var intersect = plane.intersects_ray(from, to)
			if intersect: 
				hit_pos = intersect
			else: 
				_reset_action()
				return
			
		var tile = LaneManager.world_to_tile(hit_pos)
		
		# If we switched tiles, reset progress
		if tile != active_target_coord:
			_reset_action()
			active_target_coord = tile
		
		# Get the ore at this location
		# We check the "floor" position of the tile for the block
		var tile_center_world = LaneManager.tile_to_world(tile)
		var ore_item = LaneManager.get_ore_at_world_pos(tile_center_world)
		
		if ore_item:
			# Check inventory space BEFORE mining
			if not PlayerManager.player_inventory.has_space_for(ore_item):
				_show_notification("Inventory Full!", Color.RED)
				_reset_action()
				return

			is_mining = true
			current_mining_ore = ore_item
			current_action_time += delta
			
			# Visual Feedback
			var req_time = PlayerManager.equipped_item.action_time
			if req_time <= 0: req_time = 0.1
			var pct = min(current_action_time / req_time, 1.0) * 100
			
			_set_debug_text("Mining: %s\nProgress: %.0f%%" % [ore_item.item_name, pct])
			
			if current_action_time >= req_time:
				_complete_mining(ore_item)
		else:
			_reset_action()
	else:
		_reset_action()

## Checks if there is a mineable resource at the given world position.
## Used by Main.gd to update cursor color.
func has_mineable_at(world_pos: Vector3) -> bool:
	var tile = LaneManager.world_to_tile(world_pos)
	var tile_center_world = LaneManager.tile_to_world(tile)
	var ore_item = LaneManager.get_ore_at_world_pos(tile_center_world)
	return ore_item != null

func _complete_mining(ore_item: ItemResource) -> void:
	# Double check space just in case
	if not PlayerManager.player_inventory.has_space_for(ore_item):
		_show_notification("Inventory Full!", Color.RED)
		_reset_action()
		return
		
	var remainder = PlayerManager.player_inventory.add_item(ore_item, 1)
	
	current_action_time = 0.0
	
	if remainder > 0:
		_show_notification("Inventory Full!", Color.RED)
	else:
		# Success - could play sound here
		pass

func _show_notification(text: String, color: Color) -> void:
	if not _game_ui: _game_ui = get_node_or_null("/root/Main/GameUI")
	if _game_ui:
		_game_ui.show_notification(text, color)

func _set_debug_text(text: String) -> void:
	if not _game_ui: _game_ui = get_node_or_null("/root/Main/GameUI")
	if _game_ui:
		_game_ui.set_debug_text(text)

func _reset_action() -> void:
	if is_mining:
		_set_debug_text("") # Clear text
	is_mining = false
	current_mining_ore = null
	current_action_time = 0.0
	active_target_coord = Vector2i(-1, -1)
