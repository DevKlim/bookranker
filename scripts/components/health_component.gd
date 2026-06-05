class_name HealthComponent
extends Node

signal died(node)
signal health_changed(new_amount, max_amount)
signal energy_changed(new_amount, max_amount)
signal staggered(duration)
signal recovered
signal shield_broken

@export var max_health: float = 100.0:
	set(v):
		max_health = v
		if current_health > max_health: current_health = max_health

@export var max_security: float = 0.0:
	set(v):
		max_security = v
		if current_security > max_security: current_security = max_security

@export var max_energy: float = 50.0:
	set(v):
		max_energy = v
		if current_energy > max_energy: current_energy = max_energy

@export var security_regen_delay: float = 5.0
@export var security_regen_time: float = 5.0

var current_health: float
var current_security: float
var current_energy: float
var defense: float = 0.0
var firewall: float = 0.0
var malware: float = 0.0
var purity: float = 0.0

var _stagger_timer: Timer
var _elemental_component: ElementalComponent
var time_since_last_hit: float = 0.0

func _ready() -> void:
	current_health = max_health
	current_security = max_security
	current_energy = max_energy
	_elemental_component = get_parent().get_node_or_null("ElementalComponent")
	
	_stagger_timer = Timer.new()
	_stagger_timer.one_shot = true
	_stagger_timer.name = "StaggerTimer"
	_stagger_timer.timeout.connect(_on_stagger_end)
	add_child(_stagger_timer)

func _process(delta: float) -> void:
	if max_security > 0.0:
		time_since_last_hit += delta
		if time_since_last_hit >= security_regen_delay and current_security < max_security:
			var regen_amount = (max_security / max(0.1, security_regen_time)) * delta
			current_security = move_toward(current_security, max_security, regen_amount)

func heal(amount: float) -> void:
	if amount <= 0: return
	current_health = min(current_health + amount, max_health)
	emit_signal("health_changed", current_health, max_health)
	_spawn_damage_number(amount, null, false, false, true)

func take_damage(amount: float, _element: Resource = null, source: Node = null) -> float:
	time_since_last_hit = 0.0
	if get_parent().has_node("AbyssShell"):
		var shell = get_parent().get_node("AbyssShell")
		shell.absorb_damage(amount, _element)
		_spawn_damage_number(amount, _element, false, true)
		return 0.0

	var final_amount = amount
	var is_crunched = false
	
	var crit_chance = 0.0
	var crit_mult = 1.0
	if is_instance_valid(source) and source.has_method("get_stat"):
		crit_chance = source.get_stat("luck_stat", 0.0) * 0.01
		crit_mult = 1.5 + (source.get_stat("luck_stat", 0.0) * 0.05)
		
	var my_luck = 0.0
	if get_parent().has_method("get_stat"):
		my_luck = get_parent().get_stat("luck_stat", 0.0)
		
	crit_chance = max(0.0, crit_chance - (my_luck * 0.01))
	crit_mult = max(1.0, crit_mult - (my_luck * 0.05))
	
	if crit_chance > 0.0 and randf() < crit_chance:
		final_amount *= crit_mult
		
	final_amount *= (1.0 + (malware * 0.1))
	var ecto_vuln = get_parent().get_meta("ectomist_vulnerability") if get_parent().has_meta("ectomist_vulnerability") else 0.0
	final_amount *= (1.0 + ecto_vuln / 100.0)
	
	var main_level = get_tree().current_scene
	if main_level and "level_mechanics" in main_level and is_instance_valid(main_level.level_mechanics):
		if main_level.level_mechanics.has_method("process_damage"):
			var result = main_level.level_mechanics.process_damage(final_amount, get_parent(), source)
			final_amount = result.get("amount", final_amount)
			is_crunched = result.get("crunched", false)

	var damage_to_security = min(current_security, final_amount)
	if damage_to_security > 0:
		var old_sec = current_security
		current_security -= damage_to_security
		final_amount -= damage_to_security
		_spawn_damage_number(damage_to_security, null, true)
		
		if old_sec > 0 and current_security <= 0:
			emit_signal("shield_broken")
			if get_tree().root.has_node("GameManager"):
				var gm = get_tree().root.get_node("GameManager")
				if gm.get("vfx_manager"):
					gm.vfx_manager.play_vfx("shield_break", get_parent().global_position)
		
		if get_tree().root.has_node("GameManager"):
			var gm = get_tree().root.get_node("GameManager")
			if gm.get("vfx_manager"):
				gm.vfx_manager.play_vfx("hurt", get_parent().global_position)

	if final_amount > 0:
		var damage_taken = _calculate_mitigation(final_amount)
		_apply_damage(damage_taken)
		
		if damage_taken > 0:
			ElementManager.on_damage_dealt(get_parent(), damage_taken, source)
			if is_crunched: _spawn_crunch_text(damage_taken)
			else: _spawn_damage_number(damage_taken, _element)
			
			if get_tree().root.has_node("GameManager"):
				var gm = get_tree().root.get_node("GameManager")
				if gm.get("vfx_manager"):
					gm.vfx_manager.play_vfx("hurt", get_parent().global_position)
			
		return damage_taken + damage_to_security
	return damage_to_security

