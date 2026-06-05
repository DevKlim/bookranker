@tool
class_name AttackSpawnerBuilding
extends BaseBuilding

var mode_dropdown: OptionButton
var attack_dropdown: OptionButton
var element_dropdown: OptionButton

var sequence_lbl: Label
var element_sequence: Array = []

var available_attacks: Array = []
var available_elements: Array = []

var attack_container: Control
var element_container: Control

# Building Stat Override References
var stat_spins: Dictionary = {}
var stat_names: Array = [
	"max_health", "security", "max_energy", 
	"power_consumption", "speed", "compute", "networking", 
	"attack_damage", "process_speed", "defense", "firewall", 
	"space", "ping", "malware", "entity_scale"
]

func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint(): return
	if has_meta("is_preview"): return
	
	var meta = PlayerManager.get_meta("active_build_meta") if PlayerManager.has_meta("active_build_meta") else {}
	
	if meta.get("play_on_place", false) == true:
		var grid_comp = get_node_or_null("GridComponent")
		if grid_comp: grid_comp.queue_free() 
		
		visible = false
		call_deferred("_deferred_play_on_place", meta)
	else:
		# Apply overridden stats immediately on real placement
		for sn in stat_names:
			if meta.has(sn):
				if sn in self: set(sn, float(meta[sn]))
				else: self.stats[sn] = float(meta[sn])
		_recalculate_stats()

func _deferred_play_on_place(meta: Dictionary) -> void:
	_load_resources()
	
	for sn in stat_names:
		if meta.has(sn):
			if sn in self: set(sn, float(meta[sn]))
			else: self.stats[sn] = float(meta[sn])
	
	if meta.has("sequence"):
		for e_name in meta["sequence"]:
			for e in available_elements:
				if e.element_name == e_name:
					element_sequence.append(e)
					
	if meta.get("mode", 0) == 0:
		var target_atk_id = meta.get("attack_id", "")
		var atk_idx = -1
		for i in range(available_attacks.size()):
			if available_attacks[i].id == target_atk_id:
				atk_idx = i
				break
		if atk_idx != -1:
			_play_attack_by_index(atk_idx)
		call_deferred("queue_free")
	else:
		_play_element_sequence(
			meta.get("units", 1), 
			meta.get("dmg", 10.0), 
			meta.get("aoe", 2.0), 
			meta.get("cd", 0.5)
		)

