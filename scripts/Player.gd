extends CharacterBody2D

# Load the Attack class definitions
const Attack = preload("res://scripts/Attack.gd")
const Skill = preload("res://skill-system/Skill.gd")

# EXPORT VARIABLES
@export var player_id: int = 1

@export_group("Movement")
@export var walk_speed = 300.0
@export var sprint_speed = 600.0
@export var jump_velocity = -800.0
@export var friction = 1200.0
@export var acceleration = 1500.0
@export var fast_fall_multiplier = 2.0
@export var fast_fall_velocity = 400.0
@export var fast_fall_peak_threshold = 400.0
@export var max_jumps = 2
@export var jump_buffer_time = 0.15
@export var jump_release_gravity_multiplier = 3.0
@export var landing_lag_duration = 0.15

@export_group("Debugging")
## If checked, active hitboxes will be drawn on screen.
@export var debug_draw_hitboxes: bool = false

# ATTACK & SKILL VARIABLES
var attacks_map = {}
var skills_map = {}
var skills_list: Array[Skill] = []
var current_attack: Attack = null # Can be a normal Attack or a Skill
var attack_input_buffered = ""
var combo_counters: Dictionary = {} # Tracks progress for each attack chain
var last_attack_chain: StringName = &""
var _last_anim_frame = -1
var is_in_fixed_move = false
var skill_actions = ["skill1", "skill2", "skill3", "skill4"]

# SPRINT (DOUBLE TAP) VARIABLES
var last_tap_dir = 0
var last_tap_time = 0.0
const DOUBLE_TAP_WINDOW = 0.3
var sprinting_by_double_tap = false

# JUMP VARIABLES
var jump_count = 0
var jump_input_buffered = false
var did_fast_fall_this_airtime = false

# STATE MACHINE
enum State {IDLE, WALK, SPRINT, CROUCH, JUMP, FALL, ATTACK, ATTACK_LAG, SPRINT_JUMP, LANDING_LAG}
var current_state = State.IDLE

# NODE REFERENCES
@onready var animated_sprite = $AnimatedSprite2D
@onready var hitbox_area = $Hitbox
@onready var attacks_node = $Attacks
@onready var skills_node = $Skills
@onready var skill_bar = $CanvasLayer/SkillBar
@onready var combo_timer = $ComboTimer
@onready var attack_lag_timer = $AttackLagTimer
@onready var landing_lag_timer = $LandingLagTimer
@onready var jump_buffer_timer = $JumpBufferTimer
@onready var fixed_move_timer = $FixedMoveTimer

# --- Optimization: Cache input action strings ---
var _input_left: String
var _input_right: String
var _input_down: String
var _input_jump: String
var _input_sprint: String
var _input_attack1: String
var _input_attack2: String

# Gravity
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

# Helper variable for landing detection
var was_airborne = false


func _ready():
	if player_id == 2:
		animated_sprite.modulate = Color("dc143c") # Crimson
	
	animated_sprite.animation_finished.connect(_on_animation_finished)
	
	parse_attacks()
	parse_skills()
	setup_skill_bar()
	
	# Configure timers
	landing_lag_timer.wait_time = landing_lag_duration
	jump_buffer_timer.wait_time = jump_buffer_time
	fixed_move_timer.timeout.connect(_on_fixed_move_timer_timeout)
	
	_input_left = "p%d_left" % player_id
	_input_right = "p%d_right" % player_id
	_input_down = "p%d_down" % player_id
	_input_jump = "p%d_jump" % player_id
	_input_sprint = "p%d_sprint" % player_id
	_input_attack1 = "p%d_attack1" % player_id
	_input_attack2 = "p%d_attack2" % player_id

func _draw():
	if not debug_draw_hitboxes or current_state != State.ATTACK:
		return
	
	for shape_node in hitbox_area.get_children():
		if shape_node is CollisionShape2D:
			var shape = shape_node.shape
			var position = shape_node.position
			
			if shape is RectangleShape2D:
				draw_rect(Rect2(position - shape.size / 2, shape.size), Color(1, 0, 0, 0.5))


