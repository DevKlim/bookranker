@tool
class_name BaseBuilding
extends StaticBody3D

signal stats_updated

enum Direction { DOWN, LEFT, UP, RIGHT }

# Components
var power_consumer: PowerConsumerComponent
var health_component: HealthComponent
var inventory_component: InventoryComponent
var inventory_component_alt: InventoryComponent # Handle "InputInventory" legacy
var elemental_component: ElementalComponent

var mod_inventory: InventoryComponent
var mod_handler: ModHandlerComponent

var grid_component: Node
@export var powered_color: Color = Color(1, 1, 1, 1)
@export var unpowered_color: Color = Color(0.2, 0.2, 0.2, 1)

# Identity
@export var display_name: String = ""

@export_group("Stats")
@export var max_health: float = 100.0
@export var max_energy: float = 50.0
@export var power_consumption: float = 5.0
@export var efficiency: float = 1.0 
@export var lux_stat: float = 0.0 
@export var luck_stat: float = 0.0

@export_group("Formulas")
@export var health_equation: String = ""
@export var defense_equation: String = ""
@export var power_usage_equation: String = ""
@export var processing_speed_equation: String = ""
@export var stat_weights: Dictionary = {}

@export_group("I/O Configuration")
var input_mask: int = 0
var output_mask: int = 0

@export_flags("Down:1", "Left:2", "Up:4", "Right:8") var default_input_mask: int = 15:
	set(value):
		default_input_mask = value
		_update_masks_from_current_rotation()

@export_flags("Down:1", "Left:2", "Up:4", "Right:8") var default_output_mask: int = 15:
	set(value):
		default_output_mask = value
		_update_masks_from_current_rotation()

@export var has_input: bool = true
@export var has_output: bool = true

# Legacy Single Direction Support
var output_direction: Direction = Direction.DOWN
var input_direction: Direction = Direction.UP

@export_group("Layout")
@export var layout_config: Array =[]

var visual_offset: Vector3 = Vector3.ZERO
var is_active: bool = false
var is_staggered: bool = false
var stats: Dictionary = {}

# Damage Visuals
var _tint_tween: Tween
var _tint_materials: Array[StandardMaterial3D] =[]
var _tint_sprites: Array[Node] =[]
var _output_timer: float = 0.0

func _get_main_sprite() -> AnimatedSprite3D:
	return get_node_or_null("AnimatedSprite3D")

func _ready() -> void:
	if Engine.is_editor_hint(): return
	if has_meta("is_preview"): return
	
	add_to_group("buildings")
	
	if Engine.has_singleton("GameManager") and GameManager.current_state == GameManager.GameState.IDLE:
		var n = name.to_lower()
		if "cubby" in n or is_in_group("loot_buildings"):
			if not has_node("LootComponent"):
				var lc = LootComponent.new()
				lc.name = "LootComponent"
				add_child(lc)
	
	if display_name == "":
		var n = name
		if "@" in n: display_name = "Building"
		else: display_name = n.rstrip("0123456789")
	
	_update_masks_from_current_rotation()
	
	if input_mask > 0: has_input = true
	if output_mask > 0: has_output = true
	
	_setup_visuals()
	_setup_grid_component()
	_setup_elemental_component() 
	_setup_power_component()
	_setup_health_component()
	_setup_inventory_component()
	
	_cache_visual_materials(self)
	
	_on_power_status_changed(false)

func _physics_process(delta: float) -> void:
	if not is_active: return
	
	if has_output and inventory_component:
		_output_timer -= delta
		if _output_timer <= 0:
			_output_timer = 0.5
			try_output_from_inventory(inventory_component)

