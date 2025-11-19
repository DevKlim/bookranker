class_name ResourceDeposit
extends Node2D

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	# Randomize rotation/scale slightly for variety
	if sprite:
		sprite.rotation = randf_range(0, TAU)
		var scale_mod = randf_range(1, 1)
		sprite.scale = Vector2(scale_mod, scale_mod) * 0.75