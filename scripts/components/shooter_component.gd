class_name ShooterComponent
extends Node

## Handles shooting with advanced stat calculations.

@export var projectile_scene: PackedScene
@export var projectile_speed: float = 600.0
@export var base_damage: float = 10.0
@export var base_element: ElementResource
@export var fire_rate: float = 1.0 
@export var fire_point_path: NodePath

@onready var fire_point: Marker2D = get_node_or_null(fire_point_path)
@onready var fire_rate_timer: Timer = $FireRateTimer

var _can_shoot: bool = true
var _parent_building: Node

func _ready() -> void:
	_parent_building = get_parent()
	
	# Retry loading projectile_scene if it's null (sometimes happens with cyclic load issues)
	if not projectile_scene:
		# Hard fallback to try and find the resource manually
		var fallback_path = "res://scenes/entities/projectile.tscn"
		if ResourceLoader.exists(fallback_path):
			projectile_scene = load(fallback_path)
			print("[%s] ShooterComponent: Recovered projectile_scene from fallback path." % _parent_building.name)

	if not projectile_scene:
		printerr("ERROR: [%s] ShooterComponent: projectile_scene is NULL. Shooting disabled." % _parent_building.name)
		_can_shoot = false
		return
	else:
		if not fire_point:
			printerr("ERROR: [%s] ShooterComponent: Invalid fire_point_path." % _parent_building.name)
			_can_shoot = false
			return
	
	fire_rate_timer.one_shot = true
	fire_rate_timer.timeout.connect(_on_fire_rate_timer_timeout)
	_update_timer()

func _update_timer() -> void:
	var speed_mult = 1.0
	if _parent_building and "stats" in _parent_building:
		speed_mult = _parent_building.stats.get("speed_mult", 1.0)
	
	if speed_mult <= 0: speed_mult = 0.1
	var rate = fire_rate * speed_mult
	if rate > 0:
		fire_rate_timer.wait_time = 1.0 / rate
	else:
		fire_rate_timer.wait_time = 999.0

func can_shoot() -> bool:
	return _can_shoot

func shoot_in_direction(direction: Vector2, target_lane_id: int, ammo_item: ItemResource = null, override_start_pos: Vector2 = Vector2.INF) -> void:
	if not _can_shoot or not projectile_scene: return
	
	var stats = {}
	if _parent_building and "stats" in _parent_building:
		stats = _parent_building.stats
	
	var final_damage = base_damage
	var element = base_element
	var texture = null
	var color = Color.WHITE
	
	if ammo_item:
		final_damage += ammo_item.damage
		element = ammo_item.element
		texture = ammo_item.icon
		color = ammo_item.color
	
	final_damage *= stats.get("damage_mult", 1.0)
	
	var is_magic = false
	if element and "element_name" in element:
		if element.element_name in ["Fire", "Shock", "Water", "Ice", "Chem"]:
			is_magic = true
			
	if is_magic: final_damage += stats.get("magic_boost", 0.0)
	else: final_damage += stats.get("phys_boost", 0.0)
		
	var is_crit = randf() < stats.get("crit_chance", 0.0)
	if is_crit:
		final_damage *= stats.get("crit_damage", 1.5)
		
	var proj = projectile_scene.instantiate()
	get_tree().current_scene.get_node("Projectiles").add_child(proj)
	
	var start = fire_point.global_position
	if override_start_pos != Vector2.INF: start = override_start_pos
	
	var extra_params = {
		"shred": stats.get("armor_shred", 0.0),
		"scale": stats.get("area_size", 1.0),
		"is_crit": is_crit
	}
	
	if proj.has_method("initialize"):
		proj.initialize(start, direction, projectile_speed, final_damage, target_lane_id, element, texture, color, false, extra_params)
	
	_can_shoot = false
	_update_timer()
	fire_rate_timer.start()

func _on_fire_rate_timer_timeout() -> void:
	_can_shoot = true
