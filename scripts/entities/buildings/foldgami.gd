class_name FoldgamiBuilding
extends BaseBuilding

var craft_timer: float = 0.0
var _print_delay: float = 0.0

func _ready() -> void:
	# Defensively guarantee the inventory component exists before the parent initializes
	if not has_node("InventoryComponent") and not has_node("InputInventory"):
		var inv = InventoryComponent.new()
		inv.name = "InventoryComponent"
		add_child(inv)
		
	super._ready()
	
	if inventory_component:
		inventory_component.set_capacity(3)
		inventory_component.can_receive = true
		inventory_component.can_output = true
		# Enforce strict input logic so belts and dragging route appropriately
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

# Helper to robustly get the ID whether it's an imported file or dynamically created
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

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	
	_print_delay += delta
	
	if not is_active:
		if _print_delay > 2.0:
			# print("[Foldgami] Waiting for power...")
			_print_delay = 0.0
		return
	
	var mat_slot = _get_material_slot()
	if not mat_slot:
		if craft_timer > 0:
			print("[Foldgami] Missing materials. Crafting reset.")
		craft_timer = 0.0
		return
		
	var stamp_item = _get_stamp()
	var craft_duration = 2.0
	
	# Crane folds take 3 seconds
	if stamp_item and _get_item_id(stamp_item) == "stamp_crane":
		craft_duration = 3.0
		
	var spd_mult = get_stat("attack_speed_mult", 0.0)
	craft_timer += delta * max(0.1, 1.0 + spd_mult)
	
	if _print_delay > 1.0:
		print("[Foldgami] Crafting progress: ", snapped(craft_timer, 0.1), " / ", craft_duration)
		_print_delay = 0.0
	
	if craft_timer >= craft_duration:
		craft_timer = 0.0
		var m_item = mat_slot.get("item") if typeof(mat_slot) == TYPE_DICTIONARY else mat_slot.item
		print("[Foldgami] Folding complete! Attempting to fire...")
		_try_fold(m_item, stamp_item, _get_element())

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

func _try_fold(mat_item: ItemResource, stamp_item: ItemResource, element_item: ItemResource) -> void:
	var mat_id = _get_item_id(mat_item)
	
	# Cardboard deals 4 base damage, Paper deals 2
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
		
		# Define individual stamp attributes
		if type == "crane": 
			extra_dmg = 3.0
			range_blocks = 30
			is_piercing = true
		elif type == "plane":
			extra_dmg = 2.0
			range_blocks = 30
		elif type == "swan":
			extra_dmg = 2.0
			range_blocks = 100 # Coasting length
			is_piercing = true
			is_tick_damage = true
		elif type == "lotus":
			extra_dmg = 2.0
			range_blocks = 100
			is_aoe = true
			is_tick_damage = true
		elif type == "shuriken":
			extra_dmg = 1.0
			range_blocks = 20
			
	var total_dmg = base_dmg + extra_dmg
	
	if type == "crumpled":
		total_dmg = 1.0 if mat_id == "paper" else 2.0
	
	var elem = null
	var col = Color.WHITE
	var prefix = ""
	
	if element_item:
		var e_id = _get_item_id(element_item).replace("chalk", "")
		if e_id == "ink":
			elem = ElementManager.get_element("slime")
			prefix = "Ink "
			col = Color(0.1, 0.1, 0.1, 1.0)
		else:
			prefix = e_id.capitalize() + " "
			elem = ElementManager.get_element(e_id)
			if elem: col = elem.color

	# Cache dynamic item resource definition
	var clean_prefix = prefix.strip_edges().replace(" ", "_")
	var dyn_path = "dynamic_fold_%s_%s_%s" %[mat_id, type, clean_prefix]
	var dyn_item = Engine.get_meta(dyn_path) if Engine.has_meta(dyn_path) else null
	
	if not dyn_item:
		dyn_item = ItemResource.new()
		dyn_item.resource_path = dyn_path
		dyn_item.stack_size = 50
		dyn_item.item_name = prefix + fold_name
		dyn_item.color = col
		dyn_item.element = elem
		dyn_item.damage = total_dmg
		dyn_item.icon = mat_item.icon
		
		var mods = {}
		if type in["plane", "shuriken", "crane"]:
			mods["air_borne"] = true
		elif type in["swan", "lotus"]:
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

	# 1. Output into Forward Neighbor Inventory (Belt / Cubby)
	var output_neighbor = get_neighbor(output_direction)
	if is_instance_valid(output_neighbor) and output_neighbor.has_method("receive_item") and output_neighbor.get("has_input") != false:
		var is_sea_borne = dyn_item.modifiers.get("sea_borne", false)
		
		var is_neighbor_stream = false
		if "display_name" in output_neighbor and output_neighbor.display_name in["Slipstream", "Tarstream"]:
			is_neighbor_stream = true
		
		# Prevent turning projectiles into static inventory items strictly on streams
		if not (is_sea_borne and is_neighbor_stream):
			if output_neighbor.receive_item(dyn_item, self):
				_consume_inputs(mat_item, stamp_item, element_item)
				print("[Foldgami] Handed fold successfully to neighbor.")
				return

	# 2. Fire as active Projectile into the wild
	_consume_inputs(mat_item, stamp_item, element_item)
	_fire_projectile(dyn_item, type)

func _consume_inputs(m, s, e):
	inventory_component.remove_item(m, 1)
	# STAMPS ARE NEVER CONSUMED. Reusable modifiers.
	if e: inventory_component.remove_item(e, 1)

func _fire_projectile(dyn_item: ItemResource, type: String):
	var spawn_pos = global_position + Vector3(0, 0.5, 0)
	
	var dir = Vector3.ZERO
	if output_direction == Direction.DOWN: dir = Vector3(0, 0, 1)
	elif output_direction == Direction.LEFT: dir = Vector3(-1, 0, 0)
	elif output_direction == Direction.UP: dir = Vector3(0, 0, -1)
	elif output_direction == Direction.RIGHT: dir = Vector3(1, 0, 0)
	
	var speed = 150.0 
	
	# Aero Synergy: The Box Fan adds Aero to buildings in front of it!
	if elemental_component and elemental_component.has_element("aero"):
		print("[Foldgami] Aero synergy active! Wind propels projectile faster.")
		speed *= 2.0
		
	# Force explicit load of the 3D scene to bypass old cache bugs
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
	params["grace_period"] = 0.5 # Give Seaborne items half a second to locate the stream upon firing
	
	# Convert grid blocks into seconds of lifetime
	var lifetime = float(params.get("range", 10.0)) / (speed * 0.02)
	params["lifetime"] = lifetime
	
	proj.initialize(spawn_pos, dir, speed, dyn_item.damage, lane_id, dyn_item.element, dyn_item.icon, dyn_item.color, false, params)
	print("[Foldgami] Fired ", dyn_item.item_name, " projectile at ", spawn_pos)