func build_custom_ui(container: Control) -> void:
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(400, 450)
	container.add_child(scroll)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(vbox)
	
	var instructions = Label.new()
	instructions.text = "Testing Tool: Play attacks or elements. Adjust stats dynamically."
	instructions.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
	vbox.add_child(instructions)
	
	mode_dropdown = OptionButton.new()
	mode_dropdown.add_item("Attack Mode")
	mode_dropdown.add_item("Element Sequence Mode")
	mode_dropdown.item_selected.connect(_on_mode_changed)
	vbox.add_child(mode_dropdown)
	
	attack_container = VBoxContainer.new()
	vbox.add_child(attack_container)
	
	attack_dropdown = OptionButton.new()
	attack_container.add_child(attack_dropdown)
	
	var play_atk_btn = Button.new()
	play_atk_btn.text = "Play Attack"
	play_atk_btn.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	play_atk_btn.pressed.connect(func(): _play_attack_by_index(attack_dropdown.selected))
	attack_container.add_child(play_atk_btn)
	
	element_container = VBoxContainer.new()
	vbox.add_child(element_container)
	
	element_dropdown = OptionButton.new()
	element_container.add_child(element_dropdown)
	
	var add_el_btn = Button.new()
	add_el_btn.text = "Add Element to Sequence"
	add_el_btn.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	add_el_btn.pressed.connect(_add_element)
	element_container.add_child(add_el_btn)
	
	sequence_lbl = Label.new()
	sequence_lbl.text = "Sequence: None"
	sequence_lbl.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
	sequence_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	element_container.add_child(sequence_lbl)
	
	var clear_el_btn = Button.new()
	clear_el_btn.text = "Clear Sequence"
	clear_el_btn.add_theme_color_override("font_color", Color(0.6, 0.1, 0.1))
	clear_el_btn.pressed.connect(func(): element_sequence.clear(); _update_sequence_lbl())
	element_container.add_child(clear_el_btn)
	
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 15)
	grid.add_theme_constant_override("v_separation", 8)
	element_container.add_child(grid)
	
	stat_spins["units"] = _add_stat_row(grid, "Elemental Units:", 1)
	stat_spins["dmg"] = _add_stat_row(grid, "Source Damage:", 10)
	stat_spins["aoe"] = _add_stat_row(grid, "AOE Radius:", 2.0)
	stat_spins["cd"] = _add_stat_row(grid, "Cooldown (s):", 0.5)
	
	var play_el_btn = Button.new()
	play_el_btn.text = "Play Element Sequence"
	play_el_btn.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	play_el_btn.pressed.connect(func(): _play_element_sequence(int(stat_spins["units"].value), stat_spins["dmg"].value, stat_spins["aoe"].value, stat_spins["cd"].value))
	element_container.add_child(play_el_btn)
	
	var divider = HSeparator.new()
	vbox.add_child(divider)
	
	var stats_lbl = Label.new()
	stats_lbl.text = "Building Stat Overrides"
	stats_lbl.add_theme_color_override("font_color", Color(0.1, 0.1, 0.5))
	vbox.add_child(stats_lbl)
	
	var stats_grid = GridContainer.new()
	stats_grid.columns = 2
	stats_grid.add_theme_constant_override("h_separation", 15)
	stats_grid.add_theme_constant_override("v_separation", 8)
	vbox.add_child(stats_grid)

	_load_resources()
	
	var meta = PlayerManager.get_meta("active_build_meta") if PlayerManager.has_meta("active_build_meta") else {}
	mode_dropdown.selected = meta.get("mode", 0)
	
	if meta.has("attack_id"):
		for i in range(available_attacks.size()):
			if available_attacks[i].id == meta["attack_id"]: attack_dropdown.selected = i
	
	if meta.has("sequence"):
		for e_name in meta["sequence"]:
			for e in available_elements:
				if e.element_name == e_name:
					element_sequence.append(e)
		_update_sequence_lbl()
		
	stat_spins["units"].value = meta.get("units", 1)
	stat_spins["dmg"].value = meta.get("dmg", 10.0)
	stat_spins["aoe"].value = meta.get("aoe", 2.0)
	stat_spins["cd"].value = meta.get("cd", 0.5)
	
	for sn in stat_names:
		var default_val = 0.0
		if sn in self: default_val = float(get(sn))
		elif self.stats.has(sn): default_val = float(self.stats[sn])
		
		stat_spins[sn] = _add_stat_row(stats_grid, sn.capitalize() + ":", meta.get(sn, default_val))
		stat_spins[sn].value_changed.connect(_on_custom_stat_changed.bind(sn))
	
	_on_mode_changed(mode_dropdown.selected)

func _on_custom_stat_changed(val: float, stat_name: String) -> void:
	if stat_name in self: set(stat_name, val)
	else: self.stats[stat_name] = val
	
	var meta = PlayerManager.get_meta("active_build_meta") if PlayerManager.has_meta("active_build_meta") else {}
	meta[stat_name] = val
	PlayerManager.set_meta("active_build_meta", meta)
	
	_recalculate_stats()

func _add_stat_row(grid: GridContainer, label_text: String, default_val: float) -> SpinBox:
	var lbl = Label.new()
	lbl.text = label_text
	lbl.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
	grid.add_child(lbl)
	var spin = SpinBox.new()
	spin.max_value = 9999
	spin.step = 0.1
	spin.value = default_val
	grid.add_child(spin)
	return spin

func _load_resources() -> void:
	if attack_dropdown: attack_dropdown.clear()
	available_attacks.clear()
	var a_dir = DirAccess.open("res://resources/attacks/")
	if a_dir:
		a_dir.list_dir_begin()
		var file = a_dir.get_next()
		while file != "":
			if file.ends_with(".tres"):
				var res = load("res://resources/attacks/" + file) as AttackResource
				if res:
					available_attacks.append(res)
					if attack_dropdown: attack_dropdown.add_item(res.id)
			file = a_dir.get_next()
			
	if element_dropdown: element_dropdown.clear()
	available_elements.clear()
	var e_dir = DirAccess.open("res://resources/elements/")
	if e_dir:
		e_dir.list_dir_begin()
		var file = e_dir.get_next()
		while file != "":
			if file.ends_with(".tres"):
				var res = load("res://resources/elements/" + file) as ElementResource
				if res:
					available_elements.append(res)
					if element_dropdown: element_dropdown.add_item(res.element_name)
			file = e_dir.get_next()

