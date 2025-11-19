class_name Core
extends StaticBody2D

## The main script for the Core entity, the player's primary objective to defend.


# References to the Core's components.
@onready var health_component: HealthComponent = $HealthComponent
@onready var power_provider_component: PowerProviderComponent = $PowerProviderComponent


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Assertions to ensure the necessary components are present during development.
	assert(health_component, "Core is missing a HealthComponent!")
	assert(power_provider_component, "Core is missing a PowerProviderComponent!")
		
	# Connect to the health component's 'died' signal to handle game over.
	health_component.died.connect(_on_died)
	
	# Register the Core as a power provider in the global power grid.
	PowerGridManager.register_provider(power_provider_component)

	# Register the Core's position with the BuildManager so nothing can be built on it,
	# and so enemies recognize it as a blocking entity.
	BuildManager.register_preplaced_building(self)
	
	# Log initial status for debugging.
	print("Core is operational. Initial health: %d" % health_component.current_health)
	print("Core power output: %d" % power_provider_component.power_generation)


## Handles the destruction of the Core.
func _on_died(_node_that_died) -> void:
	print("The Core has been destroyed! GAME OVER.")
	# Tell the GameManager that the player lost.
	GameManager.end_game(false) # player_won = false
	# The Core disappears from the game.
	queue_free()
