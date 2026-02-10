class_name ClutterResource
extends Resource

@export var id: String = "rock"
@export var scene: PackedScene
# LOOSENED TYPE: Changed from ItemResource to Resource to ensure parse stability
@export var drop_item: Resource
@export var drop_count: int = 1

@export_group("Generation")
@export var min_depth: int = 0
@export var max_depth: int = 30
@export_range(0.0, 1.0) var rarity: float = 0.1
## Number of times this clutter is guaranteed to attempt spawning on map generation, before random chance.
@export var guaranteed_spawns: int = 0