func _on_mode_changed(idx: int) -> void:
	attack_container.visible = (idx == 0)
	element_container.visible = (idx == 1)

func _add_element() -> void:
	var idx = element_dropdown.selected
	if idx >= 0 and idx < available_elements.size():
		element_sequence.append(available_elements[idx])
		_update_sequence_lbl()

func _update_sequence_lbl() -> void:
	if element_sequence.is_empty():
		sequence_lbl.text = "Sequence: None"
	else:
		var names = []
		for e in element_sequence:
			names.append(e.element_name)
		sequence_lbl.text = "Sequence: " + ", ".join(names)

func _play_attack_by_index(idx: int) -> void:
	if idx < 0 or idx >= available_attacks.size(): return
	var atk = available_attacks[idx]
	
	var processor = Node.new()
	processor.set_script(load("res://scripts/components/attack_processor.gd"))
	get_tree().root.add_child(processor) 
	
	var tile = get_tree().root.get_node("LaneManager").world_to_tile(global_position)
	var tile_pos = get_tree().root.get_node("LaneManager").tile_to_world(tile)
	tile_pos.y = global_position.y
	
	var damage = processor.calculate_damage(self, atk)
	processor.spawn_visuals(self, null, tile_pos, atk)
	
	if atk.spawn_projectile:
		processor.spawn_projectile(self, null, tile_pos + Vector3(0,0,1), Vector3(0,0,1), damage, atk)
	else:
		processor.apply_hit(self, null, tile_pos, damage, atk, true)
		
	processor.queue_free()

func _play_element_sequence(units: int, dmg: float, aoe: float, cd: float) -> void:
	if element_sequence.is_empty(): 
		if PlayerManager.get_meta("active_build_meta", {}).get("play_on_place", false): call_deferred("queue_free")
		return
		
	var pos = global_position
	if is_inside_tree():
		var lm = get_node_or_null("/root/LaneManager")
		if lm:
			var tile = lm.world_to_tile(global_position)
			pos = lm.tile_to_world(tile)
			pos.y = global_position.y
			
	_play_next_element_in_sequence(0, units, dmg, aoe, cd, pos)

func _play_next_element_in_sequence(idx: int, units: int, dmg: float, aoe: float, cd: float, pos: Vector3) -> void:
	if idx >= element_sequence.size(): 
		if PlayerManager.get_meta("active_build_meta", {}).get("play_on_place", false): call_deferred("queue_free")
		return
		
	var elem = element_sequence[idx]
	var tree = Engine.get_main_loop() as SceneTree
	var em = tree.root.get_node_or_null("ElementManager") if tree else null
	
	if em:
		var marker = Marker3D.new()
		marker.global_position = pos
		tree.root.add_child(marker)
		var valid_source = self if is_inside_tree() else marker
		
		em.apply_aoe_damage(marker, aoe, dmg, valid_source, false, 0.0)
		var victims = em._get_neighbors_in_radius(marker, aoe)
		for v in victims:
			if is_instance_valid(v):
				em.apply_element(v, elem, valid_source, dmg, units, true)
		marker.queue_free()
				
		var gm = tree.root.get_node_or_null("GameManager")
		if gm and gm.get("vfx_manager"):
			gm.vfx_manager.play_vfx("attack", pos, pos)
			
		var mesh_inst = MeshInstance3D.new()
		var sphere = SphereMesh.new()
		sphere.radius = aoe
		sphere.height = aoe * 2.0
		mesh_inst.mesh = sphere
		tree.root.add_child(mesh_inst)
		mesh_inst.global_position = pos
		
		var mat = StandardMaterial3D.new()
		mat.albedo_color = elem.color if "color" in elem else Color(0.2, 0.8, 1.0)
		mat.albedo_color.a = 0.5
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mesh_inst.material_override = mat
		
		var tween = mesh_inst.create_tween()
		tween.tween_property(mat, "albedo_color:a", 0.0, 0.4)
		tween.tween_callback(mesh_inst.queue_free)
	
	if tree:
		tree.create_timer(max(0.01, cd)).timeout.connect(func():
			_play_next_element_in_sequence(idx + 1, units, dmg, aoe, cd, pos)
		)
