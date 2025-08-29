# PlayerUI.gd (Updated)
extends CanvasLayer

# --- NODE REFERENCES ---
# Get references to the player and its components
@onready var player = get_parent()
@onready var health_component = player.find_child("HealthComponent")
@onready var mana_component = player.find_child("ManaComponent")
@onready var skill_handler = player.find_child("PlayerSkillHandler")

# Get references to the UI elements you placed in the editor
@onready var health_bar = $StatBarsContainer/VBoxContainer/HealthBar
@onready var mana_bar = $StatBarsContainer/VBoxContainer/ManaBar
@onready var skill_bar = $SkillBarContainer


func _ready():
	# If this UI doesn't belong to the local player, delete it.
	if not player.is_multiplayer_authority():
		queue_free()
		return

	# --- Connect UI to Player Data ---
	# Connect health component signals to the health bar UI
	if health_component and health_bar:
		health_component.health_changed.connect(health_bar.update_bar)
		health_bar.initialize(health_component.current_health, health_component.max_health)

	# Connect mana component signals to the mana bar UI
	if mana_component and mana_bar:
		mana_component.mana_changed.connect(mana_bar.update_bar)
		mana_bar.initialize(mana_component.current_mana, mana_component.max_mana)
		
	# Pass the skill data to the skill bar UI
	if skill_handler and skill_bar:
		skill_bar.setup_skill_bar(skill_handler.skills)
