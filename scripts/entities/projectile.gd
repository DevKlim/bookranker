class_name Projectile
extends Area2D

## The script for a projectile. It handles its own movement and collision logic.

var _velocity: Vector2 = Vector2.ZERO
var _damage: float = 0.0
var _element: ElementResource = null
var lane_id: int = -1

@onready var sprite: Sprite2D = $Sprite2D

func _physics_process(delta: float) -> void:
	global_position += _velocity * delta

## Initializes the projectile with its starting properties.
func initialize(start_position: Vector2, direction: Vector2, speed: float, damage: float, p_lane_id: int, p_element: ElementResource = null, texture: Texture2D = null, color: Color = Color.WHITE) -> void:
	global_position = start_position
	_velocity = direction * speed
	_damage = damage
	lane_id = p_lane_id
	_element = p_element
	
	rotation = direction.angle()
	
	if texture:
		sprite.texture = texture
	
	# Apply color. If element exists, prioritize element color, otherwise item color.
	if _element:
		sprite.self_modulate = _element.color
	else:
		sprite.self_modulate = color
	
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body is EnemyUnit and body.get_lane_id() == self.lane_id:
		if body.has_method("take_damage"):
			body.take_damage(_damage)
		
		if _element:
			ElementManager.apply_element(body, _element)
		
		queue_free()
