extends Control

@onready var health_bar_instant = $VBoxContainer/HealthBar/HealthBarInstant
@onready var health_bar_delayed = $VBoxContainer/HealthBar/HealthBarDelayed
@onready var mana_bar_instant = $VBoxContainer/ManaBar/ManaBarInstant
@onready var mana_bar_delayed = $VBoxContainer/ManaBar/ManaBarDelayed

# This function is called by Main.gd to connect this UI to a specific player.
func link_to_player(player_node: CharacterBody2D):
	if not is_instance_valid(player_node):
		return

	# Get the StatsComponent, which is a child of the player node.
	var stats_component = player_node.get_node_or_null("StatsComponent")
	if not stats_component:
		push_error("PlayerUI could not find StatsComponent on player: %s" % player_node.name)
		return

	# Connect to the signals that are emitted by the StatsComponent.
	stats_component.health_changed.connect(_on_health_changed)
	stats_component.mana_changed.connect(_on_mana_changed)
	
	# Set the initial values for the bars by getting them from the stats_component.
	_on_health_changed(stats_component.health, stats_component.max_health)
	_on_mana_changed(stats_component.mana, stats_component.max_mana)

func _on_health_changed(current_health: float, max_health: float):
	update_bar(health_bar_instant, health_bar_delayed, current_health, max_health)

func _on_mana_changed(current_mana: float, max_mana: float):
	update_bar(mana_bar_instant, mana_bar_delayed, current_mana, max_mana)
	
func update_bar(instant_bar: TextureProgressBar, delayed_bar: TextureProgressBar, current_value: float, max_value: float):
	# Update the max value for both bars
	instant_bar.max_value = max_value
	delayed_bar.max_value = max_value
	
	# The "instant" bar reflects the new value immediately.
	instant_bar.value = current_value
	
	# Create a tween to smoothly animate the "delayed" bar to the new value.
	# This creates the nice effect of the bar draining/filling after the instant change.
	var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(delayed_bar, "value", current_value, 0.6)