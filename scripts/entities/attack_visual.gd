class_name AttackVisual
extends Node3D

@export var animation_player_path: NodePath = "AnimationPlayer"
@export var animation_name: String = "default"

func _ready() -> void:
	var anim = get_node_or_null(animation_player_path)
	if anim and anim.has_animation(animation_name):
		anim.play(animation_name)
		anim.animation_finished.connect(_on_finished)
	else:
		# Fallback safety
		get_tree().create_timer(1.0).timeout.connect(queue_free)

func _on_finished(_anim_name: String) -> void:
	queue_free()
	