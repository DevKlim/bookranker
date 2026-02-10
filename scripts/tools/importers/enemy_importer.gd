@tool
class_name EnemyImporter
extends BaseImporter

func import_enemies(list: Array) -> void:
	var script = load(ENEMY_SCRIPT)
	for entry in list:
		if not entry is Dictionary: continue
		var path = RESOURCE_BASE_PATH + "enemies/" + str(entry.get("id", "unknown")) + ".tres"
		if not _should_process(str(entry.get("id")), path): continue
		
		var res = _get_or_create_resource(path, script)
		if "scene" in res: res.scene = null
		
		var new_scene_path = ""
		if entry.has("scene_path"):
			var raw_path = entry["scene_path"]
			if raw_path.begins_with("res://"):
				new_scene_path = raw_path
			else:
				new_scene_path = SCENE_ENEMIES_PATH + str(entry.get("id")) + ".tscn"
			_generate_enemy_scene(entry, new_scene_path)
		
		res.enemy_name = str(entry.get("name", "Enemy"))
		
		if new_scene_path != "":
			res.scene = ResourceLoader.load(new_scene_path, "", ResourceLoader.CACHE_MODE_REPLACE)
		elif entry.has("template") and ResourceLoader.exists(entry["template"]):
			res.scene = load(entry["template"])
			
		if entry.has("logic") and entry["logic"] is Dictionary:
			res.health = entry["logic"].get("health", 50.0)
			res.speed = entry["logic"].get("speed", 50.0)
			res.defense = entry["logic"].get("defense", 0.0)
			res.magical_defense = entry["logic"].get("magical_defense", 0.0)
			res.elemental_cd = entry["logic"].get("elemental_cd", 0.0)
			res.elemental_resistances = entry["logic"].get("resistances", {})
		if entry.has("params") and entry["params"] is Dictionary:
			res.attack_damage = entry["params"].get("attack_damage", 10.0)
			res.attack_speed = entry["params"].get("attack_speed", 1.0)
			res.attack_range_depth = int(entry["params"].get("attack_range", 1))
			res.attack_range_width = int(entry["params"].get("attack_width", 0))

		# Field Configuration
		if entry.has("field_config") and entry["field_config"] is Dictionary:
			var fc = entry["field_config"]
			res.is_field_enemy = true
			res.field_spawn_min_depth = fc.get("min_depth", 15)
			res.field_spawn_max_depth = fc.get("max_depth", 60)
			res.field_spawn_interval = fc.get("spawn_interval", 10.0)
			res.field_spawn_chance = fc.get("spawn_chance", 0.5)
			res.max_field_spawns = fc.get("max_spawns", 5)
			res.aggro_range = fc.get("aggro_range", 10.0)
			res.wander_radius = fc.get("wander_radius", 5.0)
		else:
			res.is_field_enemy = false

		if entry.has("drops") and entry["drops"] is Array:
			res.drops = entry["drops"]
		ResourceSaver.save(res, path)

func _generate_enemy_scene(data: Dictionary, save_path: String) -> void:
	var inst = CharacterBody3D.new()
	inst.name = str(data.get("name", "GeneratedEnemy"))
	
	# Support Template
	if data.has("template") and ResourceLoader.exists(data["template"]):
		var temp_res = load(data["template"])
		var temp_inst = temp_res.instantiate()
		inst.set_script(temp_inst.get_script())
		# Clone children from template
		for c in temp_inst.get_children():
			var dup = c.duplicate()
			inst.add_child(dup)
		temp_inst.free()
	else:
		inst.set_script(load(ENTITY_ENEMY_SCRIPT))

	var asset_path = data.get("scene_path", "")
	# Only add ModelContainer from asset if it's an external path (e.g. .glb) 
	# and we didn't already get visuals from a template.
	var has_visuals = inst.has_node("ModelContainer") or inst.has_node("ModelFallback")
	
	if not has_visuals:
		if asset_path != "" and asset_path != save_path and ResourceLoader.exists(asset_path):
			var asset_scene = load(asset_path)
			var asset_inst = asset_scene.instantiate()
			asset_inst.name = "ModelContainer"
			inst.add_child(asset_inst)
		else:
			var mi = MeshInstance3D.new()
			mi.name = "ModelFallback"
			mi.mesh = CapsuleMesh.new()
			inst.add_child(mi)
			
	if not inst.has_node("CollisionShape3D"):
		var col = CollisionShape3D.new()
		col.name = "CollisionShape3D"
		col.shape = CapsuleShape3D.new()
		col.position = Vector3(0, 1.0, 0)
		inst.add_child(col)
		
	_add_component(inst, COMP_HEALTH, "HealthComponent")
	var att = _add_component(inst, COMP_ATTACKER, "AttackerComponent")
	var t = Timer.new()
	t.name = "AttackTimer"
	att.add_child(t)
	
	# Explicitly add MoveComponent
	_add_component(inst, COMP_MOVE, "MoveComponent")
	
	_add_component(inst, COMP_ELEMENTAL, "ElementalComponent")
	
	_apply_logic_params(inst, data)
	_save_scene(inst, save_path)
