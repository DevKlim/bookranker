class_name ClutterObject
extends StaticBody3D

## A natural object blocking a tile (e.g., Rock, Tree).
## Can be destroyed to clear the tile and yield items.

# LOOSENED TYPE: Changed from ClutterResource to Resource to prevent cyclic dependency errors
@export var clutter_resource: Resource

var health_component: HealthComponent
var grid_component: GridComponent

func _ready() -> void:
	# Setup Components
	health_component = HealthComponent.new()
	health_component.name = "HealthComponent"
	health_component.max_health = 10.0 
	health_component.current_health = 10.0
	add_child(health_component)
	
	health_component.died.connect(_on_died)
	
	# Register to Grid so we block buildings
	grid_component = GridComponent.new()
	grid_component.name = "GridComponent"
	grid_component.layer = "building" # Occupies the building layer
	add_child(grid_component)

func take_damage(amount: float, _element: Resource = null, _source: Node = null) -> void:
	if health_component:
		health_component.take_damage(amount, _element, _source)
		_flash_damage()

func _on_died(_node) -> void:
	if clutter_resource and "drop_item" in clutter_resource and clutter_resource.drop_item:
		# Add to player inventory (Global Game Inventory)
		if PlayerManager.game_inventory:
			var remainder = PlayerManager.game_inventory.add_item(clutter_resource.drop_item, clutter_resource.drop_count)
			if remainder > 0:
				pass
	
	queue_free()

# Visual Flash
func _flash_damage() -> void:
	var mesh = get_node_or_null("Visual")
	if mesh and mesh is MeshInstance3D:
		var tween = create_tween()
		tween.tween_property(mesh, "transparency", 0.5, 0.1)
		tween.tween_property(mesh, "transparency", 0.0, 0.1)
