class_name HighlightComponent
extends Node

## ECS Component: Exposes child meshes to the HighlightSystem's 2D outline shader
## by automatically tagging them into Layer 11 (1024).

@export var is_highlighted: bool = true:
	set(val):
		is_highlighted = val
		_apply_highlight(get_parent(), val)

func _ready() -> void:
	_apply_highlight(get_parent(), is_highlighted)

func _apply_highlight(node: Node, enabled: bool) -> void:
	if not is_instance_valid(node): return
	
	# Specifically ignore particle systems so they don't get blocky outlines
	if node is GPUParticles3D or node is CPUParticles3D:
		return
		
	if node is VisualInstance3D:
		if enabled:
			node.layers |= 1024
		else:
			node.layers &= ~1024
			
	for child in node.get_children():
		_apply_highlight(child, enabled)