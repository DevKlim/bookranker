class_name BoxFanBuilding
extends BaseBuilding

var attacker: AttackerComponent

func _ready() -> void:
	display_name = "Box Fan"
	super._ready()
	if Engine.is_editor_hint(): return
	
	attacker = get_node_or_null("AttackerComponent")
	if not attacker:
		attacker = AttackerComponent.new()
		attacker.name = "AttackerComponent"
		add_child(attacker)
		
	var attack_res = AttackResource.new()
	attack_res.id = "fan_blow"
	attack_res.cooldown = 1.0
	attack_res.base_damage = 0.0
	attack_res.min_range = 1
	attack_res.max_range = 3
	attack_res.range_width = 0
	attack_res.is_aoe = true
	attack_res.visual_spawn_point = 0
	attack_res.visual_duration = 0.4
	attack_res.set_meta("rotates_with_source", true)
	attack_res.set_meta("targets_buildings", true)
	
	var aero = ElementManager.get_element("aero")
	if aero:
		attack_res.element = aero
		
	attacker.basic_attack = attack_res

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if Engine.is_editor_hint(): return
	
	if not is_active:
		if attacker: attacker.stop_attacking()
		return
	
	if attacker and attacker.attack_timer.is_stopped():
		var dir = Vector3.ZERO
		match output_direction:
			Direction.DOWN: dir = Vector3(0, 0, 1)
			Direction.UP: dir = Vector3(0, 0, -1)
			Direction.LEFT: dir = Vector3(-1, 0, 0)
			Direction.RIGHT: dir = Vector3(1, 0, 0)
		attacker.start_attacking_direction(dir)
