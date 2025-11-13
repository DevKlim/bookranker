class_name BaseBuilding
extends StaticBody2D

@onready var power_consumer: PowerConsumerComponent = $PowerConsumerComponent
@onready var sprite: Sprite2D = $Sprite2D

@export var powered_color: Color = Color(1, 1, 1, 1)
@export var unpowered_color: Color = Color(0.2, 0.2, 0.2, 1)

var is_active: bool = false


func _ready() -> void:
	assert(power_consumer, "%s is missing PowerConsumerComponent!" % self.name)
	assert(sprite, "%s is missing a Sprite2D node named 'Sprite2D'!" % self.name)
	
	PowerGridManager.register_consumer(power_consumer)
	
	# Set initial unpowered state visuals
	_on_power_status_changed(false)


func _on_power_status_changed(has_power: bool) -> void:
	is_active = has_power
	if has_power:
		sprite.modulate = powered_color
	else:
		sprite.modulate = unpowered_color