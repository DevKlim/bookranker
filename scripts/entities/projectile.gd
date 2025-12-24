extends Area2D

# REMOVED class_name to prevent global scope conflicts.
# CHANGED types to 'Resource' or 'Node' to break cyclic dependency chains.

@export var default_scale: Vector2 = Vector2(1.0, 1.0)
@export var visual_offset: Vector2 = Vector2.ZERO

var _velocity: Vector2 = Vector2.ZERO
var _damage: float = 0.0
var _element: Resource = null # Was ElementResource
var lane_id: int = -1
var speed: float = 0.0
var _shred: float = 0.0

var current_path_index: int = -1
var path: Array = []

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	# Apply defaults if not initialized via code
	if sprite:
		sprite.scale = default_scale
		sprite.position = visual_offset

func _physics_process(delta: float) -> void:
	if path.is_empty():
		global_position += _velocity * delta
		return

	var target_index = current_path_index + 1
	if target_index < path.size():
		var target_tile = path[target_index]
		var target_pos = LaneManager.tile_map.map_to_local(target_tile)
		var direction = global_position.direction_to(target_pos)
		var dist = global_position.distance_to(target_pos)
		var move = speed * delta
		rotation = direction.angle()
		
		if dist <= move:
			global_position = target_pos
			current_path_index = target_index
		else:
			global_position += direction * move
	else:
		queue_free()

# using loose typing (Resource) here to prevent dependency cycle
func initialize(start_pos: Vector2, dir: Vector2, p_speed: float, dmg: float, p_lane: int, p_elem: Resource = null, tex: Texture2D = null, col: Color = Color.WHITE, use_path: bool = false, extra_params: Dictionary = {}) -> void:
	global_position = start_pos
	speed = p_speed
	_velocity = dir * speed
	rotation = dir.angle()
	_damage = dmg
	lane_id = p_lane
	_element = p_elem
	
	print("DEBUG: Projectile Spawned. Lane: %d, Pos: %s, Speed: %.1f" % [lane_id, start_pos, speed])
	
	# Explicitly set Z-Index to the Projectile layer to render above buildings
	z_index = LaneManager.Z_LAYERS["projectile"]
	
	if sprite:
		# Force centering to ensure projectile aligns exactly with spawn point
		sprite.position = visual_offset
		sprite.offset = Vector2.ZERO
		sprite.centered = true
		sprite.scale = default_scale
		
		if tex: sprite.texture = tex
		
		# Check if element is valid and has color property before accessing
		if _element and "color" in _element:
			sprite.self_modulate = _element.color
		else:
			sprite.self_modulate = col
		
		if extra_params.get("is_crit", false):
			sprite.modulate = Color(2.0, 0.5, 0.5, 1.0)
	
	if extra_params.has("scale"):
		# Multiply base scale by dynamic scale
		scale = Vector2.ONE * extra_params["scale"]
	
	if extra_params.has("shred"):
		_shred = extra_params["shred"]
	
	if use_path: _initialize_path_tracking()
	
	# Connect safely
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _initialize_path_tracking() -> void:
	if LaneManager.lane_paths.has(lane_id):
		path = LaneManager.lane_paths[lane_id]
		var tile = LaneManager.tile_map.local_to_map(global_position)
		current_path_index = path.find(tile)
		if current_path_index == -1:
			var min_dist = INF
			for i in range(path.size()):
				var wp = LaneManager.tile_map.map_to_local(path[i])
				var d = global_position.distance_squared_to(wp)
				if d < min_dist:
					min_dist = d
					current_path_index = i

func _on_body_entered(body: Node2D) -> void:
	# Duck typing to avoid Class Reference (EnemyUnit)
	if body.has_method("get_lane_id"):
		var e_lane = body.get_lane_id()
		
		# Allow cross-lane shooting if projectile was spawned with lane_id -1 (Turret Row Axis Mode)
		if self.lane_id == -1 or e_lane == self.lane_id:
			print("DEBUG: Projectile hit %s on Lane %d" % [body.name, e_lane])
			var hc = body.get_node_or_null("HealthComponent")
			if hc:
				hc.take_damage(_damage)
			
			if _element: 
				ElementManager.apply_element(body, _element)
			queue_free()
		else:
			# Debugging mismatches
			# print("DEBUG: Projectile ignored collision. ProjLane: %d, BodyLane: %d" % [self.lane_id, e_lane])
			pass

