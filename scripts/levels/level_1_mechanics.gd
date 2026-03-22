class_name Level1Mechanics
extends Node

var current_crunch_number: int = 1

func _ready() -> void:
	randomize_crunch_number()
	if Engine.has_singleton("WaveManager"):
		WaveManager.wave_started.connect(_on_wave_started)

func randomize_crunch_number() -> void:
	current_crunch_number = randi_range(1, 9)

func _on_wave_started(wave_index: int) -> void:
	randomize_crunch_number()
	if randf() <= 0.02:
		trigger_heated_up()

func trigger_heated_up() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		_apply_heated_up(e)
	
	var container = get_tree().current_scene.get_node_or_null("Enemies")
	if container:
		if not container.child_entered_tree.is_connected(_on_enemy_spawned_heated_up):
			container.child_entered_tree.connect(_on_enemy_spawned_heated_up)
			
	if Engine.has_singleton("WaveManager"):
		if not WaveManager.wave_cleared.is_connected(_end_heated_up):
			WaveManager.wave_cleared.connect(_end_heated_up)

func _on_enemy_spawned_heated_up(node: Node) -> void:
	if node.is_in_group("enemies"):
		_apply_heated_up(node)

func _end_heated_up() -> void:
	var container = get_tree().current_scene.get_node_or_null("Enemies")
	if container and container.child_entered_tree.is_connected(_on_enemy_spawned_heated_up):
		container.child_entered_tree.disconnect(_on_enemy_spawned_heated_up)
	if Engine.has_singleton("WaveManager"):
		if WaveManager.wave_cleared.is_connected(_end_heated_up):
			WaveManager.wave_cleared.disconnect(_end_heated_up)

func _apply_heated_up(enemy: Node) -> void:
	var ec = enemy.get_node_or_null("ElementalComponent")
	if ec:
		var igni = ElementManager.get_element("igni")
		if igni:
			ec.add_or_refresh_status(igni, 1)
			var data = ec.get_active_data("igni")
			if data: data.duration = 9999.0
			
	if "speed" in enemy:
		enemy.speed *= 1.5
	if enemy.has_node("MoveComponent"):
		enemy.get_node("MoveComponent").move_speed *= 1.5

func process_damage(amount: float, victim: Node, source: Node) -> Dictionary:
	var crunched = false
	var final_amount = amount
	
	if round(amount) == current_crunch_number and abs(amount - round(amount)) < 0.01:
		final_amount = amount * 2.0
		crunched = true
		
	return { "amount": final_amount, "crunched": crunched }

func get_debug_text() -> String:
	return "\nCrunch Number: %d" % current_crunch_number