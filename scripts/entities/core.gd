class_name Core
extends StaticBody3D

## The main script for the Core entity, the player's primary objective to defend.


# References to the Core's components.
@onready var health_component: HealthComponent = $HealthComponent
@onready var power_provider_component: PowerProviderComponent = $PowerProviderComponent
@onready var mesh_instance: MeshInstance3D = $Core

# Original material storage for toggling transparency
var _default_material: Material
var _transparent_material: StandardMaterial3D

# Damage Visuals
var _tint_tween: Tween

## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Assertions to ensure the necessary components are present during development.
	assert(health_component, "Core is missing a HealthComponent!")
	assert(power_provider_component, "Core is missing a PowerProviderComponent!")
		
	# Connect to the health component's 'died' signal to handle game over.
	health_component.died.connect(_on_died)
	health_component.health_changed.connect(_on_health_changed)
	
	# Set power generation to 100 as requested
	power_provider_component.power_generation = 100.0
	
	# Register the Core as a power provider in the global power grid.
	PowerGridManager.register_provider(power_provider_component)

	# Register the Core's footprint (5x5 area) in the LaneManager to prevent building overlap.
	# The Core is centered at logical tile (0, 2).
	# A 5x5 area implies offsets of -2 to +2 in both X and Z directions from the center.
	var center_tile = Vector2i(-3, 2)
	for x_off in range(-2, 3):
		for z_off in range(-2, 3):
			var tile_pos = center_tile + Vector2i(x_off, z_off)
			LaneManager.register_entity(self, tile_pos, "building")
	
	# Prepare transparency materials
	if mesh_instance:
		_default_material = mesh_instance.get_active_material(0)
		# If no material exists, create a basic one
		if not _default_material:
			_default_material = StandardMaterial3D.new()
			_default_material.albedo_color = Color(0.2, 0.5, 1.0) # Core Blue
			mesh_instance.material_override = _default_material
			
		_transparent_material = StandardMaterial3D.new()
		# Copy basics
		if _default_material is StandardMaterial3D:
			_transparent_material.albedo_color = _default_material.albedo_color
		else:
			_transparent_material.albedo_color = Color(0.2, 0.5, 1.0)
			
		_transparent_material.albedo_color.a = 0.3
		_transparent_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	# Log initial status for debugging.
	print("Core is operational at %s. Initial health: %d" % [global_position, health_component.current_health])
	print("Core power output: %d" % power_provider_component.power_generation)


## Handles the destruction of the Core.
func _on_died(_node_that_died) -> void:
	print("The Core has been destroyed! GAME OVER.")
	# Tell the GameManager that the player lost.
	GameManager.end_game(false) # player_won = false
	# The Core disappears from the game.
	queue_free()

func _on_health_changed(new_val, old_val) -> void:
	if new_val < old_val:
		_flash_damage()

func _flash_damage() -> void:
	if not mesh_instance: return
	if _tint_tween: _tint_tween.kill()
	_tint_tween = create_tween()
	
	var base_col = Color(0.2, 0.5, 1.0) # Core Blue
	if _default_material is StandardMaterial3D:
		base_col = _default_material.albedo_color
		
	var damage_col = Color(1.0, 0.2, 0.2, 1.0) # Flash Red
	
	_tint_tween.tween_method(_apply_tint_color, damage_col, base_col, 0.3)

func _apply_tint_color(col: Color) -> void:
	# Apply to the active material override (could be default or transparent)
	var mat = mesh_instance.material_override
	if mat is StandardMaterial3D:
		mat.albedo_color = col

func set_transparent(is_transparent: bool) -> void:
	if not mesh_instance: return
	
	if is_transparent:
		if mesh_instance.material_override != _transparent_material:
			mesh_instance.material_override = _transparent_material
	else:
		if mesh_instance.material_override != _default_material:
			mesh_instance.material_override = _default_material
