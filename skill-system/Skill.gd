class_name Skill
extends Attack

@export_group("Skill Properties")
@export var skill_name: String = "New Skill"
@export var description: String = "Skill description."
@export var cooldown: float = 1.0
@export var skill_input_action: String # e.g., "skill1"
@export var effect_frame: int = 0

var cooldown_timer: float = 0.0

func _process(delta: float) -> void:
	if cooldown_timer > 0:
		cooldown_timer -= delta
		cooldown_timer = max(0.0, cooldown_timer)

func can_use() -> bool:
	return cooldown_timer <= 0

func start_cooldown() -> void:
	cooldown_timer = cooldown

# This is where the skill's actual effect happens (e.g., spawning a projectile).
# It's called from Player.gd when the animation hits the effect_frame.
func execute_effect(player: CharacterBody2D) -> void:
	# Base implementation does nothing. Override in specific skills.
	print("Executing base skill effect for %s." % skill_name)