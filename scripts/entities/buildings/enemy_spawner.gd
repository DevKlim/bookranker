extends BaseBuilding
class_name EnemySpawnerBuilding

var enemy_dropdown: OptionButton
var hp_spin: SpinBox
var dmg_spin: SpinBox
var spd_spin: SpinBox
var def_spin: SpinBox
var no_ai_check: CheckBox
var no_move_check: CheckBox

var available_enemies: Array =[]

func _ready() -> void:
	super._ready()

func build_custom_ui(container: Control) -> void:
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	container.add_child(vbox)
	
	var instructions = Label.new()
	instructions.text = "Select an enemy to spawn at this location for testing."
	instructions.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
	vbox.add_child(instructions)
	
	enemy_dropdown = OptionButton.new()
	enemy_dropdown.item_selected.connect(_on_enemy_selected)
	vbox.add_child(enemy_dropdown)
	
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 15)
	grid.add_theme_constant_override("v_separation", 8)
	vbox.add_child(grid)
	
	hp_spin = _add_stat_row(grid, "Override HP:")
	dmg_spin = _add_stat_row(grid, "Override Damage:")
	spd_spin = _add_stat_row(grid, "Override Speed:")
	def_spin = _add_stat_row(grid, "Override Defense:")
	
	no_ai_check = CheckBox.new()
	no_ai_check.text = "Disable AI (Force Idle State)"
	no_ai_check.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	no_ai_check.add_theme_color_override("font_hover_color", Color(0.3, 0.3, 0.3))
	no_ai_check.add_theme_color_override("font_pressed_color", Color.BLACK)
	vbox.add_child(no_ai_check)
	
	no_move_check = CheckBox.new()
	no_move_check.text = "Disable Movement (Speed = 0)"
	no_move_check.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	no_move_check.add_theme_color_override("font_hover_color", Color(0.3, 0.3, 0.3))
	no_move_check.add_theme_color_override("font_pressed_color", Color.BLACK)
	vbox.add_child(no_move_check)
	
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 15)
	vbox.add_child(spacer)
	
	var spawn_btn = Button.new()
	spawn_btn.text = "Spawn Selected Enemy"
	spawn_btn.custom_minimum_size = Vector2(0, 40)
	spawn_btn.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	spawn_btn.pressed.connect(_spawn_enemy)
	vbox.add_child(spawn_btn)

	_populate_enemies()

func _add_stat_row(grid: GridContainer, label_text: String) -> SpinBox:
	var lbl = Label.new()
	lbl.text = label_text
	lbl.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(lbl)
	
	var spin = SpinBox.new()
	spin.max_value = 999999
	spin.step = 0.1
	grid.add_child(spin)
	return spin

func _populate_enemies() -> void:
	enemy_dropdown.clear()
	available_enemies.clear()
	
	var dir = DirAccess.open("res://resources/enemies/")
	if dir:
		dir.list_dir_begin()
		var file = dir.get_next()
		while file != "":
			if file.ends_with(".tres"):
				var res = load("res://resources/enemies/" + file) as EnemyResource
				if res:
					available_enemies.append(res)
					enemy_dropdown.add_item(res.enemy_name)
			file = dir.get_next()
	
	if available_enemies.size() > 0:
		_on_enemy_selected(0)

func _on_enemy_selected(idx: int) -> void:
	if idx < 0 or idx >= available_enemies.size(): return
	var res = available_enemies[idx]
	
	hp_spin.value = res.max_health
	dmg_spin.value = res.attack_damage
	spd_spin.value = res.speed
	def_spin.value = res.defense

func _spawn_enemy() -> void:
	var idx = enemy_dropdown.selected
	if idx < 0 or idx >= available_enemies.size(): return
	var res = available_enemies[idx]
	
	if not res.scene: return
	var inst = res.scene.instantiate()
	
	var enemies_container = get_tree().current_scene.get_node_or_null("Enemies")
	if not enemies_container: enemies_container = get_tree().current_scene
	enemies_container.add_child(inst)
	
	inst.global_position = self.global_position + Vector3(0, 5, 0)
	
	var res_dup = res.duplicate()
	var target_speed = spd_spin.value
	if no_move_check.button_pressed:
		target_speed = 0.0
	res_dup.speed = target_speed
	
	inst.initialize_from_resource(res_dup)
	
	if inst.health_component:
		inst.health_component.max_health = hp_spin.value
		inst.health_component.current_health = hp_spin.value
		inst.health_component.defense = def_spin.value
		
	if inst.attacker_component:
		inst.attacker_component.initialize(dmg_spin.value, res_dup.process_speed, res_dup.attack_element)
		
	if inst.move_component:
		inst.move_component.move_speed = target_speed
		
	if no_ai_check.button_pressed:
		inst.is_field_enemy = true
		inst.idle_timer = 999999.0
		inst.aggro_range = 0.0
		inst.current_state = inst.State.IDLE

	if inst.stat_component:
		inst.stat_component._mark_dirty()