func take_damage_no_conduct(amount: float, source: Node = null) -> float:
	time_since_last_hit = 0.0
	if get_parent().has_node("AbyssShell"):
		var shell = get_parent().get_node("AbyssShell")
		shell.absorb_damage(amount, null)
		_spawn_damage_number(amount, null, false, true)
		return 0.0

	var final_amount = amount
	var is_crunched = false
	
	var crit_chance = 0.0
	var crit_mult = 1.0
	if is_instance_valid(source) and source.has_method("get_stat"):
		crit_chance = source.get_stat("luck_stat", 0.0) * 0.01
		crit_mult = 1.5 + (source.get_stat("luck_stat", 0.0) * 0.05)
		
	var my_luck = 0.0
	if get_parent().has_method("get_stat"): my_luck = get_parent().get_stat("luck_stat", 0.0)
		
	crit_chance = max(0.0, crit_chance - (my_luck * 0.01))
	crit_mult = max(1.0, crit_mult - (my_luck * 0.05))
	
	if crit_chance > 0.0 and randf() < crit_chance: final_amount *= crit_mult
	
	final_amount *= (1.0 + (malware * 0.1))
	var ecto_vuln = get_parent().get_meta("ectomist_vulnerability") if get_parent().has_meta("ectomist_vulnerability") else 0.0
	final_amount *= (1.0 + ecto_vuln / 100.0)
	
	var main_level = get_tree().current_scene
	if main_level and "level_mechanics" in main_level and is_instance_valid(main_level.level_mechanics):
		if main_level.level_mechanics.has_method("process_damage"):
			var result = main_level.level_mechanics.process_damage(final_amount, get_parent(), source)
			final_amount = result.get("amount", final_amount)
			is_crunched = result.get("crunched", false)

	var damage_to_security = min(current_security, final_amount)
	if damage_to_security > 0:
		var old_sec = current_security
		current_security -= damage_to_security
		final_amount -= damage_to_security
		_spawn_damage_number(damage_to_security, null, true)
		
		if old_sec > 0 and current_security <= 0:
			emit_signal("shield_broken")
			if get_tree().root.has_node("GameManager"):
				var gm = get_tree().root.get_node("GameManager")
				if gm.get("vfx_manager"):
					gm.vfx_manager.play_vfx("shield_break", get_parent().global_position)
		
		if get_tree().root.has_node("GameManager"):
			var gm = get_tree().root.get_node("GameManager")
			if gm.get("vfx_manager"):
				gm.vfx_manager.play_vfx("hurt", get_parent().global_position)

	if final_amount > 0:
		var damage_taken = _calculate_mitigation(final_amount)
		_apply_damage(damage_taken)
		
		if damage_taken > 0:
			if is_crunched: _spawn_crunch_text(damage_taken)
			else: _spawn_damage_number(damage_taken, null)
			
			if get_tree().root.has_node("GameManager"):
				var gm = get_tree().root.get_node("GameManager")
				if gm.get("vfx_manager"):
					gm.vfx_manager.play_vfx("hurt", get_parent().global_position)
					
		return damage_taken + damage_to_security
	return damage_to_security

func _calculate_mitigation(amount: float) -> float:
	var damage_taken = max(0.0, amount - defense)
	if _elemental_component:
		var mult = _elemental_component.get_stat_modifier("incoming_damage_mult")
		damage_taken *= (1.0 + mult)
		var defense_taken_mult = _elemental_component.get_stat_modifier("damage_taken_mult")
		damage_taken *= (1.0 + defense_taken_mult)
	return damage_taken