func _cache_visual_materials(node: Node) -> void:
	if node is Sprite3D or node is AnimatedSprite3D:
		_tint_sprites.append(node)
	elif node is MeshInstance3D:
		if node.mesh:
			var surf_count = node.mesh.get_surface_count()
			for i in range(surf_count):
				var mat = node.get_active_material(i)
				if not mat: mat = StandardMaterial3D.new()
				if mat is StandardMaterial3D:
					var unique_mat = mat.duplicate()
					node.set_surface_override_material(i, unique_mat)
					_tint_materials.append(unique_mat)
	for child in node.get_children():
		_cache_visual_materials(child)

func _setup_visuals() -> void:
	var sprite = _get_main_sprite()
	if sprite: 
		sprite.position += visual_offset
	else:
		var visual = get_node_or_null("BlockVisual")
		if visual: 
			visual.position += visual_offset

func _setup_grid_component() -> void:
	if not has_node("GridComponent"):
		grid_component = GridComponent.new()
		grid_component.name = "GridComponent"
		grid_component.layer = "building"
		if "snap_to_grid" in grid_component:
			grid_component.snap_to_grid = true
		add_child(grid_component)
	else:
		grid_component = get_node("GridComponent")

func _setup_elemental_component() -> void:
	elemental_component = get_node_or_null("ElementalComponent")
	if not elemental_component:
		elemental_component = ElementalComponent.new()
		elemental_component.name = "ElementalComponent"
		add_child(elemental_component)
		
	if not elemental_component.is_connected("status_applied", _on_element_changed):
		elemental_component.status_applied.connect(_on_element_changed)
	if not elemental_component.is_connected("status_removed", _on_element_changed):
		elemental_component.status_removed.connect(_on_element_changed)
	if not elemental_component.is_connected("status_changed", _on_element_changed):
		elemental_component.status_changed.connect(_on_element_changed)

func _on_element_changed(_id = "", _units = 0) -> void:
	emit_signal("stats_updated")

func _setup_power_component() -> void:
	power_consumer = get_node_or_null("PowerConsumerComponent")
	if not power_consumer:
		power_consumer = PowerConsumerComponent.new()
		power_consumer.name = "PowerConsumerComponent"
		add_child(power_consumer)
	
	_update_power_consumption()
	PowerGridManager.register_consumer(power_consumer)

func _update_power_consumption() -> void:
	if not power_consumer: return
	var eff = get_stat("efficiency", efficiency)
	if eff <= 0.1: eff = 0.1
	var final_power = power_consumption / eff
	
	if power_usage_equation != "":
		if ClassDB.class_exists("FormulaHelper") or ResourceLoader.exists("res://scripts/utils/formula_helper.gd"):
			var fh = load("res://scripts/utils/formula_helper.gd")
			if fh:
				var vars = {"power_consumption": power_consumption, "efficiency": eff, "final_power": final_power}
				for k in stat_weights.keys():
					vars[k+"_weight"] = stat_weights[k]
					vars[k] = get_stat(k, 0.0)
				final_power = fh.evaluate(self, power_usage_equation, vars, final_power)
				
	power_consumer.power_consumption = final_power

func _setup_health_component() -> void:
	health_component = get_node_or_null("HealthComponent")
	if not health_component:
		health_component = HealthComponent.new()
		health_component.name = "HealthComponent"
		add_child(health_component)
	
	var mod_health = max_health * GameManager.get_stat_multiplier("building_health")
	health_component.max_health = mod_health
	health_component.current_health = mod_health
	health_component.max_energy = max_energy
	health_component.current_energy = max_energy
	
	health_component.died.connect(_on_died)
	health_component.staggered.connect(_on_staggered)
	health_component.recovered.connect(_on_recovered)
	health_component.health_changed.connect(_on_health_changed)

func _on_health_changed(new_val, old_val) -> void:
	if new_val < old_val:
		_flash_damage()
	emit_signal("stats_updated")

func _flash_damage() -> void:
	if _tint_tween: _tint_tween.kill()
	_tint_tween = create_tween()
	
	var base_col = powered_color if is_active else unpowered_color
	var damage_col = Color(1.0, 0.4, 0.4, 1.0)
	
	_tint_tween.tween_method(_apply_tint_ratio.bind(base_col, damage_col), 1.0, 0.0, 0.3)