func parse_attacks():
	attacks_map.clear()
	for attack_node in attacks_node.get_children():
		if not attack_node is Attack:
			continue
		
		var attack: Attack = attack_node
		var state = attack.required_state
		var input = attack.required_input

		if not attacks_map.has(state):
			attacks_map[state] = {}
		if not attacks_map[state].has(input):
			attacks_map[state][input] = []
			
		attacks_map[state][input].append(attack)
	
	# Sort each list by combo_index to make logic predictable
	for state in attacks_map:
		for input in attacks_map[state]:
			attacks_map[state][input].sort_custom(func(a, b): return a.combo_index < b.combo_index)

func parse_skills():
	skills_map.clear()
	skills_list.clear()
	for skill_node in skills_node.get_children():
		if skill_node is Skill:
			var skill: Skill = skill_node
			if not skill.skill_input_action.is_empty():
				skills_map[skill.skill_input_action] = skill
				skills_list.append(skill)
	# Sort by action name to keep UI consistent
	skills_list.sort_custom(func(a, b): return a.skill_input_action < b.skill_input_action)

func setup_skill_bar():
	if is_instance_valid(skill_bar):
		skill_bar.setup_skill_bar(skills_list)

func _physics_process(delta):
	was_airborne = not is_on_floor()
	
	if not (current_state == State.ATTACK and is_in_fixed_move):
		apply_gravity(delta)
	
	match current_state:
		State.IDLE, State.WALK, State.SPRINT, State.CROUCH:
			handle_ground_state(delta)
		State.JUMP, State.FALL, State.SPRINT_JUMP:
			handle_air_state(delta)
		State.ATTACK:
			handle_attack_state(delta)
		State.ATTACK_LAG:
			handle_attack_lag_state(delta)
		State.LANDING_LAG:
			handle_landing_lag_state(delta)
			
	handle_input()
	handle_jumping()
	move_and_slide()

	if was_airborne and is_on_floor():
		handle_landing()
	
	if current_state == State.ATTACK:
		update_active_hitboxes()
	else:
		clear_active_hitboxes() # Ensure hitboxes are off when not attacking
	
	if debug_draw_hitboxes:
		queue_redraw()

	update_animation_and_flip()
	_last_anim_frame = animated_sprite.frame


func apply_gravity(delta):
	if not is_on_floor():
		var gravity_multiplier = 1.0
		if velocity.y < 0 and not Input.is_action_pressed(_input_jump):
			gravity_multiplier = jump_release_gravity_multiplier
		elif velocity.y > 0 and Input.is_action_pressed(_input_down) and current_state not in [State.ATTACK_LAG, State.LANDING_LAG, State.ATTACK]:
			gravity_multiplier = fast_fall_multiplier
			did_fast_fall_this_airtime = true
		velocity.y += gravity * gravity_multiplier * delta


func handle_input():
	if current_state in [State.ATTACK_LAG, State.LANDING_LAG]:
		return

	# Attack Inputs
	if Input.is_action_just_pressed(_input_attack1):
		handle_attack_input("attack1")
	if Input.is_action_just_pressed(_input_attack2):
		handle_attack_input("attack2")
	
	# Skill Inputs
	for action in skill_actions:
		if Input.is_action_just_pressed(action):
			handle_skill_input(action)
			
	# Fast Fall
	if not is_on_floor() and Input.is_action_just_pressed(_input_down):
		if abs(velocity.y) < fast_fall_peak_threshold:
			velocity.y = fast_fall_velocity
			did_fast_fall_this_airtime = true

func handle_ground_state(delta):
	if not is_on_floor():
		current_state = State.FALL
		return
	handle_ground_movement(delta)

func handle_air_state(delta):
	handle_air_movement(delta)

