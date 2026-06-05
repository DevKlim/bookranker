class_name FoldgamiBuilding
extends BaseBuilding

var craft_timer: float = 0.0
var _print_delay: float = 0.0

func _ready() -> void:
	if not has_node("InventoryComponent") and not has_node("InputInventory"):
		var inv = InventoryComponent.new()
		inv.name = "InventoryComponent"
		add_child(inv)
		
	super._ready()
	
	if inventory_component:
		inventory_component.set_capacity(3)
		inventory_component.can_receive = true
		inventory_component.can_output = true
		inventory_component.slot_filter = _foldgami_slot_filter

func get_slot_tooltip(idx: int) -> String:
	match idx:
		0: return "Paper / Cardboard"
		1: return "Stamp (Optional)"
		2: return "Element / Ink (Optional)"
	return ""

func get_slot_label(idx: int) -> String:
	match idx:
		0: return "MAT"
		1: return "STP"
		2: return "ELM"
	return ""

func _get_item_id(item: Resource) -> String:
	if not item: return ""
	var id = item.resource_path.get_file().get_basename()
	if id == "": id = item.item_name.to_lower().replace(" ", "_")
	return id

func _foldgami_slot_filter(item: Resource, index: int) -> bool:
	var id = _get_item_id(item)
	if index == 0:
		return id == "paper" or id == "cardboard"
	elif index == 1:
		return id.begins_with("stamp_")
	elif index == 2:
		return id.ends_with("chalk") or id == "ink"
	return false

# Prevent raw ingredients from auto-outputting
func try_output_from_inventory(inv: InventoryComponent) -> bool:
	return false 

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	
	_print_delay += delta
	
	if not is_active:
		if _print_delay > 2.0:
			_print_delay = 0.0
		return
	
	var mat_slot = _get_material_slot()
	var stamp_item = _get_stamp()
	
	var required_mats = 1
	var craft_duration = 2.0
	var type = "crumpled"
	
	if stamp_item:
		var stamp_id = _get_item_id(stamp_item)
		type = stamp_id.replace("stamp_", "")
		if type == "shuriken":
			required_mats = 2
		elif type in ["swan", "crane"]:
			required_mats = 3
			if type == "crane":
				craft_duration = 3.0
				
	var current_mat_count = 0
	if mat_slot:
		current_mat_count = mat_slot.get("count") if typeof(mat_slot) == TYPE_DICTIONARY else mat_slot.count
		
	if current_mat_count < required_mats:
		if craft_timer > 0:
			print("[Foldgami] Missing materials. Crafting reset.")
		craft_timer = 0.0
		return
		
	var spd_mult = get_stat("process_speed", 1.0)
	craft_timer += delta * max(0.1, spd_mult)
	
	if _print_delay > 1.0:
		print("[Foldgami] Crafting progress: ", snapped(craft_timer, 0.1), " / ", craft_duration)
		_print_delay = 0.0
	
	if craft_timer >= craft_duration:
		craft_timer = 0.0
		var m_item = mat_slot.get("item") if typeof(mat_slot) == TYPE_DICTIONARY else mat_slot.item
		print("[Foldgami] Folding complete! Attempting to fire...")
		_try_fold(m_item, stamp_item, _get_element(), required_mats)

func _get_material_slot():
	if not inventory_component or inventory_component.slots.size() <= 0: return null
	var slot = inventory_component.slots[0]
	if slot != null:
		var item = slot.get("item") if typeof(slot) == TYPE_DICTIONARY else slot.item
		var id = _get_item_id(item)
		if id == "paper" or id == "cardboard":
			return slot
	return null

func _get_stamp():
	if not inventory_component or inventory_component.slots.size() <= 1: return null
	var slot = inventory_component.slots[1]
	if slot != null:
		var item = slot.get("item") if typeof(slot) == TYPE_DICTIONARY else slot.item
		var id = _get_item_id(item)
		if id.begins_with("stamp_"):
			return item
	return null

func _get_element():
	if not inventory_component or inventory_component.slots.size() <= 2: return null
	var slot = inventory_component.slots[2]
	if slot != null:
		var item = slot.get("item") if typeof(slot) == TYPE_DICTIONARY else slot.item
		var id = _get_item_id(item)
		if id.ends_with("chalk") or id == "ink":
			return item
	return null