func _apply_tint_ratio(ratio: float, base: Color, dmg: Color) -> void:
	var final = base.lerp(dmg, ratio)
	for s in _tint_sprites:
		if is_instance_valid(s): s.modulate = final
	for m in _tint_materials:
		if is_instance_valid(m): m.albedo_color = final

func _setup_inventory_component() -> void:
	inventory_component = get_node_or_null("InventoryComponent")
	if not inventory_component:
		inventory_component = get_node_or_null("InputInventory")

	mod_inventory = InventoryComponent.new()
	mod_inventory.name = "ModInventory"
	mod_inventory.max_slots = 3
	mod_inventory.set_capacity(3)
	
	# Restrict slots to Mod items
	var ItemResClass = load("res://scripts/resources/item_resource.gd")
	if ItemResClass and "MOD" in ItemResClass.EquipmentType.keys():
		for i in range(3):
			mod_inventory.set_slot_restriction(i, ItemResClass.EquipmentType.MOD)
	
	mod_inventory.custom_filter = func(item):
		var t = item.get("mod_type")
		if not t or t == "":
			if "modifiers" in item and item.modifiers.has("type"):
				t = item.modifiers.get("type")
			elif "type" in item:
				t = item.get("type")
		return t == "building"
		
	add_child(mod_inventory)
	
	mod_handler = ModHandlerComponent.new()
	mod_handler.name = "ModHandlerComponent"
	add_child(mod_handler)
	mod_handler.initialize(self, mod_inventory)
	mod_handler.mods_updated.connect(_recalculate_stats)

func _recalculate_stats() -> void:
	if health_component:
		var base_max_hp = max_health * GameManager.get_stat_multiplier("building_health")
		var hp_mult = mod_handler.get_stat_modifier("max_health_mult")
		var final_hp = base_max_hp * (1.0 + hp_mult)
		
		if health_equation != "":
			if ClassDB.class_exists("FormulaHelper") or ResourceLoader.exists("res://scripts/utils/formula_helper.gd"):
				var fh = load("res://scripts/utils/formula_helper.gd")
				if fh:
					var vars = {"base_health": max_health, "final_health": final_hp, "hp_mult": hp_mult}
					for k in stat_weights.keys(): vars[k+"_weight"] = stat_weights[k]; vars[k] = get_stat(k, 0.0)
					final_hp = fh.evaluate(self, health_equation, vars, final_hp)
					
		health_component.max_health = final_hp
		if health_component.current_health > health_component.max_health:
			health_component.current_health = health_component.max_health
			
		var def_val = get_stat("defense", 0.0)
		if defense_equation != "":
			if ClassDB.class_exists("FormulaHelper") or ResourceLoader.exists("res://scripts/utils/formula_helper.gd"):
				var fh = load("res://scripts/utils/formula_helper.gd")
				if fh:
					var vars = {"base_defense": def_val}
					for k in stat_weights.keys(): vars[k+"_weight"] = stat_weights[k]; vars[k] = get_stat(k, 0.0)
					def_val = fh.evaluate(self, defense_equation, vars, def_val)
		health_component.defense = def_val

		var base_max_energy = max_energy
		var energy_flat = mod_handler.get_stat_modifier("max_energy_flat")
		health_component.max_energy = base_max_energy + energy_flat
		if health_component.current_energy > health_component.max_energy:
			health_component.current_energy = health_component.max_energy
			
	if has_node("CrafterComponent"):
		var crafter = get_node("CrafterComponent")
		var pspeed = get_stat("processing_speed", 1.0)
		if processing_speed_equation != "":
			if ClassDB.class_exists("FormulaHelper") or ResourceLoader.exists("res://scripts/utils/formula_helper.gd"):
				var fh = load("res://scripts/utils/formula_helper.gd")
				if fh:
					var vars = {"base_speed": pspeed}
					for k in stat_weights.keys(): vars[k+"_weight"] = stat_weights[k]; vars[k] = get_stat(k, 0.0)
					pspeed = fh.evaluate(self, processing_speed_equation, vars, pspeed)
		crafter.processing_speed_mult = pspeed
		
	_update_power_consumption()
	emit_signal("stats_updated")

