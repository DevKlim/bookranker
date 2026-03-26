class_name ShooterComponent
extends Node

## Handles shooting logic for turrets/buildings.

@export var fire_point_path: NodePath
var fire_point: Marker3D

var last_shot_time: int = 0
var cooldown_ms: int = 1000

## Base elemental units applied by the building itself (if any).
@export var base_element_units: int = 0

func _ready() -> void:
	if not fire_point_path.is_empty():
		fire_point = get_node(fire_point_path)

func can_shoot() -> bool:
	return (Time.get_ticks_msec() - last_shot_time) >= cooldown_ms

func shoot_in_direction(dir: Vector3, lane_id: int, ammo_item: Resource, override_pos: Vector3 = Vector3.ZERO) -> bool:
	if not can_shoot(): return false
	
	var dmg = 10.0
	var speed = 200.0
	var elem = null
	var units = 1
	var ignore_cd = false
	var scene_to_spawn = load("res://scenes/entities/projectile.tscn")
	var tex = null
	var col = Color.WHITE
	
	if ammo_item:
		if "damage" in ammo_item: dmg = float(ammo_item.get("damage"))
		if "element" in ammo_item: elem = ammo_item.get("element")
		
		# Use MAX(building units, item units)
		var i_units = 1
		if "element_units" in ammo_item: i_units = int(ammo_item.get("element_units"))
		units = max(base_element_units, i_units)
		
		if "ignore_element_cooldown" in ammo_item: ignore_cd = bool(ammo_item.get("ignore_element_cooldown"))
		
		if "projectile_scene" in ammo_item and ammo_item.get("projectile_scene"):
			scene_to_spawn = ammo_item.get("projectile_scene")
		if "icon" in ammo_item and ammo_item.get("icon"):
			tex = ammo_item.get("icon")
		if "color" in ammo_item: col = ammo_item.get("color")
		
		# Apply Elemental Stats from Component (e.g., Building Mods)
		var parent = get_parent()
		if parent.has_node("ElementalComponent"):
			var ec = parent.get_node("ElementalComponent")
			var d_mult = ec.get_stat_modifier("damage_mult")
			dmg *= (1.0 + d_mult)
	
	# Fallback if no ammo item passed (legacy infinite ammo logic)
	else:
		tex = load("res://icon.svg")
		units = max(1, base_element_units)
	
	var spawn_pos = override_pos
	if fire_point: spawn_pos = fire_point.global_position
	
	var p = scene_to_spawn.instantiate()
	get_tree().root.add_child(p)
	
	# Pass unit data via extra_params to the Projectile
	var params = {
		"source": get_parent(),
		"element_units": units,
		"ignore_element_cd": ignore_cd
	}
	p.initialize(spawn_pos, dir, speed, dmg, lane_id, elem, tex, col, false, params)
	
	last_shot_time = Time.get_ticks_msec()
	return true