func _try_fold(mat_item: ItemResource, stamp_item: ItemResource, element_item: ItemResource, required_mats: int) -> void:
	var mat_id = _get_item_id(mat_item)
	
	# Spawn fold visual effect through the GameManager's vfx_manager instance
	if get_tree().root.has_node("GameManager"):
		var gm = get_tree().root.get_node("GameManager")
		if gm.get("vfx_manager"):
			gm.vfx_manager.play_vfx("fold_craft", global_position)
	
	var base_dmg = 4.0 if mat_id == "cardboard" else 2.0
	
	var type = "crumpled"
	var fold_name = "Crumpled Fold"
	var extra_dmg = 0.0
	var range_blocks = 10
	
	var is_piercing = false
	var is_tick_damage = false
	var is_aoe = false
	
	if stamp_item:
		var stamp_id = _get_item_id(stamp_item)
		type = stamp_id.replace("stamp_", "")
		fold_name = type.capitalize() + " Fold"
		
		if type == "crane": 
			extra_dmg = 3.0
			range_blocks = 30
			is_piercing = true
		elif type == "plane":
			extra_dmg = 2.0
			range_blocks = 30
		elif type == "swan":
			extra_dmg = 2.0
			range_blocks = 100
			is_piercing = true
			is_tick_damage = true
		elif type == "lotus":
			extra_dmg = 1.0
			range_blocks = 100
			is_aoe = true
			is_tick_damage = true
		elif type == "shuriken":
			extra_dmg = 1.0
			range_blocks = 10
			
	var stat_bonus = 0.0
	if type == "crumpled":
		stat_bonus = get_stat("space", 10.0) * 0.2
	elif type == "shuriken":
		stat_bonus = get_stat("speed", 5.0) * 0.5
	elif type == "plane":
		stat_bonus = get_stat("networking", 0.0) * 1.0
	elif type == "crane":
		stat_bonus = get_stat("attack_damage", 0.0) * 1.0
	elif type == "swan":
		stat_bonus = get_stat("luck_stat", 0.0) * 0.5
	elif type == "lotus":
		stat_bonus = get_stat("compute", 1.0) * 1.0
			
	var total_dmg = (base_dmg + extra_dmg + stat_bonus) * get_stat("attack_damage_mult", 1.0)
	
	if type == "crumpled":
		total_dmg = ((1.0 if mat_id == "paper" else 2.0) + stat_bonus) * get_stat("attack_damage_mult", 1.0)
	
	var elem = null
	var col = Color.WHITE
	var prefix = ""
	
	if element_item:
		var e_id = _get_item_id(element_item).replace("chalk", "")
		if e_id == "ink":
			elem = ElementManager.get_element("dark")
			prefix = "Ink "
			if elem: col = elem.color
		else:
			prefix = e_id.capitalize() + " "
			elem = ElementManager.get_element(e_id)
			if elem: col = elem.color

	var clean_prefix = prefix.strip_edges().replace(" ", "_")
	var dyn_path = "dynamic_fold_%s_%s_%s_%d" %[mat_id, type, clean_prefix, int(total_dmg)]
	var dyn_item = Engine.get_meta(dyn_path) if Engine.has_meta(dyn_path) else null
	
	if not dyn_item:
		dyn_item = ItemResource.new()
		dyn_item.resource_path = dyn_path
		dyn_item.stack_size = 50
		var mat_display = "Paper"
		if mat_id == "cardboard": mat_display = "Cardboard"
		dyn_item.item_name = prefix + mat_display + " " + fold_name
		dyn_item.color = col
		dyn_item.element = elem
		dyn_item.damage = total_dmg
		
		var base_item_path = "res://resources/items/%sfold.tres" % type
		if ResourceLoader.exists(base_item_path):
			var base_item = load(base_item_path)
			if base_item and base_item.icon:
				dyn_item.icon = base_item.icon
			else:
				dyn_item.icon = mat_item.icon
		else:
			dyn_item.icon = mat_item.icon
		
		var mods = {}
		if type in ["plane", "shuriken", "crane"]:
			mods["air_borne"] = true
		elif type in ["swan", "lotus"]:
			mods["sea_borne"] = true
		else:
			mods["ground_borne"] = true
			
		if is_piercing: mods["piercing"] = true
		if is_tick_damage: mods["tick_damage"] = true
		if is_aoe: mods["aoe_explosion"] = true
			
		mods["range"] = float(range_blocks)
		mods["fold_type"] = type

		var p_scene_path = "res://scenes/attacks/fold_%s.tscn" % type
		if ResourceLoader.exists(p_scene_path):
			dyn_item.projectile_scene = load(p_scene_path)

		dyn_item.modifiers = mods
		Engine.set_meta(dyn_path, dyn_item)

	var output_count = 1
	if type == "shuriken": output_count = 3

	var output_neighbor = get_neighbor(output_direction)
	if is_instance_valid(output_neighbor) and output_neighbor.has_method("receive_item") and output_neighbor.get("has_input") != false:
		if not (output_neighbor is FoldgamiBuilding):
			var is_sea_borne = dyn_item.modifiers.get("sea_borne", false)
			var is_neighbor_stream = false
			if "display_name" in output_neighbor and output_neighbor.display_name in ["Slipstream", "Tarstream"]:
				is_neighbor_stream = true
			
			if not (is_sea_borne and is_neighbor_stream):
				var successfully_passed = 0
				for i in range(output_count):
					if output_neighbor.receive_item(dyn_item, self):
						successfully_passed += 1
						
				if successfully_passed > 0:
					_consume_inputs(mat_item, stamp_item, element_item, required_mats)
					print("[Foldgami] Handed fold successfully to neighbor.")
					return

	_consume_inputs(mat_item, stamp_item, element_item, required_mats)
	
	if type == "shuriken":
		_fire_projectile(dyn_item, type, -15.0)
		_fire_projectile(dyn_item, type, 0.0)
		_fire_projectile(dyn_item, type, 15.0)
	else:
		_fire_projectile(dyn_item, type, 0.0)

