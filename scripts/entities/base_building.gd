class_name BaseBuilding
extends StaticBody2D

enum Direction { DOWN, LEFT, UP, RIGHT }

@onready var power_consumer: PowerConsumerComponent = $PowerConsumerComponent
@onready var health_component: HealthComponent = $HealthComponent

@export var powered_color: Color = Color(1, 1, 1, 1)
@export var unpowered_color: Color = Color(0.2, 0.2, 0.2, 1)

@export var output_direction: Direction = Direction.DOWN
@export var input_direction: Direction = Direction.UP

var is_active: bool = false

# This helper allows subclasses (like Turret) to specify where their main sprite is.
func _get_main_sprite() -> AnimatedSprite2D:
	return get_node_or_null("AnimatedSprite2D")


func _ready() -> void:
	assert(power_consumer, "%s is missing PowerConsumerComponent!" % self.name)
	assert(health_component, "%s is missing HealthComponent!" % self.name)
	
	PowerGridManager.register_consumer(power_consumer)
	health_component.died.connect(_on_died)
	
	_on_power_status_changed(false)
	set_build_rotation(&"idle_down")


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
	if not is_instance_valid(animated_sprite): return
	
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


func get_sprite_frames() -> SpriteFrames:
	var animated_sprite = _get_main_sprite()
	if is_instance_valid(animated_sprite):
		return animated_sprite.sprite_frames
	return null


func _on_died(_node):
	queue_free()

## Helper to find the building adjacent in a specific direction.
func get_neighbor(dir: Direction) -> Node2D:
	var tile_coord = LaneManager.tile_map.local_to_map(global_position)
	var log_coord = LaneManager.get_logical_from_tile(tile_coord)
	if log_coord == Vector2i(-1, -1): return null
	
	var target_log = log_coord
	
	# Directions mapped to logical grid changes:
	# DOWN (Depth - 1), LEFT (Lane + 1), UP (Depth + 1), RIGHT (Lane - 1)
	match dir:
		Direction.DOWN: target_log += Vector2i(0, -1)
		Direction.LEFT: target_log += Vector2i(1, 0)
		Direction.UP: target_log += Vector2i(0, 1)
		Direction.RIGHT: target_log += Vector2i(-1, 0)
	
	var target_tile = LaneManager.get_tile_from_logical(target_log.x, target_log.y)
	return LaneManager.get_buildable_at(target_tile)

## Interface for buildings to accept items (e.g. from conveyors).
## Returns true if item was accepted.
func receive_item(item: ItemResource) -> bool:
	return false
