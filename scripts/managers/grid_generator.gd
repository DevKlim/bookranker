class_name GridGenerator extends Node

var lm: Node

func setup(lane_manager: Node) -> void:
	lm = lane_manager

func generate_chunk(start_d: int, end_d: int) -> void:
	for lane in range(lm.num_lanes):
		_generate_ores_for_lane_chunk(lane, start_d, end_d)
		_generate_clutter_for_lane_chunk(lane, start_d, end_d)
		_generate_loot_buildings_for_lane_chunk(lane, start_d, end_d)
		_generate_terrain_for_lane_chunk(lane, start_d, end_d)

func generate_guaranteed_ores(level_ores: Array) -> void:
	for o_conf in level_ores:
		var guaranteed = o_conf.get("guaranteed", 0)
		if guaranteed <= 0: continue
		var block_id = o_conf.get("block_id", -1)
		if block_id == -1: continue
		var placed = 0
		var attempts = 0
		var min_d = o_conf.get("min_depth", 0)
		var max_d = o_conf.get("max_depth", 30)
		
		while placed < guaranteed and attempts < 1000:
			attempts += 1
			var lane = randi() % lm.num_lanes
			var act_max = min(max_d, lm.LANE_LENGTH - 1)
			if act_max < min_d: continue
			var depth = randi_range(min_d, act_max)
			var coord = lm._calculate_grid_coord(lane, depth)
			var cell_pos = Vector3i(coord.x, 0, coord.y)
			if lm.grid_map.get_cell_item(cell_pos) == GridMap.INVALID_CELL_ITEM:
				_place_ore_block_by_config(coord, block_id, o_conf)
				placed += 1

func _generate_ores_for_lane_chunk(lane: int, start_d: int, end_d: int) -> void:
	var level_ores = GameManager.current_level_config.get("ores",[])
	if level_ores.is_empty(): return
	for depth in range(start_d, end_d):
		var tile_coord = lm._calculate_grid_coord(lane, depth)
		var cell_pos = Vector3i(tile_coord.x, 0, tile_coord.y)
		if lm.grid_map.get_cell_item(cell_pos) != GridMap.INVALID_CELL_ITEM: continue
		
		var valid_ores =[]
		for o_conf in level_ores:
			if depth >= o_conf.get("min_depth", 0) and depth <= o_conf.get("max_depth", 30):
				valid_ores.append(o_conf)
				
		if valid_ores.is_empty(): continue
		var picked_conf = null
		valid_ores.shuffle()
		for o_conf in valid_ores:
			if randf() < o_conf.get("rarity", 0.1):
				picked_conf = o_conf
				break
				
		if picked_conf:
			var block_id = picked_conf.get("block_id", -1)
			if block_id != -1:
				var gen_method = picked_conf.get("generation_method", "random")
				if gen_method == "cluster":
					_generate_ore_cluster(tile_coord, block_id, picked_conf)
				else:
					_place_ore_block_by_config(tile_coord, block_id, picked_conf)
					
