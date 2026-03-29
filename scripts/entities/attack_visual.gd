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
		
	# Boosts render priority so that weapon attacks/slashes always draw above standard transparents & HUD outlines
	_set_render_priority_recursive(self, 100)

func _set_render_priority_recursive(node: Node, priority: int) -> void:
	if node is MeshInstance3D and node.mesh:
		for i in range(node.mesh.get_surface_count()):
			var mat = node.get_active_material(i)
			if mat:
				# Duplicate to avoid affecting global shared materials
				var unique_mat = mat.duplicate()
				unique_mat.render_priority = priority
				node.set_surface_override_material(i, unique_mat)
	elif node is Sprite3D or node is AnimatedSprite3D:
		node.render_priority = priority
		
	for child in node.get_children():
		_set_render_priority_recursive(child, priority)

func _on_finished(_anim_name: String) -> void:
	queue_free()
