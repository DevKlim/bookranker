extends Node

class_name AttackHandlerComponent

signal attack_initiated(attack_data)
signal attack_ended
signal attack_lag_started(duration)
signal hit_target(duration)
signal skills_updated(skills_array)

@onready var combo_timer: Timer = $ComboTimer
@onready var attack_lag_timer: Timer = $AttackLagTimer

var owner_player: CharacterBody2D # Use the base type to avoid circular dependency
var owner_stats: StatsComponent
var owner_sprite: AnimatedSprite2D

var current_attack: Attack = null
var current_chain: StringName = &""
var current_combo_index: int = 0
var buffered_attack_input: String = ""
var hit_targets_this_attack: Array[Node] = []

var combo_chains: Dictionary = {}
var skills_by_input: Dictionary = {}
var skill_cooldowns: Dictionary = {}

# Use CharacterBody2D as the type hint for the owner node.
# This is a key step to prevent circular dependency errors with Player.gd.
func initialize(owner_node: CharacterBody2D, stats_node: StatsComponent, sprite_node: AnimatedSprite2D, player_id: int):
	owner_player = owner_node
	owner_stats = stats_node
	owner_sprite = sprite_node
	
	var skill_list: Array[Attack] = []
	for attack in get_children():
		if not attack is Attack: continue
		
		if attack.attack_type == "Skill":
			if not attack.skill_input_action.is_empty():
				var full_action_name = "p%d_%s" % [player_id, attack.skill_input_action]
				skills_by_input[full_action_name] = attack
				skill_list.append(attack)
		else: # "Combo"
			if not combo_chains.has(attack.attack_chain):
				combo_chains[attack.attack_chain] = {}
			combo_chains[attack.attack_chain][attack.combo_index] = attack
	
	emit_signal("skills_updated", skill_list)

func handle_attack_input(input_action: String):
	if current_attack:
		var frame = owner_sprite.frame
		if frame >= current_attack.cancel_frame:
			try_to_perform_attack(input_action)
		else:
			buffered_attack_input = input_action
		return
	
	try_to_perform_attack(input_action)
	
func try_to_perform_attack(input_action: String):
	var next_attack: Attack
	
	if skills_by_input.has(input_action):
		next_attack = skills_by_input[input_action]
	else:
		var base_input = input_action.trim_prefix("p%d_" % owner_player.player_id)
		next_attack = _get_next_combo_attack(base_input)

	if next_attack and _can_perform_attack(next_attack):
		_perform_attack(next_attack)

# --- REWRITTEN FUNCTION ---
# This function is now smarter. It first tries to continue an existing combo.
# If that's not possible, it searches for ANY valid combo starter (index 1)
# that matches the player's current state (like "Aerial").
func _get_next_combo_attack(base_input_action: String) -> Attack:
	# 1. Try to continue the current combo chain
	if not combo_timer.is_stopped() and combo_chains.has(current_chain):
		var next_index_in_chain = current_combo_index + 1
		var chain = combo_chains[current_chain]
		if chain.has(next_index_in_chain) and chain[next_index_in_chain].required_input == base_input_action:
			return chain[next_index_in_chain]

	# 2. If not continuing, find a NEW valid chain starter that matches the player's state
	for chain_name in combo_chains:
		var chain = combo_chains[chain_name]
		if chain.has(1): # Is there a starting attack in this chain?
			var starting_attack: Attack = chain[1]
			# Check if input AND state requirements are met
			if starting_attack.required_input == base_input_action and owner_player.check_required_state(starting_attack.required_state):
				current_chain = chain_name # Set the new chain we are starting
				return starting_attack
				
	# 3. If no valid attack is found
	return null


func _can_perform_attack(attack_data: Attack) -> bool:
	# owner_player is a CharacterBody2D, but we know it's our Player script,
	# so we can safely call methods from Player.gd on it.
	if not owner_player.check_required_state(attack_data.required_state):
		return false
	
	# Check cooldowns
	if skill_cooldowns.has(attack_data) and Time.get_ticks_msec() < skill_cooldowns.get(attack_data, 0):
		return false
	
	# Check resource costs
	if owner_stats.mana < attack_data.mana_cost:
		return false
	if owner_stats.health <= attack_data.hp_cost: # Can't pay with your last breath
		return false

	return true

func _perform_attack(attack_data: Attack):
	# Deduct costs and start cooldown first
	owner_stats.use_mana(attack_data.mana_cost)
	owner_stats.use_health(attack_data.hp_cost)
	
	if attack_data.cooldown > 0.0:
		skill_cooldowns[attack_data] = Time.get_ticks_msec() + (attack_data.cooldown * 1000)

	current_attack = attack_data
	if attack_data.attack_type == "Combo":
		current_combo_index = attack_data.combo_index
		current_chain = attack_data.attack_chain
		combo_timer.start()
	
	hit_targets_this_attack.clear()
	buffered_attack_input = ""
	emit_signal("attack_initiated", attack_data)

func check_for_buffered_attack():
	if not buffered_attack_input.is_empty():
		var frame = owner_sprite.frame
		if current_attack and frame >= current_attack.cancel_frame:
			var buffered_input = buffered_attack_input
			buffered_attack_input = ""
			try_to_perform_attack(buffered_input)

func on_animation_finished(anim_name: StringName):
	if current_attack and anim_name == current_attack.animation_name:
		_end_attack()

func on_land():
	if current_attack and current_attack.required_state == "Aerial":
		_end_attack()

func on_hurt():
	if current_attack:
		current_attack = null
		current_combo_index = 0
		current_chain = &""
		combo_timer.stop()

func _end_attack():
	if not current_attack: return
	
	var lag_duration = current_attack.end_lag_duration
	current_attack = null
	
	if lag_duration > 0:
		emit_signal("attack_lag_started", lag_duration)
	else:
		emit_signal("attack_ended")

func on_hit_target(hitbox: HitboxData):
	emit_signal("hit_target", hitbox.hitlag_duration)
