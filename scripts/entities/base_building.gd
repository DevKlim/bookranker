@tool
class_name BaseBuilding
extends StaticBody2D

enum Direction { DOWN, LEFT, UP, RIGHT }

# Preload textures for the editor visualization
const ARROW_DOWN = preload("res://assets/ui/arrowdown.png")
const ARROW_LEFT = preload("res://assets/ui/arrowleft.png")
const ARROW_UP = preload("res://assets/ui/arrowup.png")
const ARROW_RIGHT = preload("res://assets/ui/arrowright.png")

# Preload GridComponent script to avoid class_name parse errors
const GridComponentScript = preload("res://scripts/components/grid_component.gd")

@onready var power_consumer: PowerConsumerComponent = $PowerConsumerComponent
@onready var health_component: HealthComponent = $HealthComponent

# Typed as Node to avoid parser errors if class DB is stale, but it is a GridComponent
var grid_component: Node

@export var powered_color: Color = Color(1, 1, 1, 1)
@export var unpowered_color: Color = Color(0.2, 0.2, 0.2, 1)

@export_group("I/O Configuration")
@export var output_direction: Direction = Direction.DOWN:
	set(value):
		output_direction = value
		queue_redraw()

@export var input_direction: Direction = Direction.UP:
	set(value):
		input_direction = value
		queue_redraw()

@export var has_input: bool = true:
	set(value):
		has_input = value
		queue_redraw()

@export var has_output: bool = true:
	set(value):
		has_output = value
		queue_redraw()

## The visual offset applied ONLY to the sprite, not the root.
## This is set by the BuildManager upon instantiation.
var visual_offset: Vector2 = Vector2.ZERO

## Center Offset determines logic center. 
## Since GridComponent now snaps ROOT to Tile Center, this should be ZERO for logic calculations based on root.
var center_offset: Vector2 = Vector2.ZERO 

var is_active: bool = false

func _get_main_sprite() -> AnimatedSprite2D:
	return get_node_or_null("AnimatedSprite2D")

func _ready() -> void:
	if Engine.is_editor_hint():
		queue_redraw()
		return
	
	# Apply Visual Offset to Sprite Position ONLY.
	# The Root node stays at the tile center logic point.
	var sprite = _get_main_sprite()
	if sprite:
		sprite.position = visual_offset
	
	# Add GridComponent dynamically if not present in scene
	if not has_node("GridComponent"):
		grid_component = GridComponentScript.new()
		grid_component.name = "GridComponent"
		grid_component.layer = "building"
		grid_component.snap_to_grid = true # Enforce snap!
		add_child(grid_component)
	else:
		grid_component = get_node("GridComponent")

	assert(power_consumer, "%s is missing PowerConsumerComponent!" % self.name)
	assert(health_component, "%s is missing HealthComponent!" % self.name)
	
	health_component.died.connect(_on_died)
	
	# Initial state setup
	set_build_rotation(&"idle_down")
	_on_power_status_changed(false)

	# Register consumer
	PowerGridManager.register_consumer(power_consumer)

func _draw() -> void:
	# Only draw these debug arrows in the editor
	if not Engine.is_editor_hint():
		return
		
	if has_input:
		var tex = _get_arrow_texture(input_direction)
		if tex:
			# Draw input arrow (Red Tint) centered, including visual offset
			draw_texture(tex, (-tex.get_size() / 2.0) + visual_offset, Color(1, 0, 0, 0.7))
	
	if has_output:
		var tex = _get_arrow_texture(output_direction)
		if tex:
			# Draw output arrow (Green/White Tint) centered, including visual offset
			draw_texture(tex, (-tex.get_size() / 2.0) + visual_offset, Color(0, 1, 0, 0.7))

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
	
	if has_power:
		animated_sprite.modulate = powered_color
	else:
		animated_sprite.modulate = unpowered_color

func set_build_rotation(anim_name: StringName) -> void:
	var animated_sprite = _get_main_sprite()
	if is_instance_valid(animated_sprite):
		if animated_sprite.sprite_frames.has_animation(anim_name):
			animated_sprite.play(anim_name)

	match anim_name:
		&"idle_down":
			output_direction = Direction.DOWN
			input_direction = Direction.UP
		&"idle_left":
			output_direction = Direction.LEFT
			input_direction = Direction.RIGHT
		&"idle_up":
			output_direction = Direction.UP
			input_direction = Direction.DOWN
		&"idle_right":
			output_direction = Direction.RIGHT
			input_direction = Direction.LEFT
	
	if Engine.is_editor_hint():
		queue_redraw()

func get_sprite_frames() -> SpriteFrames:
	var animated_sprite = _get_main_sprite()
	if is_instance_valid(animated_sprite):
		return animated_sprite.sprite_frames
	return null

## Virtual method to return configuration for extra sprite tiles (OFFSET ONLY).
## Returns Array of Dictionary: { "offset": Vector2i (tile_coords), "animation": StringName }
func get_visual_configuration(_anim_name: StringName) -> Array:
	return []

## Virtual method to return ALL occupied logical cells relative to (0,0) (including 0,0).
## If empty, assumes standard 1x1 at (0,0).
func get_occupied_cells(_anim_name: StringName) -> Array[Vector2i]:
	return [Vector2i.ZERO]

func _on_died(_node):
	queue_free()

func get_neighbor(dir: Direction) -> Node2D:
	if Engine.is_editor_hint(): return null

	# Use Root position (Tile Center)
	var tile_center_pos = global_position
	var current_tile = LaneManager.world_to_tile(tile_center_pos) 
	var log_coord = LaneManager.get_logical_from_tile(current_tile)
	
	var target_tile = Vector2i(-1, -1)

	# 1. Try Logical Lane Grid
	if log_coord != Vector2i(-1, -1):
		var target_log = log_coord
		match dir:
			Direction.DOWN: target_log += Vector2i(0, -1)
			Direction.LEFT: target_log += Vector2i(1, 0)
			Direction.UP: target_log += Vector2i(0, 1)
			Direction.RIGHT: target_log += Vector2i(-1, 0)
		target_tile = LaneManager.get_tile_from_logical(target_log.x, target_log.y)

	# 2. Fallback to Physical Grid
	if target_tile == Vector2i(-1, -1):
		var offset = Vector2i.ZERO
		match dir:
			Direction.DOWN: offset = Vector2i(0, 1)
			Direction.UP: offset = Vector2i(0, -1)
			Direction.LEFT: offset = Vector2i(-1, 0)
			Direction.RIGHT: offset = Vector2i(1, 0)
		target_tile = current_tile + offset

	if target_tile == Vector2i(-1, -1): return null
	return LaneManager.get_buildable_at(target_tile)

func try_output_from_inventory(inventory: InventoryComponent) -> bool:
	if not has_output: return false
	if not inventory.has_item(): return false
	
	var neighbor = get_neighbor(output_direction)
	
	if is_instance_valid(neighbor) and neighbor.has_method("receive_item"):
		if neighbor is BaseBuilding and not neighbor.has_input:
			return false
			
		var item = inventory.get_first_item()
		if item:
			if neighbor.receive_item(item, self):
				inventory.remove_item(item, 1)
				return true
	return false

func receive_item(_item: ItemResource, _from_node: Node2D = null) -> bool:
	return false

func requires_recipe_selection() -> bool:
	return false