func handle_attack_state(delta):
	if not current_attack: return # Safety check
	
	var current_frame = animated_sprite.frame
	
	# --- Directional Cancel Logic ---
	if current_attack.can_directional_cancel and current_frame >= current_attack.directional_cancel_start_frame:
		var facing_right = not animated_sprite.flip_h
		var opposite_input_pressed = (facing_right and Input.is_action_just_pressed(_input_left)) or \
									 (not facing_right and Input.is_action_just_pressed(_input_right))
		if opposite_input_pressed:
			_end_attack_state() # Cancel the attack with no lag
			return # Exit early

	# --- Skill Effect Logic ---
	if current_attack is Skill:
		var skill: Skill = current_attack
		if current_frame >= skill.effect_frame and _last_anim_frame < skill.effect_frame:
			skill.execute_effect(self)

	# --- Movement Logic ---
	match current_attack.movement_type:
		"Apply Velocity":
			if current_frame >= current_attack.applied_velocity_frame and _last_anim_frame < current_attack.applied_velocity_frame:
				var facing_dir = -1.0 if animated_sprite.flip_h else 1.0
				velocity += current_attack.applied_velocity * Vector2(facing_dir, 1.0)
			if is_on_floor(): velocity.x = move_toward(velocity.x, 0, friction * delta / 2)
			else: velocity.x = move_toward(velocity.x, 0, friction * delta * 0.25)
		
		"Fixed Distance":
			if not is_in_fixed_move and current_frame >= current_attack.move_start_frame and _last_anim_frame < current_attack.move_start_frame:
				is_in_fixed_move = true
				fixed_move_timer.wait_time = current_attack.move_duration
				fixed_move_timer.start()

			if is_in_fixed_move:
				var facing_dir = -1.0 if animated_sprite.flip_h else 1.0
				var move_velocity = current_attack.move_distance / current_attack.move_duration
				velocity.x = move_velocity.x * facing_dir
				velocity.y = move_velocity.y
			else:
				if is_on_floor(): velocity.x = move_toward(velocity.x, 0, friction * delta / 2)
				else: velocity.x = move_toward(velocity.x, 0, friction * delta * 0.25)
		
		"None":
			if is_on_floor(): velocity.x = move_toward(velocity.x, 0, friction * delta / 2)
			else: velocity.x = move_toward(velocity.x, 0, friction * delta * 0.25)

	# --- Combo/Cancel Logic ---
	if attack_input_buffered != "" and current_frame >= current_attack.cancel_frame:
		var buffered_input = attack_input_buffered
		attack_input_buffered = ""
		_end_attack_state() # End current attack cleanly before starting next
		find_and_initiate_attack(buffered_input)
		if current_state == State.ATTACK: return

func handle_attack_lag_state(delta):
	velocity.x = move_toward(velocity.x, 0, friction * delta)

func handle_landing_lag_state(delta):
	if Input.is_action_just_pressed(_input_jump):
		velocity.y = jump_velocity
		current_state = State.JUMP
		jump_count += 1
		landing_lag_timer.stop()
		return
	velocity.x = move_toward(velocity.x, 0, friction * delta)

func handle_landing():
	if current_state in [State.JUMP, State.FALL, State.SPRINT_JUMP, State.ATTACK]:
		_end_attack_state() # Clears attack state, hitboxes, etc.
		jump_count = 0
		
		# Reset combo state on landing
		combo_counters.clear()
		last_attack_chain = &""
		combo_timer.stop()
		
		if did_fast_fall_this_airtime:
			animated_sprite.play("Land")
			current_state = State.LANDING_LAG
			landing_lag_timer.start()
		else:
			current_state = State.IDLE
		did_fast_fall_this_airtime = false

func handle_ground_movement(delta):
	var direction = Input.get_axis(_input_left, _input_right)
	
	if Input.is_action_pressed(_input_down) and direction == 0:
		current_state = State.CROUCH
		velocity.x = move_toward(velocity.x, 0, friction * delta)
		return
	elif current_state == State.CROUCH:
		current_state = State.IDLE

	if direction != 0:
		var just_pressed_dir = Input.is_action_just_pressed(_input_left) or Input.is_action_just_pressed(_input_right)
		if just_pressed_dir:
			var current_time = Time.get_ticks_msec() / 1000.0
			if current_time - last_tap_time < DOUBLE_TAP_WINDOW and sign(direction) == sign(last_tap_dir):
				sprinting_by_double_tap = true
			elif sign(direction) != sign(last_tap_dir):
				sprinting_by_double_tap = false
			last_tap_time = current_time
			last_tap_dir = direction
		
		var sprint_by_key = Input.is_action_pressed(_input_sprint)
		
		if sprint_by_key or sprinting_by_double_tap:
			current_state = State.SPRINT
			velocity.x = move_toward(velocity.x, sprint_speed * direction, acceleration * delta)
		else:
			sprinting_by_double_tap = false
			current_state = State.WALK
			velocity.x = move_toward(velocity.x, walk_speed * direction, acceleration * delta)
	else:
		sprinting_by_double_tap = false
		current_state = State.IDLE
		velocity.x = move_toward(velocity.x, 0, friction * delta)

