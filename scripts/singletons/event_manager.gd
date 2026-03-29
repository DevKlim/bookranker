class_name EventManagerSingleton
extends Node

## Manages random events that can trigger during the game,
## altering stats, giving items, or changing rules dynamically.

var active_events: Array[EventResource] =[]

signal event_started(event: EventResource)
signal event_ended(event: EventResource)

func _process(delta: float) -> void:
	for i in range(active_events.size() - 1, -1, -1):
		var ev = active_events[i]
		if ev.duration > 0.0:
			ev.duration -= delta
			if ev.duration <= 0.0:
				_end_event(ev)
				active_events.remove_at(i)

func trigger_event(event_id: String) -> void:
	var event_path = "res://resources/events/%s.tres" % event_id
	if ResourceLoader.exists(event_path):
		var ev = load(event_path) as EventResource
		if ev:
			# Clone it so we can track the duration independently for active events
			var ev_instance = ev.duplicate()
			_apply_event(ev_instance)

func _apply_event(ev: EventResource) -> void:
	print("EventManager: Event Triggered: ", ev.event_name)
	
	match ev.effect_type:
		"give_item":
			var item_id = ev.parameters.get("item_id", "")
			var count = int(ev.parameters.get("count", 1))
			var item_path = "res://resources/items/%s.tres" % item_id
			if ResourceLoader.exists(item_path):
				var item = load(item_path)
				if PlayerManager.game_inventory:
					PlayerManager.game_inventory.add_item(item, count)
		"stat_multiplier":
			var stat_name = ev.parameters.get("stat_name", "")
			var multiplier = float(ev.parameters.get("multiplier", 1.0))
			if stat_name != "":
				var current = GameManager.get_stat_multiplier(stat_name)
				GameManager.set_global_stat(stat_name, current * multiplier)
		"spawn_entity":
			# Extensible base case for modders to add spawns
			pass
	
	if ev.duration > 0.0:
		active_events.append(ev)
	emit_signal("event_started", ev)

func _end_event(ev: EventResource) -> void:
	print("EventManager: Event Ended: ", ev.event_name)
	
	match ev.effect_type:
		"stat_multiplier":
			var stat_name = ev.parameters.get("stat_name", "")
			var multiplier = float(ev.parameters.get("multiplier", 1.0))
			if stat_name != "":
				var current = GameManager.get_stat_multiplier(stat_name)
				# Revert the multiplier
				GameManager.set_global_stat(stat_name, current / multiplier)
				
	emit_signal("event_ended", ev)

func clear_active_events() -> void:
	for ev in active_events:
		_end_event(ev)
	active_events.clear()
