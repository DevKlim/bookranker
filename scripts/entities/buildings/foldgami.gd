class_name FoldgamiBuilding
extends BaseBuilding

var craft_timer: float = 0.0
var craft_duration: float = 2.0

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if not is_active: return
	
	craft_timer -= delta
	if craft_timer <= 0:
		craft_timer = craft_duration / max(0.1, get_stat("attack_speed_mult", 1.0))
		_try_fold()

func _try_fold() -> void:
	if not inventory_component: return
	
	var paper_res = load("res://resources/items/paper.tres")
	if not paper_res or not inventory_component.has_item_count(paper_res, 1):
		return
		
	var stamp_item: ItemResource = null
	var element_item: ItemResource = null
	var ink_item: ItemResource = null
	
	for slot in inventory_component.slots:
		if slot and slot.item:
			var id = slot.item.resource_path.get_file().get_basename()
			if id.begins_with("stamp_"): stamp_item = slot.item
			elif id.ends_with("chalk"): element_item = slot.item
			elif id == "ink": ink_item = slot.item
			
	var fold_name = "Crumpled Fold"
	var type = "crumpled"
	if stamp_item:
		type = stamp_item.resource_path.get_file().get_basename().replace("stamp_", "")
		fold_name = type.capitalize() + " Fold"
		
	var prefix = ""
	var elem = null
	var col = Color.WHITE
	
	if element_item:
		var e_id = element_item.resource_path.get_file().get_basename().replace("chalk", "")
		prefix = e_id.capitalize() + " "
		var e_res = load("res://resources/elements/" + e_id + ".tres")
		if e_res:
			elem = e_res
			col = e_res.color
	elif ink_item:
		prefix = "Ink "
		var slime_res = load("res://resources/elements/slime.tres")
		if slime_res:
			elem = slime_res
			col = Color.BLACK
			
	var dyn_path = "dynamic:fold_" + type + "_" + prefix.strip_edges()
	var dyn_item = Engine.get_meta(dyn_path) if Engine.has_meta(dyn_path) else null
	
	if not dyn_item:
		dyn_item = ItemResource.new()
		dyn_item.resource_path = dyn_path
		dyn_item.stack_size = 50
		dyn_item.item_name = prefix + fold_name
		dyn_item.color = col
		dyn_item.element = elem
		dyn_item.damage = 5.0
		dyn_item.modifiers = {}
		
		if type in ["plane", "shuriken", "crane"]:
			dyn_item.modifiers["air_borne"] = true
		elif type in ["swan", "lotus"]:
			dyn_item.modifiers["sea_borne"] = true
		else:
			dyn_item.modifiers["ground_borne"] = true
			
		if type == "crane":
			dyn_item.modifiers["piercing"] = true
			
		var atk = AttackResource.new()
		atk.id = "fold_shot"
		atk.spawn_projectile = true
		atk.projectile_speed = 100.0
		atk.element = elem
		atk.projectile_color = col
		dyn_item.attack_config = atk
		
		# Give it an icon from paper if available
		dyn_item.icon = paper_res.icon if paper_res else null
		
		Engine.set_meta(dyn_path, dyn_item)
		
	if inventory_component.has_space_for(dyn_item):
		inventory_component.remove_item(paper_res, 1)
		if stamp_item: inventory_component.remove_item(stamp_item, 1)
		if element_item: inventory_component.remove_item(element_item, 1)
		if ink_item: inventory_component.remove_item(ink_item, 1)
		inventory_component.add_item(dyn_item, 1)
		