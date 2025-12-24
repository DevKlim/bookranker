@tool
class_name BaseBuilding
extends StaticBody2D

enum Direction { DOWN, LEFT, UP, RIGHT }

const ARROW_DOWN = preload("res://assets/ui/arrowdown.png")
const ARROW_LEFT = preload("res://assets/ui/arrowleft.png")
const ARROW_UP = preload("res://assets/ui/arrowup.png")
const ARROW_RIGHT = preload("res://assets/ui/arrowright.png")
const GridComponentScript = preload("res://scripts/components/grid_component.gd")

# Use loose typing to avoid cyclic dependency issues
@onready var power_consumer: Node = $PowerConsumerComponent
@onready var health_component: Node = $HealthComponent

var grid_component: Node
@export var powered_color: Color = Color(1, 1, 1, 1)
@export var unpowered_color: Color = Color(0.2, 0.2, 0.2, 1)

@export_group("I/O Configuration")
@export var output_direction: Direction = Direction.DOWN:
	set(value): output_direction = value; queue_redraw()
@export var input_direction: Direction = Direction.UP:
	set(value): input_direction = value; queue_redraw()
@export var has_input: bool = true:
	set(value): has_input = value; queue_redraw()
@export var has_output: bool = true:
	set(value): has_output = value; queue_redraw()

var visual_offset: Vector2 = Vector2.ZERO
var center_offset: Vector2 = Vector2.ZERO 
var is_active: bool = false

var stats: Dictionary = {
	"speed_mult": 1.0,
	"power_efficiency": 1.0,
	"output_count": 0.0,
	"luck": 0.0,
	"xp_gain": 1.0,
	"max_health_mult": 1.0,
	"health_regen": 0.0,
	"armor": 0.0,
	"thorns": 0.0,
	"damage_mult": 1.0,
	"crit_chance": 0.0,
	"crit_damage": 1.5,
	"area_size": 1.0,
	"phys_boost": 0.0,
	"magic_boost": 0.0,
	"armor_shred": 0.0,
}

var _base_power_consumption: float = 5.0
var _base_max_health: float = 100.0

func _get_main_sprite() -> AnimatedSprite2D:
	return get_node_or_null("AnimatedSprite2D")

func _ready() -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return
	
	var sprite = _get_main_sprite()
	if sprite: sprite.position = visual_offset
	
	if not has_node("GridComponent"):
		grid_component = GridComponentScript.new()
		grid_component.name = "GridComponent"
		grid_component.layer = "building"
		if "snap_to_grid" in grid_component:
			grid_component.snap_to_grid = true
		add_child(grid_component)
	else:
		grid_component = get_node("GridComponent")

	# Added safety checks to prevent "Bad address index" if nodes are missing
	if not power_consumer:
		printerr("BaseBuilding %s: Missing PowerConsumerComponent" % name)
		return
		
	if not health_component:
		printerr("BaseBuilding %s: Missing HealthComponent" % name)
		return
	
	if health_component.has_signal("died"):
		health_component.died.connect(_on_died)
	
	if "power_consumption" in power_consumer:
		_base_power_consumption = power_consumer.power_consumption
	if "max_health" in health_component:
		_base_max_health = health_component.max_health
	
	# Default to parsing our own animation name to set direction if set in editor
	var sprite_node = _get_main_sprite()
	if sprite_node and sprite_node.sprite_frames:
		set_build_rotation(sprite_node.animation)
	else:
		set_build_rotation(&"idle_down")
		
	_on_power_status_changed(false)
	PowerGridManager.register_consumer(power_consumer)
	
	var invs = []
	if has_node("InventoryComponent"): invs.append(get_node("InventoryComponent"))
	if has_node("InputInventory"): invs.append(get_node("InputInventory"))
	
	for inv in invs:
		if not inv.is_connected("inventory_changed", _recalculate_modifiers):
			inv.inventory_changed.connect(_recalculate_modifiers)

func _recalculate_modifiers() -> void:
	# Reset defaults
	stats["speed_mult"] = 1.0
	stats["power_efficiency"] = 1.0
	stats["output_count"] = 0.0
	stats["luck"] = 0.0
	stats["xp_gain"] = 1.0
	stats["max_health_mult"] = 1.0
	stats["health_regen"] = 0.0
	stats["armor"] = 0.0
	stats["thorns"] = 0.0
	stats["damage_mult"] = 1.0
	stats["crit_chance"] = 0.0
	stats["crit_damage"] = 1.5
	stats["area_size"] = 1.0
	stats["phys_boost"] = 0.0
	stats["magic_boost"] = 0.0
	stats["armor_shred"] = 0.0

	var inventories = []
	if has_node("InventoryComponent"): inventories.append(get_node("InventoryComponent"))
	if has_node("InputInventory"): inventories.append(get_node("InputInventory"))
	
	for inv in inventories:
		if not is_instance_valid(inv): continue
		# Safety check for slot access
		if "slots" in inv and inv.slots is Array:
			for slot in inv.slots:
				if slot != null and slot.item and slot.item.modifiers:
					_apply_item_mods(slot.item.modifiers)
	
	# Apply Logic safely
	if is_instance_valid(power_consumer) and "power_consumption" in power_consumer:
		power_consumer.power_consumption = max(0.1, _base_power_consumption * stats["power_efficiency"])
	
	if is_instance_valid(health_component) and "max_health" in health_component and "current_health" in health_component:
		var new_max = _base_max_health * stats["max_health_mult"]
		if new_max != health_component.max_health:
			var ratio = 1.0
			if health_component.max_health > 0:
				ratio = health_component.current_health / health_component.max_health
			health_component.max_health = new_max
			health_component.current_health = new_max * ratio
		
		# Set dynamic stats if variables exist on component
		if "armor" in health_component: health_component.armor = stats["armor"]
		if "thorns" in health_component: health_component.thorns = stats["thorns"]
		if "regen_rate" in health_component: health_component.regen_rate = stats["health_regen"]

