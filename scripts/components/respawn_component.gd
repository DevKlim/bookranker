class_name RespawnComponent
extends Node

var body: CharacterBody3D
var respawns_count: int = 0
var respawns_unlimited: bool = false
var respawns_cooldown: float = 5.0

func _ready() -> void:
	body = get_parent()
	call_deferred("_cache_components")
	
func _cache_components() -> void:
	var hc = body.get_node_or_null("HealthComponent")
	if hc: hc.died.connect(on_died)

func setup(count: int, unlimited: bool, cooldown: float) -> void:
	respawns_count = count
	respawns_unlimited = unlimited
	respawns_cooldown = cooldown

func on_died(_node) -> void:
	if body and "is_dead" in body and body.is_dead: return
	if body and "is_dead" in body: body.is_dead = true
	
	var is_player = body.is_in_group("player") or body.name == "Player"
	var inv = body.get_node_or_null("InventoryComponent")
	
	if inv and not is_player:
		for i in range(inv.slots.size()):
			inv.slots[i] = null
		inv.inventory_changed.emit()

	var main = get_tree().current_scene
	if main and main.get("selection_controller"):
		var sc = main.selection_controller
		if sc.selected_allies.has(body):
			sc.selected_allies.erase(body)
			if body.has_method("set_selected"): body.set_selected(false)
			if is_player: PlayerManager.set("is_player_selected", false)
			if sc.selected_allies.is_empty():
				sc.deselect_all()
			else:
				if sc.selected_ally == body:
					sc.selected_ally = sc.selected_allies.back()
					if "game_ui" in main and main.game_ui: main.game_ui.set_selected_ally(sc.selected_ally)
					
	var can_respawn = respawns_unlimited or respawns_count > 0 or is_player
	
	if can_respawn:
		if not respawns_unlimited and not is_player:
			respawns_count -= 1
		
		body.visible = false
		body.collision_layer = 0
		body.set_process(false)
		body.set_physics_process(false)
		
		if "current_mode" in body: body.current_mode = 0 # IDLE
		var ac = body.get_node_or_null("AttackerComponent")
		if ac: ac.stop_attacking()
		var mc = body.get_node_or_null("MoveComponent")
		if mc: mc.stop_moving()
		if ToolManager.instance and ToolManager.instance.active_miners.has(body):
			ToolManager.instance.active_miners.erase(body)
		
		var ui = get_node_or_null("/root/Main/GameUI")
		if not ui and main and "game_ui" in main: ui = main.game_ui
		
		var r_cd = respawns_cooldown if respawns_cooldown > 0.0 else 5.0
		if ui:
			var lives_left = "Unlimited" if (respawns_unlimited or is_player) else str(respawns_count) + " left"
			ui.register_ally_respawn(body.get("display_name"), r_cd, lives_left)
			
		get_tree().create_timer(r_cd).timeout.connect(respawn)
	else:
		body.queue_free()

func respawn() -> void:
	if not is_instance_valid(body) or not body.is_inside_tree(): return
	if body and "is_dead" in body: body.is_dead = false
	
	var respawn_pos = Vector3.ZERO
	if Engine.has_singleton("LaneManager"):
		var middle_lane = int(LaneManager.num_lanes / 2.0)
		var target_tile = Vector2i(LaneManager.generation_offset.x, middle_lane + LaneManager.generation_offset.y)
		respawn_pos = LaneManager.tile_to_world(target_tile)
		respawn_pos.y = 1.0
	else:
		respawn_pos = Vector3(0.5, 1.0, 0.5)

	var fall_start_pos = respawn_pos
	fall_start_pos.y += 15.0
	body.global_position = fall_start_pos
	
	var tween = body.create_tween()
	tween.tween_property(body, "global_position:y", respawn_pos.y, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	var mc = body.get_node_or_null("MoveComponent")
	if mc:
		mc.target_position = respawn_pos
		mc.stop_moving()
	
	if "target_pos" in body: body.set("target_pos", respawn_pos)
	if "is_moving" in body: body.set("is_moving", false)
	
	var hc = body.get_node_or_null("HealthComponent")
	if hc: hc.current_health = hc.max_health
	
	body.visible = true
	body.collision_layer = 4
	body.set_process(true)
	body.set_physics_process(true)
