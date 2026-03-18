class_name ClutterResource
extends Resource

@export var id: String = "rock"
@export var scene: PackedScene
# LOOSENED TYPE: Changed from ItemResource to Resource to ensure parse stability
@export var drop_item: Resource
@export var drop_count: int = 1