func _apply_damage(val: float) -> void:
	current_health -= val
	emit_signal("health_changed", current_health, max_health)
	if current_health <= 0: emit_signal("died", get_parent())

func take_energy_damage(amount: float) -> void:
	current_energy -= amount
	emit_signal("energy_changed", current_energy, max_energy)
	if current_energy <= 0 and _stagger_timer.is_stopped():
		current_energy = 0
		stagger(3.0)

func stagger(base_duration: float) -> void:
	var ping_mult = 1.0
	if get_parent().has_method("get_stat"):
		ping_mult = get_parent().get_stat("ping", 1.0)
		
	var effective_duration = base_duration * (1.0 - purity) * ping_mult
	if _elemental_component:
		for id in _elemental_component.get_active_element_names():
			var res = ElementManager.get_element(id)
			if res and res.cc_scaling_equation != "":
				if ClassDB.class_exists("FormulaHelper") or ResourceLoader.exists("res://scripts/utils/formula_helper.gd"):
					var fh = load("res://scripts/utils/formula_helper.gd")
					if fh:
						var vars = {"base_duration": effective_duration, "purity": purity}
						effective_duration = fh.evaluate(res, res.cc_scaling_equation, vars, effective_duration)
						
	if effective_duration < 0.1: effective_duration = 0.1
	emit_signal("staggered", effective_duration)
	_stagger_timer.start(effective_duration)

func _on_stagger_end() -> void:
	current_energy = max_energy
	emit_signal("energy_changed", current_energy, max_energy)
	emit_signal("recovered")

func _spawn_damage_number(amount: float, element: Resource, is_security: bool = false, is_absorbed: bool = false, is_heal: bool = false) -> void:
	if amount < 0.5: return 
	var label = Label3D.new()
	var font = load("res://assets/fonts/v2-fs-tahoma-8px.otf")
	if step_decimals(amount): label.text = str(round(amount))
	else: label.text = str(int(amount))
	label.pixel_size = 0.03
	if font: label.font = font
	label.font_size = 16
	label.outline_modulate = Color.BLACK
	label.outline_size = 4
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.sorting_offset = amount 
	label.render_priority = 100
	
	if is_heal:
		label.modulate = Color(0.2, 1.0, 0.4)
		label.text = "+" + label.text
	elif is_absorbed:
		label.modulate = Color(0.6, 0.6, 0.6, 0.8)
		label.text += " ABS"
	elif is_security: label.modulate = Color(0.2, 0.6, 1.0)
	elif element and "color" in element: label.modulate = element.color
	else: label.modulate = Color.WHITE
		
	var root = get_tree().current_scene
	if root: root.add_child(label)
	else: get_parent().add_child(label)
		
	var y_off = 2.0
	if get_parent().is_in_group("buildings") or get_parent().is_in_group("allies"):
		y_off = 3.5 # Generous height so numbers clear large entities entirely
		
	var pos = get_parent().global_position + Vector3(0, y_off, 0)
	pos += Vector3(randf_range(-0.5, 0.5), randf_range(0.0, 0.5), randf_range(-0.5, 0.5))
	label.global_position = pos
	
	var tween = label.create_tween()
	tween.tween_property(label, "global_position:y", pos.y + 1.0, 1.0)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(label.queue_free)

func _spawn_crunch_text(amount: float) -> void:
	if amount < 0.5: return
	var label = Label3D.new()
	label.text = str(round(amount))
	label.pixel_size = 0.03
	var font = load("res://assets/fonts/v2-fs-tahoma-8px.otf")
	if font: label.font = font
	label.font_size = 16
	label.modulate = Color.GOLD
	label.outline_modulate = Color.BLACK
	label.outline_size = 4
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.sorting_offset = amount + 100 
	label.render_priority = 100
	
	var root = get_tree().current_scene
	if root: root.add_child(label)
	else: get_parent().add_child(label)
		
	var y_off = 2.0
	if get_parent().is_in_group("buildings") or get_parent().is_in_group("allies"):
		y_off = 3.5
		
	var pos = get_parent().global_position + Vector3(0, y_off, 0)
	pos += Vector3(randf_range(-0.5, 0.5), randf_range(0.0, 0.5), randf_range(-0.5, 0.5))
	label.global_position = pos
	
	var tween = label.create_tween()
	tween.tween_property(label, "global_position:y", pos.y + 1.5, 1.0)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(label.queue_free)