func _consume_inputs(m, s, e, req):
	inventory_component.remove_item(m, req)
	if e: inventory_component.remove_item(e, 1)

func _fire_projectile(dyn_item: ItemResource, type: String, angle_deg: float = 0.0):
	var spawn_pos = global_position + Vector3(0, 0.5, 0)
	
	var dir = Vector3.ZERO
	if output_direction == Direction.DOWN: dir = Vector3(0, 0, 1)
	elif output_direction == Direction.LEFT: dir = Vector3(-1, 0, 0)
	elif output_direction == Direction.UP: dir = Vector3(0, 0, -1)
	elif output_direction == Direction.RIGHT: dir = Vector3(1, 0, 0)
	
	if angle_deg != 0.0:
		dir = dir.rotated(Vector3.UP, deg_to_rad(angle_deg))
	
	var speed = 150.0 
	
	if elemental_component and elemental_component.has_element("aero"):
		print("[Foldgami] Aero synergy active! Wind propels projectile faster.")
		speed *= 2.0
		
	var p_scene = null
	var specific_scene_path = "res://scenes/attacks/fold_%s.tscn" % type
	if ResourceLoader.exists(specific_scene_path):
		p_scene = load(specific_scene_path)
		
	if not p_scene:
		p_scene = load("res://scenes/entities/projectile.tscn")
		
	if not p_scene: 
		printerr("[Foldgami] Critical: No projectile scene found!")
		return
		
	var proj = p_scene.instantiate()
	get_tree().root.add_child(proj)
	
	var lane_id = LaneManager.world_to_tile(spawn_pos).y
	var params = dyn_item.modifiers.duplicate()
	params["source"] = self
	params["grace_period"] = 0.5 
	
	var lifetime = float(params.get("range", 10.0)) / (speed * 0.02)
	params["lifetime"] = lifetime
	
	proj.initialize(spawn_pos, dir, speed, dyn_item.damage, lane_id, dyn_item.element, dyn_item.icon, dyn_item.color, false, params)
	print("[Foldgami] Fired ", dyn_item.item_name, " projectile at ", spawn_pos)