func _generate_ore_cluster(center: Vector2i, block_id: int, conf: Dictionary) -> void:
	var cluster_size = randi_range(conf.get("cluster_min", 2), conf.get("cluster_max", 5))
	var placed = 0
	var queue = [center]
	var visited = {center: true}
	
	while queue.size() > 0 and placed < cluster_size:
		var curr = queue.pop_front()
		if not lm.is_valid_tile(curr): continue
		
		var cell_pos = Vector3i(curr.x, 0, curr.y)
		if lm.grid_map.get_cell_item(cell_pos) == GridMap.INVALID_CELL_ITEM:
			_place_ore_block_by_config(curr, block_id, conf)
			placed += 1
			
		var neighbors =[Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
		neighbors.shuffle()
		for n in neighbors:
			var next_t = curr + n
			if not visited.has(next_t):
				visited[next_t] = true
				if randf() < 0.7:
					queue.append(next_t)

func _place_ore_block_by_config(coord: Vector2i, block_id: int, conf: Dictionary) -> void:
	if not lm.grid_map: return
	lm.grid_map.set_cell_item(Vector3i(coord.x, 0, coord.y), block_id)
	var yield_min = conf.get("yield_min", 1)
	var yield_max = conf.get("yield_max", 1)
	lm.active_ore_deposits[coord] = randi_range(yield_min, yield_max)

func _generate_terrain_for_lane_chunk(lane: int, start_d: int, end_d: int) -> void:
	if not lm.grid_map: return
	var terrain_layers = GameManager.current_level_config.get("terrain_layers",[ { "depth": 5, "block": "Dirt" }, { "depth": lm.LANE_LENGTH, "block": "Stone" } ])
	for depth in range(start_d, end_d):
		var tile_coord = lm._calculate_grid_coord(lane, depth)
		var cell_pos = Vector3i(tile_coord.x, 0, tile_coord.y)
		if lm.grid_map.get_cell_item(cell_pos) != GridMap.INVALID_CELL_ITEM: continue
		var block_to_place = "Stone"
		for layer in terrain_layers:
			if depth <= layer.get("depth", lm.LANE_LENGTH):
				block_to_place = layer.get("block", "Stone")
				break
		if lm.block_name_to_id_map.has(block_to_place):
			lm.grid_map.set_cell_item(cell_pos, lm.block_name_to_id_map[block_to_place])

func _get_clutter_resource(id: String) -> Resource:
	for c in lm.clutter_types:
		if c.resource_path.ends_with(id + ".tres"):
			return c
	return null

func generate_guaranteed_clutter(level_clutter: Array, parent_node: Node) -> void:
	for c_conf in level_clutter:
		var guaranteed = c_conf.get("guaranteed", 0)
		if guaranteed <= 0: continue
		
		var c_res = _get_clutter_resource(c_conf["id"])
		if not c_res: continue
		
		var placed = 0
		var attempts = 0
		var min_d = c_conf.get("min_depth", 0)
		var max_d = c_conf.get("max_depth", 30)
		
		while placed < guaranteed and attempts < 1000:
			attempts += 1
			var lane = randi() % lm.num_lanes
			var act_max = min(max_d, lm.LANE_LENGTH - 1)
			if act_max < min_d: continue
			var depth = randi_range(min_d, act_max)
			var tile_coord = lm._calculate_grid_coord(lane, depth)
			
			if lm.get_entity_at(tile_coord, "building"): continue
			if lm.get_ore_at_world_pos(lm.tile_to_world(tile_coord)): continue
			
			_spawn_clutter_at(tile_coord, c_res, parent_node)
			placed += 1

func _generate_clutter_for_lane_chunk(lane: int, start_d: int, end_d: int) -> void:
	var level_clutter = GameManager.current_level_config.get("clutter",[])
	if level_clutter.is_empty(): return
	var root = get_tree().current_scene
	var parent_node = root.get_node_or_null("Buildings")
	if not parent_node: parent_node = root

	for depth in range(start_d, end_d):
		var tile_coord = lm._calculate_grid_coord(lane, depth)
		if lm.get_entity_at(tile_coord, "building"): continue
		if lm.get_ore_at_world_pos(lm.tile_to_world(tile_coord)): continue
		
		var valid_clutter =[]
		for c_conf in level_clutter:
			if depth >= c_conf.get("min_depth", 0) and depth <= c_conf.get("max_depth", 30):
				valid_clutter.append(c_conf)
		
		if valid_clutter.is_empty(): continue
		valid_clutter.shuffle()
		
		var picked_conf = null
		for c_conf in valid_clutter:
			if randf() < c_conf.get("rarity", 0.1):
				picked_conf = c_conf
				break
		
		if picked_conf:
			var c_res = _get_clutter_resource(picked_conf["id"])
			if c_res:
				_spawn_clutter_at(tile_coord, c_res, parent_node)

func _spawn_clutter_at(coord: Vector2i, clutter: Resource, parent: Node) -> void:
	if not "scene" in clutter or not clutter.scene: return
	var inst = clutter.scene.instantiate()
	if "clutter_resource" in inst:
		inst.clutter_resource = clutter
	parent.add_child(inst)
	inst.global_position = lm.tile_to_world(coord) + lm.building_offset + Vector3(0, 1.0, 0)

func generate_guaranteed_loot_buildings(level_loot: Array, parent_node: Node) -> void:
	for l_conf in level_loot:
		var guaranteed = l_conf.get("guaranteed", 0)
		if guaranteed <= 0: continue
		
		var placed = 0
		var attempts = 0
		var min_d = l_conf.get("min_depth", 0)
		var max_d = l_conf.get("max_depth", 30)
		
		while placed < guaranteed and attempts < 1000:
			attempts += 1
			var lane = randi() % lm.num_lanes
			var act_max = min(max_d, lm.LANE_LENGTH - 1)
			if act_max < min_d: continue
			var depth = randi_range(min_d, act_max)
			var tile_coord = lm._calculate_grid_coord(lane, depth)
			
			if lm.get_entity_at(tile_coord, "building"): continue
			if lm.get_ore_at_world_pos(lm.tile_to_world(tile_coord)): continue
			
			_spawn_loot_building_at(tile_coord, l_conf, parent_node)
			placed += 1

func _generate_loot_buildings_for_lane_chunk(lane: int, start_d: int, end_d: int) -> void:
	var level_loot = GameManager.current_level_config.get("loot_buildings",[])
	if level_loot.is_empty(): return
	var root = get_tree().current_scene
	var parent_node = root.get_node_or_null("Buildings")
	if not parent_node: parent_node = root

	for depth in range(start_d, end_d):
		var tile_coord = lm._calculate_grid_coord(lane, depth)
		if lm.get_entity_at(tile_coord, "building"): continue
		if lm.get_ore_at_world_pos(lm.tile_to_world(tile_coord)): continue
		
		var valid_loot =[]
		for l_conf in level_loot:
			if depth >= l_conf.get("min_depth", 0) and depth <= l_conf.get("max_depth", 30):
				valid_loot.append(l_conf)
		
		if valid_loot.is_empty(): continue
		valid_loot.shuffle()
		
		var picked_conf = null
		for l_conf in valid_loot:
			if randf() < l_conf.get("rarity", 0.1):
				picked_conf = l_conf
				break
		
		if picked_conf:
			_spawn_loot_building_at(tile_coord, picked_conf, parent_node)

func _spawn_loot_building_at(coord: Vector2i, conf: Dictionary, parent: Node) -> void:
	var building_id = conf.get("id", "")
	if building_id == "": return
	
	var path = "res://scenes/buildables/%s.tscn" % building_id
	if not ResourceLoader.exists(path): return
	
	var scene = load(path)
	if not scene: return
	var inst = scene.instantiate()
	parent.add_child(inst)
	inst.global_position = lm.tile_to_world(coord) + lm.building_offset
	
	if not inst.is_in_group("clutter"):
		inst.add_to_group("clutter")
		
	if "display_name" in inst:
		inst.display_name = "Loot"
	elif "ally_name" in inst:
		inst.set("ally_name", "Loot")
	
	var inv = inst.get_node_or_null("InventoryComponent")
	if not inv:
		inv = inst.get("inventory_component")
	
	if inv and conf.has("loot_pool"):
		var pool = GameManager.get_item_pool(conf["loot_pool"])
		if not pool.is_empty():
			for i in range(randi_range(1, 3)):
				var pick = GameManager.pick_from_weighted_pool(pool)
				if pick.is_empty(): continue
				var item_id = pick.get("item", "")
				var item_path = "res://resources/items/%s.tres" % item_id
				if ResourceLoader.exists(item_path):
					var item_res = load(item_path)
					var count = randi_range(pick.get("min", 1), pick.get("max", 1))
					inv.add_item(item_res, count)
		
		if not inv.inventory_changed.is_connected(_on_loot_inventory_changed):
			inv.inventory_changed.connect(_on_loot_inventory_changed.bind(inst, inv))

func _on_loot_inventory_changed(inst: Node, inv: Node) -> void:
	if not is_instance_valid(inst): return
	var has_items = false
	for slot in inv.slots:
		if slot != null and slot.count > 0:
			has_items = true
			break
	if not has_items:
		inst.queue_free()
