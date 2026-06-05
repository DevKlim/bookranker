class_name DeskBuilding
extends BaseBuilding

var _fire_cooldown: float = 0.0

func _ready() -> void:
	display_name = "Desk"
	super._ready()
	if inventory_component:
		inventory_component.set_capacity(1)
		inventory_component.can_receive = true
		inventory_component.can_output = true
		
		inventory_component.custom_filter = func(item):
			if not item: return false
			var id = item.resource_path.get_file().get_basename()
			return id.begins_with("dynamic_fold_")

func get_slot_tooltip(idx: int) -> String:
	if idx == 0: return "Folded Paper Craft"
	return ""

func get_slot_label(idx: int) -> String:
	if idx == 0: return "FOLD"
	return ""

# Prevent the Desk from mindlessly tossing the fold on the floor
func try_output_from_inventory(inv: InventoryComponent) -> bool:
	return false

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if Engine.is_editor_hint(): return
	
	if _fire_cooldown > 0.0:
		_fire_cooldown -= delta
	
	if not is_active: return
	
	if _fire_cooldown <= 0.0 and inventory_component and inventory_component.has_item():
		if elemental_component and elemental_component.has_element("aero"):
			var fold_item = inventory_component.get_first_item()
			if fold_item:
				var type = fold_item.modifiers.get("fold_type", "crumpled")
				var output_count = 1
				if type == "shuriken": output_count = 3
				
				inventory_component.remove_item(fold_item, 1)
				
				if type == "shuriken":
					_fire_projectile(fold_item, -15.0)
					_fire_projectile(fold_item, 0.0)
					_fire_projectile(fold_item, 15.0)
				else:
					_fire_projectile(fold_item, 0.0)
					
				var spd_mult = get_stat("process_speed", 1.0)
				_fire_cooldown = 1.0 / max(0.1, spd_mult)

func _fire_projectile(dyn_item: ItemResource, angle_deg: float = 0.0) -> void:
	var spawn_pos = global_position + Vector3(0, 0.5, 0)
	var type = dyn_item.modifiers.get("fold_type", "crumpled")
	
	var dir = Vector3.ZERO
	if output_direction == Direction.DOWN: dir = Vector3(0, 0, 1)
	elif output_direction == Direction.LEFT: dir = Vector3(-1, 0, 0)
	elif output_direction == Direction.UP: dir = Vector3(0, 0, -1)
	elif output_direction == Direction.RIGHT: dir = Vector3(1, 0, 0)
	
	if angle_deg != 0.0:
		dir = dir.rotated(Vector3.UP, deg_to_rad(angle_deg))
	
	var speed = 150.0 
	
	if elemental_component and elemental_component.has_element("aero"):
		speed *= 2.0
		
	var p_scene = null
	var specific_scene_path = "res://scenes/attacks/fold_%s.tscn" % type
	if ResourceLoader.exists(specific_scene_path):
		p_scene = load(specific_scene_path)
	if not p_scene:
		p_scene = load("res://scenes/entities/projectile.tscn")
	if not p_scene: return
		
	var proj = p_scene.instantiate()
	get_tree().root.add_child(proj)
	
	var lane_id = LaneManager.world_to_tile(spawn_pos).y
	var params = dyn_item.modifiers.duplicate()
	params["source"] = self
	params["grace_period"] = 0.5
	
	var lifetime = float(params.get("range", 10.0)) / (speed * 0.02)
	params["lifetime"] = lifetime
	
	var bonus_dmg = get_stat("attack_damage", 0.0)
	
	proj.initialize(spawn_pos, dir, speed, dyn_item.damage + bonus_dmg, lane_id, dyn_item.element, dyn_item.icon, dyn_item.color, false, params)
