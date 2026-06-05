class_name ToolManager
extends Node

## Manages active tool actions and mining states. Delegates logic to individual tool scripts.

static var instance: ToolManager

var active_miners: Dictionary = {} # { AgentNode: { "target": Node/Resource, "time": float, "max_time": float, "type": String, "tile": Vector2i } }

var _game_ui: GameUI

func _enter_tree() -> void:
	instance = self

func _ready() -> void:
	_game_ui = get_node_or_null("/root/Main/GameUI")

func _process(delta: float) -> void:
	# Process Player Auto-Mining
	var player = get_tree().get_first_node_in_group("player")
	var player_mining = false
	var tool_item = null
	
	if player and player.has_method("_get_item_in_slot"):
		tool_item = player._get_item_in_slot(0) # SLOT_TOOL
		
	if player and tool_item and tool_item.is_tool:
		var target_data = _find_target_at_agent(player, tool_item)
		if not target_data.is_empty():
			# Auto-mine if in Tool Mode
			if player.current_mode == 1: # AllyMode.TOOL is 1
				player_mining = true
				if not active_miners.has(player):
					request_mining(player, tool_item)
				else:
					if active_miners[player].target != target_data.target:
						_reset_player_mining()
						request_mining(player, tool_item)
			else:
				if not Input.is_action_pressed("build_place") or _is_ui_blocked():
					_reset_player_mining()
		else:
			if not Input.is_action_pressed("build_place") or _is_ui_blocked():
				_reset_player_mining()
	else:
		_reset_player_mining()
	
	# Manual Mining Support
	if Input.is_action_pressed("build_place") and not _is_ui_blocked() and not player_mining:
		# Check if the player is actually in tool mode to prevent mining while deselected/idle
		if player and player.current_mode == 1 and tool_item and tool_item.is_tool:
			request_mining(player, tool_item)
	elif not player_mining and not Input.is_action_pressed("build_place"):
		if player and player.current_mode != 1:
			_reset_player_mining()

	# Process Active Miners
	var finished_agents =[]
	for agent in active_miners:
		if not is_instance_valid(agent): 
			finished_agents.append(agent)
			continue
			
		var data = active_miners[agent]
		data.time += delta
		
		if data.time >= data.max_time:
			_complete_mining(agent, data)
			finished_agents.append(agent)
	
	for agent in finished_agents:
		active_miners.erase(agent)

func request_mining(agent: Node3D, tool_item: ItemResource) -> void:
	if active_miners.has(agent): return # Already mining
	
	var target_data = _find_target_at_agent(agent, tool_item)
	if target_data.is_empty(): return
	
	active_miners[agent] = {
		"target": target_data.target,
		"type": target_data.type,
		"tile": target_data.get("tile", Vector2i.ZERO),
		"time": 0.0,
		"max_time": tool_item.action_time,
		"tool": tool_item
	}

# Public helper for checking highlighting on hover. Uses the assigned tool script if available.
func has_mineable_at(world_pos: Vector3, tool_item: ItemResource = null) -> bool:
	if not tool_item:
		var player = get_tree().get_first_node_in_group("player")
		if player and player.has_method("_get_item_in_slot"):
			tool_item = player._get_item_in_slot(0) # Active slot tool
			
	var tile = LaneManager.world_to_tile(world_pos)
	
	if tool_item and tool_item.has_method("get_artifact_instance"):
		var artifact = tool_item.get_artifact_instance()
		if artifact and artifact.has_method("can_mine_tile"):
			return artifact.can_mine_tile(tile)
	
	# Default Fallback checks basic clutter and default ores
	if LaneManager.get_entity_at(tile, "building") is ClutterObject:
		return true
	var tile_world = LaneManager.tile_to_world(tile)
	if LaneManager.get_ore_at_world_pos(tile_world):
		return true
		
	return false

func _find_target_at_agent(agent: Node3D, tool_item: ItemResource) -> Dictionary:
	if tool_item and tool_item.has_method("get_artifact_instance"):
		var artifact = tool_item.get_artifact_instance()
		if artifact and artifact.has_method("get_valid_target"):
			return artifact.get_valid_target(agent, tool_item)
			
	# Default Fallback behavior if no script is attached to the item resource
	var tile = LaneManager.world_to_tile(agent.global_position)
	var clutter = LaneManager.get_entity_at(tile, "building")
	if clutter is ClutterObject:
		return { "target": clutter, "type": "clutter", "tile": tile }
	return {}

func _complete_mining(agent: Node3D, data: Dictionary) -> void:
	var tool_item = data.get("tool") as ItemResource
	var handled = false
	
	# Pass processing to the external tool script
	if tool_item and tool_item.has_method("get_artifact_instance"):
		var artifact = tool_item.get_artifact_instance()
		if artifact and artifact.has_method("process_mine_completion"):
			handled = artifact.process_mine_completion(agent, data, tool_item)
			
	# Fallback if standard script doesn't override resolution handling fully
	if not handled:
		if data.type == "clutter":
			var clutter = data.target as ClutterObject
			if is_instance_valid(clutter):
				clutter.take_damage(9999.0)

func _is_ui_blocked() -> bool:
	if BuildManager.is_building: return true
	if _game_ui and _game_ui.is_any_menu_open(): return true
	return false

func _reset_player_mining() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player and active_miners.has(player):
		active_miners.erase(player)

func _show_notification(text: String, color: Color) -> void:
	if _game_ui: _game_ui.show_notification(text, color)
