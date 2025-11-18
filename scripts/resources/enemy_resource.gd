class_name EnemyResource
extends Resource

@export var enemy_name: String = "Enemy"
@export var scene: PackedScene
@export var health: float = 50.0
@export var speed: float = 75.0
@export var attack_damage: float = 10.0
@export var attack_speed: float = 1.0 # Attacks per second
@export var attack_element: ElementResource
