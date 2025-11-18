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
	assert(_get_main_sprite(), "%s is missing an AnimatedSprite2D node!" % self.name)
	
	PowerGridManager.register_consumer(power_consumer)
	health_component.died.connect(_on_died)
	
	# Set initial unpowered state visuals
	_on_power_status_changed(false)

	# Set default animation state
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
