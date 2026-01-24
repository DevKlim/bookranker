class_name ElementalComponent
extends Node

signal status_applied(element_id, units)
signal status_removed(element_id)
signal status_changed(element_id, units)

# Structure: { "element_id": { "resource": ElementResource, "visual": Sprite3D, "units": int, "duration": float } }
var active_statuses: Dictionary = {}
var cooldowns: Dictionary = {}

@export var elemental_cd: float = 0.0

@onready var visual_container: Node3D = Node3D.new()
var _health_component: HealthComponent

func _ready() -> void:
	_health_component = get_parent().get_node_or_null("HealthComponent")
	
	visual_container.name = "StatusVisuals"
	visual_container.position = Vector3(0, 2.0, 0)
	get_parent().call_deferred("add_child", visual_container)

	if get_parent().has_signal("tile_changed"):
		get_parent().tile_changed.connect(_on_parent_tile_changed)

func is_on_cooldown(element_id: String) -> bool:
	if not cooldowns.has(element_id): return false
	return Time.get_ticks_msec() < cooldowns[element_id]

func set_cooldown(element_id: String, duration_sec: float) -> void:
	var mag_def = 0.0
	if _health_component:
		mag_def = _health_component.magical_defense
	
	var final_duration = (duration_sec + elemental_cd) * (1.0 + mag_def)
	if final_duration <= 0: return
	cooldowns[element_id] = Time.get_ticks_msec() + int(final_duration * 1000.0)

func add_or_refresh_status(element: ElementResource, units: int) -> void:
	var id = element.element_name.to_lower()
	var purity = 0.0
	if _health_component: purity = _health_component.purity
	
	var effective_duration = element.duration * (1.0 - purity)
	if effective_duration < 0.1: effective_duration = 0.1
	
	if active_statuses.has(id):
		var data = active_statuses[id]
		data.units = max(data.units, units)
		data.duration = effective_duration
		_update_visual_label(data)
		emit_signal("status_changed", id, data.units)
	else:
		var sprite = Sprite3D.new()
		sprite.texture = element.icon
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.pixel_size = 0.02
		sprite.modulate = element.color
		visual_container.add_child(sprite)
		
		var lbl = Label3D.new()
		lbl.name = "UnitLabel"
		lbl.pixel_size = 0.01
		lbl.position = Vector3(0.3, 0.3, 0)
		lbl.render_priority = 10
		lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.add_child(lbl)
		
		active_statuses[id] = {
			"resource": element,
			"visual": sprite,
			"units": units,
			"duration": effective_duration
		}
		
		# 1. Global Tracking
		ElementManager.track_element_addition(id)
		
		# 2. Spatial Tracking (Optimization)
		if id in ElementManager.SPATIAL_ELEMENTS:
			var tile = LaneManager.world_to_tile(get_parent().global_position)
			ElementManager.register_spatial_status(id, get_parent(), tile)
		
		_update_visual_label(active_statuses[id])
		_arrange_visuals()
		emit_signal("status_applied", id, units)

func consume_units(id: String, amount: int) -> int:
	if not active_statuses.has(id): return 0
	
	var data = active_statuses[id]
	var removed = min(data.units, amount)
	data.units -= removed
	
	if data.units <= 0:
		remove_status(id)
	else:
		_update_visual_label(data)
		emit_signal("status_changed", id, data.units)
		
	return removed

func remove_status(id: String) -> void:
	if active_statuses.has(id):
		# 1. Global Tracking
		ElementManager.track_element_removal(id)
		
		# 2. Spatial Tracking
		if id in ElementManager.SPATIAL_ELEMENTS:
			var tile = LaneManager.world_to_tile(get_parent().global_position)
			ElementManager.unregister_spatial_status(id, get_parent(), tile)

		var data = active_statuses[id]
		if is_instance_valid(data.visual): data.visual.queue_free()
		active_statuses.erase(id)
		call_deferred("_arrange_visuals")
		emit_signal("status_removed", id)

func remove_all_statuses() -> void:
	var keys = active_statuses.keys()
	for id in keys:
		remove_status(id)
	
	active_statuses.clear()
	call_deferred("_arrange_visuals")

func _on_parent_tile_changed(old_tile: Vector2i, new_tile: Vector2i) -> void:
	for id in active_statuses:
		if id in ElementManager.SPATIAL_ELEMENTS:
			ElementManager.update_spatial_status_position(id, get_parent(), old_tile, new_tile)

func _update_visual_label(data: Dictionary) -> void:
	var lbl = data.visual.get_node_or_null("UnitLabel")
	if lbl:
		lbl.text = str(data.units) if data.units > 1 else ""

func _arrange_visuals() -> void:
	if not is_instance_valid(visual_container): return
	var valid_visuals = []
	for id in active_statuses:
		var vis = active_statuses[id].visual
		if is_instance_valid(vis) and not vis.is_queued_for_deletion():
			valid_visuals.append(vis)
	
	var count = valid_visuals.size()
	var spacing = 0.5
	var start_x = -((count - 1) * spacing) / 2.0
	for i in range(count):
		valid_visuals[i].position = Vector3(start_x + (i * spacing), 0, 0)

func get_stat_modifier(stat_key: String) -> float:
	var total = 0.0
	for id in active_statuses:
		var res = active_statuses[id].resource
		if res.stat_modifiers.has(stat_key):
			total += res.stat_modifiers[stat_key]
	return total

func has_element(id: String) -> bool:
	return active_statuses.has(id.to_lower())

func get_active_element_names() -> Array:
	return active_statuses.keys()

func get_active_data(id: String) -> Dictionary:
	return active_statuses.get(id, {})

func _process(delta: float) -> void:
	if active_statuses.is_empty(): return
	var keys = active_statuses.keys()
	
	for id in keys:
		if not active_statuses.has(id): continue
		var data = active_statuses[id]
		data.duration -= delta
		
		if data.duration <= 0:
			remove_status(id)
			continue
		
		if _health_component:
			var res = data.resource
			if res.stat_modifiers.has("damage_per_second"):
				var dmg = res.stat_modifiers["damage_per_second"] * delta
				_health_component.take_damage(dmg)
