class_name Wire
extends BaseWiring

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var is_powered: bool = false
# Connections: 1:down, 2:left, 3:up, 4:right
var connections: Array[int] = []

func _ready() -> void:
	assert(animated_sprite, "Wire scene requires an AnimatedSprite2D child.")
	update_visuals()

func set_powered(p_is_powered: bool) -> void:
	if is_powered != p_is_powered:
		is_powered = p_is_powered
		update_visuals()

func set_connections(p_connections: Array[int]) -> void:
	# Sort to ensure consistent animation names (e.g., "12" not "21")
	p_connections.sort()
	if connections != p_connections:
		connections = p_connections
		update_visuals()

func update_visuals() -> void:
	var state_prefix = "on_" if is_powered else "off_"
	var suffix = "0"
	if not connections.is_empty():
		suffix = "".join(connections.map(func(i): return str(i)))

	var anim_name = state_prefix + suffix
	
	if animated_sprite.sprite_frames.has_animation(anim_name):
		animated_sprite.play(anim_name)
	else:
		# Fallback to a default state if a specific connection animation is missing
		var fallback_anim = state_prefix + "0"
		if animated_sprite.sprite_frames.has_animation(fallback_anim):
			animated_sprite.play(fallback_anim)