func handle_air_movement(delta):
	var direction = Input.get_axis(_input_left, _input_right)
	var target_air_speed = walk_speed
	if current_state == State.SPRINT_JUMP:
		target_air_speed = sprint_speed
	if direction != 0:
		velocity.x = move_toward(velocity.x, target_air_speed * direction, acceleration * delta * 0.75)

func handle_jumping():
	if Input.is_action_just_pressed(_input_jump):
		jump_input_buffered = true
		jump_buffer_timer.start()
	var wants_to_jump = jump_input_buffered or (is_on_floor() and Input.is_action_pressed(_input_jump))
	if not wants_to_jump: return
	if current_state in [State.ATTACK_LAG, State.LANDING_LAG, State.CROUCH]: return
	if jump_count >= max_jumps: return
	if not is_on_floor() and not jump_input_buffered: return
	
	jump_input_buffered = false
	jump_buffer_timer.stop()
	did_fast_fall_this_airtime = false
	
	if current_state == State.ATTACK and current_attack and animated_sprite.frame < current_attack.cancel_frame:
		return
	
	velocity.y = jump_velocity
	
	if is_on_floor():
		if current_state == State.SPRINT:
			current_state = State.SPRINT_JUMP
		else:
			current_state = State.JUMP
	
	jump_count += 1

func handle_attack_input(type: String):
	if current_state == State.ATTACK:
		if current_attack and animated_sprite.frame < current_attack.cancel_frame:
			attack_input_buffered = type
		else:
			find_and_initiate_attack(type)
	elif current_state not in [State.ATTACK_LAG, State.LANDING_LAG]:
		find_and_initiate_attack(type)

func handle_skill_input(action: String):
	# Can't use skills while already attacking, in lag, etc.
	if current_state in [State.ATTACK, State.ATTACK_LAG, State.LANDING_LAG]:
		return
		
	var skill: Skill = skills_map.get(action)
	
	if skill and skill.can_use():
		# Check if player state is valid for this skill (e.g. Grounded/Aerial)
		var player_posture = "Aerial" if not is_on_floor() else "Grounded"
		if skill.required_state == player_posture or skill.required_state == "Any": # Added "Any" for flexibility
			initiate_attack(skill) # Re-use the attack initiation logic
			skill.start_cooldown()

func find_and_initiate_attack(input: String):
	# Determine current state context for attacks
	var state_key = "Grounded"
	if not is_on_floor(): state_key = "Aerial"
	elif current_state == State.SPRINT: state_key = "Running"
	elif current_state == State.CROUCH: state_key = "Crouching"

	if not attacks_map.has(state_key) or not attacks_map[state_key].has(input):
		return # No attacks for this state/input combination

	var possible_attacks = attacks_map[state_key][input]
	var attack_to_initiate: Attack = null

	# 1. Try to continue an existing combo from the last used chain
	if not combo_timer.is_stopped() and last_attack_chain != &"":
		var current_combo_index = combo_counters.get(last_attack_chain, 0)
		var next_combo_index = current_combo_index + 1
		
		for attack in possible_attacks:
			if attack.attack_chain == last_attack_chain and attack.combo_index == next_combo_index:
				attack_to_initiate = attack
				break

	# 2. If no combo to continue, find a starter attack (combo_index == 1)
	if not attack_to_initiate:
		# Reset combo state before starting a new one
		if last_attack_chain != &"":
			combo_counters.erase(last_attack_chain)
		last_attack_chain = &""

		for attack in possible_attacks:
			if attack.combo_index == 1:
				attack_to_initiate = attack
				break
	
	# 3. Initiate the found attack
	if attack_to_initiate:
		initiate_attack(attack_to_initiate)