func _apply_item_mods(mods: Dictionary) -> void:
	for key in mods:
		if stats.has(key):
			if key == "crit_damage" or key == "output_count" or key == "luck" or \
			   key == "armor" or key == "thorns" or key == "health_regen" or \
			   key == "crit_chance" or key == "phys_boost" or key == "magic_boost" or key == "armor_shred":
				stats[key] += mods[key]
			else:
				stats[key] *= mods[key]

func get_stat(key: String) -> float:
	return stats.get(key, 0.0)

func _draw() -> void:
	if not Engine.is_editor_hint(): return
	if has_input:
		var tex = _get_arrow_texture(input_direction)
		if tex: draw_texture(tex, (-tex.get_size() / 2.0) + visual_offset, Color(1, 0, 0, 0.7))
	if has_output:
		var tex = _get_arrow_texture(output_direction)
		if tex: draw_texture(tex, (-tex.get_size() / 2.0) + visual_offset, Color(0, 1, 0, 0.7))

func _get_arrow_texture(dir: Direction) -> Texture2D:
	match dir:
		Direction.DOWN: return ARROW_DOWN
		Direction.LEFT: return ARROW_LEFT
		Direction.UP: return ARROW_UP
		Direction.RIGHT: return ARROW_RIGHT
	return null

func _on_power_status_changed(has_power: bool) -> void:
	is_active = has_power
	var animated_sprite = _get_main_sprite()
	if not is_instance_valid(animated_sprite): return
	if has_power: animated_sprite.modulate = powered_color
	else: animated_sprite.modulate = unpowered_color

func set_build_rotation(anim_name: StringName) -> void:
	var animated_sprite = _get_main_sprite()
	if is_instance_valid(animated_sprite) and animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)
	
	# Dynamic parsing of direction from animation suffix
	var s = String(anim_name)
	if s.ends_with("down"):
		output_direction = Direction.DOWN; input_direction = Direction.UP
	elif s.ends_with("left"):
		output_direction = Direction.LEFT; input_direction = Direction.RIGHT
	elif s.ends_with("up"):
		output_direction = Direction.UP; input_direction = Direction.DOWN
	elif s.ends_with("right"):
		output_direction = Direction.RIGHT; input_direction = Direction.LEFT
	
	if Engine.is_editor_hint(): queue_redraw()

func get_sprite_frames() -> SpriteFrames:
	var s = _get_main_sprite()
	return s.sprite_frames if s else null

func get_visual_configuration(_anim: StringName) -> Array: return []
func get_occupied_cells(_anim: StringName) -> Array[Vector2i]: return [Vector2i.ZERO]
func _on_died(_node): queue_free()
func receive_item(_i, _n=null): return false
func get_neighbor(dir: Direction) -> Node2D:
	if Engine.is_editor_hint(): return null
	var tile = LaneManager.world_to_tile(global_position)
	var log_c = LaneManager.get_logical_from_tile(tile)
	var t_tile = Vector2i(-1,-1)
	if log_c != Vector2i(-1,-1):
		var lt = log_c
		match dir:
			Direction.DOWN: lt.y-=1
			Direction.LEFT: lt.x+=1
			Direction.UP: lt.y+=1
			Direction.RIGHT: lt.x-=1
		t_tile = LaneManager.get_tile_from_logical(lt.x, lt.y)
	if t_tile == Vector2i(-1,-1):
		match dir:
			Direction.DOWN: t_tile=tile+Vector2i(0,1)
			Direction.UP: t_tile=tile+Vector2i(0,-1)
			Direction.LEFT: t_tile=tile+Vector2i(-1,0)
			Direction.RIGHT: t_tile=tile+Vector2i(1,0)
	return LaneManager.get_buildable_at(t_tile)

func try_output_from_inventory(inv: InventoryComponent) -> bool:
	if not has_output or not inv.has_item(): return false
	var n = get_neighbor(output_direction)
	if is_instance_valid(n) and n.has_method("receive_item"):
		if n.get("has_input") == false: return false
		var it = inv.get_first_item()
		if it and n.receive_item(it, self):
			inv.remove_item(it, 1)
			return true
	return false

func requires_recipe_selection() -> bool: return false