func _on_power_status_changed(has_power: bool) -> void:
	is_active = has_power and not is_staggered
	
	if _tint_tween and _tint_tween.is_running(): return

	var target_col = powered_color if has_power else unpowered_color
	var animated_sprite = _get_main_sprite()
	if is_instance_valid(animated_sprite):
		animated_sprite.modulate = target_col
	
	for m in _tint_materials:
		if is_instance_valid(m): m.albedo_color = target_col
	
	set_process(is_active)
	set_physics_process(is_active)
	
	var shooter = get_node_or_null("ShooterComponent")
	if shooter: shooter.set_process(is_active)
	
	emit_signal("stats_updated")

func _on_staggered(_duration: float) -> void:
	is_staggered = true
	_on_power_status_changed(power_consumer.has_power if power_consumer else false)

func _on_recovered() -> void:
	is_staggered = false
	_on_power_status_changed(power_consumer.has_power if power_consumer else false)

func set_build_rotation(rotation_val: Variant) -> void:
	var dir_idx: int = 0
	if typeof(rotation_val) == TYPE_INT: dir_idx = rotation_val
	elif typeof(rotation_val) == TYPE_STRING:
		var s = String(rotation_val)
		if s.ends_with("down"): dir_idx = 0
		elif s.ends_with("left"): dir_idx = 1
		elif s.ends_with("up"): dir_idx = 2
		elif s.ends_with("right"): dir_idx = 3

	output_direction = dir_idx as Direction
	match output_direction:
		Direction.DOWN: input_direction = Direction.UP
		Direction.LEFT: input_direction = Direction.RIGHT
		Direction.UP:   input_direction = Direction.DOWN
		Direction.RIGHT:input_direction = Direction.LEFT
		_: input_direction = Direction.UP

	var shift = (dir_idx + 2) % 4
	input_mask = _rotate_bitmask(int(default_input_mask), shift)
	output_mask = _rotate_bitmask(int(default_output_mask), shift)
	
	var rads = 0.0
	match dir_idx:
		0: rads = PI       
		1: rads = PI * 0.5 
		2: rads = 0.0      
		3: rads = -PI * 0.5
	rotation = Vector3(0, rads, 0)

func _update_masks_from_current_rotation() -> void:
	var y_rot = wrapf(rotation.y, -PI, PI)
	var dir_idx = 2
	if is_equal_approx(abs(y_rot), PI): dir_idx = 0
	elif is_equal_approx(y_rot, PI * 0.5): dir_idx = 1
	elif is_equal_approx(y_rot, -PI * 0.5): dir_idx = 3
	
	var shift = (dir_idx + 2) % 4
	input_mask = _rotate_bitmask(int(default_input_mask), shift)
	output_mask = _rotate_bitmask(int(default_output_mask), shift)

func _rotate_bitmask(mask: int, steps: int) -> int:
	var result: int = 0
	for i in range(4):
		if (mask & (1 << i)) != 0:
			var new_pos = (i + steps) % 4
			result |= (1 << new_pos)
	return result

func get_occupied_cells(rotation_index: int = -1) -> Array[Vector2i]:
	if layout_config.is_empty(): return[Vector2i.ZERO]
	var ri = rotation_index
	if ri == -1: ri = int(output_direction)
	var result: Array[Vector2i] =[]
	for point in layout_config:
		var p
		if point is Vector2i: p = point
		else: p = Vector2i.ZERO 
		if ri == 0:   p = Vector2i(-p.x, -p.y)
		elif ri == 1: p = Vector2i(p.y, -p.x)
		elif ri == 2: p = p
		elif ri == 3: p = Vector2i(-p.y, p.x)
		result.append(p)
	return result

