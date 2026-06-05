@tool
class_name AllyImporter
extends BaseImporter

func import_allies(list: Array) -> void:
	var script = load(ALLY_SCRIPT)
	for entry in list:
		if not entry is Dictionary: continue
		var path = RESOURCE_BASE_PATH + "allies/" + str(entry.get("id", "unknown")) + ".tres"
		if not _should_process(str(entry.get("id")), path): continue
		
		var new_scene_path = SCENE_ALLIES_PATH + str(entry.get("id")) + ".tscn"
		if not only_update_resources:
			_generate_ally_scene(entry, new_scene_path)
		
		var res = _get_or_create_resource(path, script)
		res.ally_name = str(entry.get("name", "Ally"))
		
		if entry.has("texture") and ResourceLoader.exists(entry["texture"]):
			res.icon = load(entry["texture"])
		
		res.scene = load(new_scene_path)
		
		var logic = entry.get("logic", {})
		res.max_health = float(logic.get("max_health", logic.get("health", 100.0)))
		res.speed = float(logic.get("speed", 5.0))
		res.scale = float(logic.get("scale", logic.get("size", 1.0)))
		res.defense = float(logic.get("defense", 0.0))
		res.firewall = float(logic.get("firewall", logic.get("magical_defense", 0.0)))
		res.attack_damage = float(logic.get("attack_damage", 10.0))
		res.process_speed = float(logic.get("process_speed", logic.get("attack_speed", 1.0)))
		res.security = float(logic.get("security", 0.0))
		res.networking = float(logic.get("networking", 0.0))
		res.space = float(logic.get("space", logic.get("weight", 10.0)))
		res.luck_stat = float(logic.get("luck_stat", 0.0))
		res.compute = float(logic.get("compute", 1.0))
		res.ping = float(logic.get("ping", 1.0))
		res.malware = float(logic.get("malware", 0.0))
		
		res.inventory_slots = int(logic.get("inventory_slots", 8))
		res.has_tool_slot = bool(logic.get("tool_slot", true))
		res.has_weapon_slot = bool(logic.get("weapon_slot", true))
		res.has_armor_slot = bool(logic.get("armor_slot", true))
		res.has_artifact_slot = bool(logic.get("artifact_slot", true))
		
		var respawns = entry.get("respawns", {})
		res.respawns_count = int(respawns.get("count", 0))
		res.respawns_unlimited = bool(respawns.get("unlimited", false))
		res.respawns_cooldown = float(respawns.get("cooldown", 5.0))
		
		_apply_formulas_and_weights(res, entry)
		
		ResourceSaver.save(res, path)

func _generate_ally_scene(data: Dictionary, save_path: String) -> void:
	var inst = CharacterBody3D.new()
	inst.name = str(data.get("name", "GeneratedAlly"))
	inst.set_script(load(ENTITY_ALLY_SCRIPT))
	inst.add_to_group("allies")
	if str(data.get("id")) == "player":
		inst.add_to_group("player")
	inst.collision_layer = 4 # Same layer as Player
	
	# Visuals
	if data.has("texture") and ResourceLoader.exists(data["texture"]):
		var sprite = Sprite3D.new()
		sprite.name = "Visual"
		sprite.texture = load(data["texture"])
		sprite.pixel_size = 0.03
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.position = Vector3(0, 1.0, 0)
		inst.add_child(sprite)
	else:
		var mi = MeshInstance3D.new()
		mi.name = "Visual"
		mi.mesh = CapsuleMesh.new()
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 0.6, 1.0) # Ally Blue
		mi.mesh.surface_set_material(0, mat)
		mi.position = Vector3(0, 1.0, 0)
		inst.add_child(mi)

	var col = CollisionShape3D.new()
	col.name = "CollisionShape3D"
	col.shape = CapsuleShape3D.new()
	col.position = Vector3(0, 1.0, 0)
	inst.add_child(col)
	
	_add_component(inst, COMP_HEALTH, "HealthComponent")
	var move = _add_component(inst, COMP_MOVE, "MoveComponent")
	move.move_speed = 5.0
	move.stop_distance = 0.1
	
	var inv = _add_component(inst, COMP_INVENTORY, "InventoryComponent")
	var logic = data.get("logic", {})
	inv.max_slots = int(logic.get("inventory_slots", 8))
	inv.can_receive = true
	inv.can_output = true
	
	_add_component(inst, COMP_ELEMENTAL, "ElementalComponent")
	
	_apply_logic_params(inst, data)
	_save_scene(inst, save_path)