func initiate_attack(attack_data: Attack):
	current_state = State.ATTACK
	attack_input_buffered = ""
	current_attack = attack_data
	
	if not attack_data is Skill:
		# If this is a new chain, clear the old one's progress.
		# This handles switching from an attack1 combo to an attack2 combo starter.
		if attack_data.attack_chain != last_attack_chain and last_attack_chain != &"":
			combo_counters.erase(last_attack_chain)

		last_attack_chain = attack_data.attack_chain
		combo_counters[last_attack_chain] = attack_data.combo_index
		combo_timer.start()

	animated_sprite.play(attack_data.animation_name)
	_last_anim_frame = -1

func stop_fixed_move():
	if is_in_fixed_move:
		is_in_fixed_move = false
		fixed_move_timer.stop()
		velocity = Vector2.ZERO

func clear_active_hitboxes():
	for child in hitbox_area.get_children():
		child.queue_free()

func update_active_hitboxes():
	clear_active_hitboxes() # Clear previous frame's hitboxes.
	if not current_attack:
		return

	var frame = animated_sprite.frame
	
	for editor_hitbox in current_attack.get_children():
		if "start_frame" in editor_hitbox and "end_frame" in editor_hitbox:
			if frame >= editor_hitbox.start_frame and frame < editor_hitbox.end_frame:
				var new_shape_node = CollisionShape2D.new()
				var rect_shape = RectangleShape2D.new()
				
				rect_shape.size = editor_hitbox.size
				new_shape_node.position = editor_hitbox.position + editor_hitbox.size / 2.0
				
				new_shape_node.shape = rect_shape
				hitbox_area.add_child(new_shape_node)

func update_animation_and_flip():
	var direction = Input.get_axis(_input_left, _input_right)
	if direction != 0:
		if current_state == State.ATTACK and current_attack and not current_attack.can_turn_around:
			pass # Do not allow turning
		else:
			var is_flipped = direction < 0
			animated_sprite.flip_h = is_flipped
			hitbox_area.scale.x = -1 if is_flipped else 1

	if current_state in [State.ATTACK, State.ATTACK_LAG, State.LANDING_LAG]:
		return

	var anim_to_play = ""
	match current_state:
		State.IDLE: anim_to_play = "Idle"
		State.WALK: anim_to_play = "Walk"
		State.SPRINT: anim_to_play = "Sprint"
		State.CROUCH: anim_to_play = "Crouch"
		State.JUMP:
			if animated_sprite.animation != "Jump_Start": anim_to_play = "Jump_Start"
		State.FALL: anim_to_play = "Fall"
		State.SPRINT_JUMP: anim_to_play = "Sprint_Jump"
	
	if anim_to_play and animated_sprite.animation != anim_to_play:
		animated_sprite.play(anim_to_play)

func _end_attack_state(lag_duration: float = 0.0):
	stop_fixed_move()
	clear_active_hitboxes()
	current_attack = null
	if lag_duration > 0:
		current_state = State.ATTACK_LAG
		attack_lag_timer.wait_time = lag_duration
		attack_lag_timer.start()
	else:
		current_state = State.IDLE if is_on_floor() else State.FALL

func _on_animation_finished():
	var anim_name = animated_sprite.animation
	if current_attack and anim_name == current_attack.animation_name:
		_end_attack_state(current_attack.end_lag_duration)
	elif anim_name == "Jump_Start" or anim_name == "Sprint_Jump":
		current_state = State.FALL

func _on_combo_timer_timeout():
	if last_attack_chain != &"":
		combo_counters.erase(last_attack_chain)
		last_attack_chain = &""

func _on_attack_lag_timer_timeout():
	current_state = State.IDLE if is_on_floor() else State.FALL

func _on_landing_lag_timer_timeout():
	if current_state == State.LANDING_LAG:
		current_state = State.IDLE

func _on_jump_buffer_timer_timeout():
	jump_input_buffered = false

func _on_fixed_move_timer_timeout():
	is_in_fixed_move = false
	if is_on_floor():
		velocity = Vector2.ZERO
	else:
		velocity.x = 0