func _on_died(_node): queue_free()

func receive_item(item: Resource, from_node: Node3D = null, _extra_data: Dictionary = {}) -> bool: 
	if not has_input: return false
	
	if from_node:
		var my_tile = LaneManager.world_to_tile(global_position)
		var sender_tile = LaneManager.world_to_tile(from_node.global_position)
		var diff = sender_tile - my_tile
		
		var incoming_dir = -1
		if diff == Vector2i(0, 1): incoming_dir = Direction.DOWN
		elif diff == Vector2i(-1, 0): incoming_dir = Direction.LEFT
		elif diff == Vector2i(0, -1): incoming_dir = Direction.UP
		elif diff == Vector2i(1, 0): incoming_dir = Direction.RIGHT
		
		if incoming_dir != -1 and not (input_mask & (1 << incoming_dir)):
			return false 

	if not item: return false
	if inventory_component:
		if not inventory_component.can_receive: return false
		var remainder = inventory_component.add_item(item, 1)
		return remainder == 0
	return false

func get_neighbor(dir: Direction) -> Node3D:
	if Engine.is_editor_hint(): return null
	var tile = LaneManager.world_to_tile(global_position)
	var offset = Vector2i.ZERO
	match dir:
		Direction.DOWN: offset = Vector2i(0, 1)
		Direction.UP:   offset = Vector2i(0, -1)
		Direction.LEFT: offset = Vector2i(-1, 0)
		Direction.RIGHT:offset = Vector2i(1, 0)
	
	var b = LaneManager.get_entity_at(tile + offset, "building")
	if b: return b
	return null

func try_output_from_inventory(inv: InventoryComponent) -> bool:
	if not has_output or not inv or not inv.has_item(): return false
	if not inv.can_output: return false
	
	var it = inv.get_first_item()
	if not it: return false

	for i in range(4):
		if (output_mask & (1 << i)):
			var n = get_neighbor(i as Direction)
			if is_instance_valid(n) and n.has_method("receive_item"):
				if n.get("has_input") == false: continue
				
				if n.receive_item(it, self):
					inv.remove_item(it, 1)
					return true
	return false

func requires_recipe_selection() -> bool: return false

func get_stat(stat_name: String, default_value: float = 0.0) -> float:
	var base_val = default_value
	
	# Extract base stat directly from building logic if available
	if stat_name in self:
		var val = get(stat_name)
		if typeof(val) in[TYPE_INT, TYPE_FLOAT]:
			base_val = float(val)
	elif stats.has(stat_name):
		base_val = float(stats[stat_name])
	
	var final_val = base_val
	
	# External Element Multipliers
	if elemental_component:
		var mult = elemental_component.get_stat_modifier(stat_name + "_mult")
		final_val *= (1.0 + mult)
		var flat = elemental_component.get_stat_modifier(stat_name + "_flat")
		final_val += flat
	
	# External Mod Chip Multipliers dynamically
	if mod_handler:
		var mult = mod_handler.get_stat_modifier(stat_name + "_mult")
		final_val *= (1.0 + mult)
		var flat = mod_handler.get_stat_modifier(stat_name + "_flat")
		final_val += flat

	return max(0.0, final_val)

## Updated to accept 3 arguments to match Enemy and HealthComponent signature
func take_damage(amount: float, element: Resource = null, source: Node = null) -> void:
	if health_component: 
		health_component.take_damage(amount, element, source)

func set_active_state(is_active_flag: bool) -> void:
	if is_staggered: is_active_flag = false
	self.is_active = is_active_flag
	set_process(is_active)
	set_physics_process(is_active)
	var shooter = get_node_or_null("ShooterComponent")
	if shooter: shooter.set_process(is_active)
