extends Resource

class_name HitboxData

@export var shape: Shape2D
@export var position: Vector2 = Vector2.ZERO
@export var start_frame: int = 0
@export var end_frame: int = 999

@export_group("Damage Properties")
@export var damage: float = 10.0
## How long the victim is stunned and cannot act.
@export var stun_duration: float = 0.2
## A brief freeze-frame for the attacker to add impact.
@export var hitlag_duration: float = 0.08

@export_group("Knockback Properties")
@export var knockback_amount: float = 400.0
## Direction relative to the attacker (e.g., (1, -1) is forward and up). This will be flipped automatically for the attacker's direction.
@export var knockback_direction: Vector2 = Vector2(1, -0.5).normalized()