extends Node
class_name DPSMeterComponent

var total_damage: float = 0.0
var _damage_history: Array = []
var label: Label3D
var _last_health: float = -1.0

func _ready() -> void:
	label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 2.5, 0)
	label.pixel_size = 0.02
	label.font_size = 48
	label.outline_modulate = Color.BLACK
	label.outline_size = 6
	
	var font = load("res://assets/fonts/v2-fs-tahoma-8px.otf")
	if font: label.font = font
	
	label.text = "DPS: 0.0\nTotal: 0"
	
	get_parent().call_deferred("add_child", label)
	
	var hc = get_parent().get_node_or_null("HealthComponent")
	if hc:
		hc.health_changed.connect(_on_health_changed)

func _on_health_changed(new_val: float, max_val: float) -> void:
	if _last_health < 0:
		_last_health = max_val
	var dmg = _last_health - new_val
	_last_health = new_val
	
	if dmg > 0:
		total_damage += dmg
		_damage_history.append({"time": Time.get_ticks_msec(), "amount": dmg})

func _process(_delta: float) -> void:
	var current_time = Time.get_ticks_msec()
	var dps = 0.0
	
	# Purge history older than 1 second while summing recent damage
	for i in range(_damage_history.size() - 1, -1, -1):
		if current_time - _damage_history[i].time > 1000:
			_damage_history.remove_at(i)
		else:
			dps += _damage_history[i].amount
			
	if is_instance_valid(label):
		label.text = "DPS: %.1f\nTotal: %.1f" % [dps, total_damage-9000000]

