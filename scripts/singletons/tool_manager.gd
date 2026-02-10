class_name ToolManager
extends Node

## Manages tool interactions (Hand Drill, Wrench, etc) and mining logic.

static var instance: ToolManager

var active_miners: Dictionary = {} # { AgentNode: { "target": Node/Resource, "time": float, "max_time": float, "type": String } }

# Visuals for Player
var _ui_layer: CanvasLayer
var _mining_bar: ProgressBar
var _game_ui: GameUI

func _enter_tree() -> void:
	instance = self

func _ready() -> void:
	_game_ui = get_node_or_null("/root/Main/GameUI")
	_setup_mining_visuals()

func _setup_mining_visuals() -> void:
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 100 
	add_child(_ui_layer)
	
	_mining_bar = ProgressBar.new()
	_mining_bar.show_percentage = false
	_mining_bar.custom_minimum_size = Vector2(60, 8)
	_mining_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.6)
	_mining_bar.add_theme_stylebox_override("background", bg)
	
	var fg = StyleBoxFlat.new()
	fg.bg_color = Color(0.4, 1.0, 0.4, 1) 
	_mining_bar.add_theme_stylebox_override("fill", fg)
	
	_mining_bar.visible = false
	_ui_layer.add_child(_mining_bar)

func _process(delta: float) -> void:
	# Process Player Input (Manual)
	if Input.is_action_pressed("build_place") and not _is_ui_blocked():
		var player = get_tree().get_first_node_in_group("player")
		if player and PlayerManager.equipped_item and PlayerManager.equipped_item.is_tool:
			request_mining(player, PlayerManager.equipped_item)
	else:
		_reset_player_mining()

	# Process Active Miners
	var finished_agents = []
	for agent in active_miners:
		if not is_instance_valid(agent): 
			finished_agents.append(agent)
			continue
			
		var data = active_miners[agent]
		data.time += delta
		
		# UI Update for Player only
		if agent.is_in_group("player"):
			_update_visual_bar(min(data.time / data.max_time, 1.0) * 100)
		
		if data.time >= data.max_time:
			_complete_mining(agent, data)
			finished_agents.append(agent)
	
	for agent in finished_agents:
		active_miners.erase(agent)
		if agent.is_in_group("player"):
			_hide_visual_bar()

func request_mining(agent: Node3D, tool_item: ItemResource) -> void:
	if active_miners.has(agent): return # Already mining
	
	var target_data = _find_target_at_agent(agent)
	if target_data.is_empty(): return
	
	var time = tool_item.action_time
	
	active_miners[agent] = {
		"target": target_data.target,
		"type": target_data.type,
		"time": 0.0,
		"max_time": time,
		"tool": tool_item
	}

# Public helper for checking highlighting
func has_mineable_at(world_pos: Vector3) -> bool:
	var tile = LaneManager.world_to_tile(world_pos)
	
	if LaneManager.get_entity_at(tile, "building") is ClutterObject:
		return true
	
	var tile_world = LaneManager.tile_to_world(tile)
	if LaneManager.get_ore_at_world_pos(tile_world):
		return true
		
	return false

func _find_target_at_agent(agent: Node3D) -> Dictionary:
	var tile = LaneManager.world_to_tile(agent.global_position)
	
	# Priority 1: Clutter (Adjacent check allowed for player, but Ally usually stands on/near)
	# Simplified: Check tile center
	var clutter = LaneManager.get_entity_at(tile, "building")
	if clutter is ClutterObject:
		return { "target": clutter, "type": "clutter" }
	
	# Priority 2: Ore
	var tile_world = LaneManager.tile_to_world(tile)
	var ore = LaneManager.get_ore_at_world_pos(tile_world)
	if ore:
		return { "target": ore, "type": "ore" }
		
	return {}

func _complete_mining(agent: Node3D, data: Dictionary) -> void:
	var inv: InventoryComponent = null
	if agent.is_in_group("player"):
		inv = PlayerManager.game_inventory
	elif agent.has_method("get_node_or_null"):
		inv = agent.get_node_or_null("InventoryComponent")
	
	if not inv: return

	if data.type == "ore":
		var ore = data.target as ItemResource
		if inv.has_space_for(ore):
			inv.add_item(ore, 1)
		elif agent.is_in_group("player"):
			_show_notification("Inventory Full!", Color.RED)

	elif data.type == "clutter":
		var clutter = data.target as ClutterObject
		if is_instance_valid(clutter):
			# Clutter drops are handled by its _on_died, which tries to give to PlayerManager
			# We need to ensure Clutter gives to the *agent* who mined it.
			# For now, Clutter simply dies.
			clutter.take_damage(9999.0)

func _is_ui_blocked() -> bool:
	if BuildManager.is_building: return true
	if _game_ui and _game_ui.is_any_menu_open(): return true
	return false

func _reset_player_mining() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player and active_miners.has(player):
		active_miners.erase(player)
		_hide_visual_bar()

func _update_visual_bar(percent: float) -> void:
	if _mining_bar:
		_mining_bar.visible = true
		_mining_bar.value = percent
		var mouse_pos = _mining_bar.get_viewport().get_mouse_position()
		_mining_bar.position = mouse_pos + Vector2(-30, 32)

func _hide_visual_bar() -> void:
	if _mining_bar: _mining_bar.visible = false

func _show_notification(text: String, color: Color) -> void:
	if _game_ui: _game_ui.show_notification(text, color)
