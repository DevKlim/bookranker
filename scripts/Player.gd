extends CharacterBody2D

# EXPORT VARIABLES
@export var player_id: int = 1

@export_group("Movement")
@export var walk_speed = 300.0
@export var sprint_speed = 600.0
@export var jump_velocity = -800.0
@export var friction = 1200.0
@export var acceleration = 1500.0
@export var fast_fall_multiplier = 2.0
@export var max_jumps = 2

@export_group("Combat")
@export var knockback_force = 900.0
@export var combo_reset_time = 0.8 # Window to reset combo after the last attack

# SPRINT (DOUBLE TAP) VARIABLES
var last_tap_dir = 0
var last_tap_time = 0.0
const DOUBLE_TAP_WINDOW = 0.3

# ATTACK VARIABLES
var attack1_combo = 0
var attack2_combo = 0
var attack_input_buffered = ""

# COMBO WEAVING RULES
# "window_frame" is the first frame where a combo into the next attack is allowed.
const COMBO_RULES = {
	"Attack1_1": {"next_attack_type": "attack1", "window_frame": 2},
	"Attack1_2": {"next_attack_type": "attack1", "window_frame": 5},
	"Attack2_1": {"next_attack_type": "attack2", "window_frame": 2},
	"Attack2_2": {"next_attack_type": "attack2", "window_frame": 2},
	"Attack2_3": {"next_attack_type": "attack2", "window_frame": 1}
	# No rules for Attack1_3 or Attack2_4 as they are combo enders
}

# JUMP VARIABLES
var jump_count = 0

# STATE MACHINE
enum State {IDLE, WALK, SPRINT, CROUCH, JUMP, FALL, ATTACK, HURT}
var current_state = State.IDLE

# NODE REFERENCES
@onready var animated_sprite = $AnimatedSprite2D
@onready var hitbox_shape = $Hitbox/CollisionShape2D
@onready var combo_timer = $ComboTimer
@onready var collision_shape = $CollisionShape2D

# Store original shapes for crouching
var standing_shape: CapsuleShape2D
var crouching_shape: CapsuleShape2D

# Gravity
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")


func _ready():
	if player_id == 2:
		animated_sprite.modulate = Color("dc143c") # Crimson
	
	animated_sprite.animation_finished.connect(_on_animation_finished)
	combo_timer.wait_time = combo_reset_time
	
	if collision_shape.shape is CapsuleShape2D:
		standing_shape = collision_shape.shape
		crouching_shape = standing_shape.duplicate()
		crouching_shape.height = standing_shape.height / 2.0


func _physics_process(delta):
	apply_gravity(delta)
	handle_input()
	
	match current_state:
		State.IDLE, State.WALK, State.SPRINT, State.CROUCH:
			handle_ground_state(delta)
		State.JUMP, State.FALL:
			handle_air_state(delta)
		State.ATTACK:
			handle_attack_state(delta)
		State.HURT:
			if is_on_floor():
				velocity.x = move_toward(velocity.x, 0, friction * delta)

	move_and_slide()
	update_animation_and_flip()


func apply_gravity(delta):
	if not is_on_floor():
		var gravity_multiplier = 1.0
		if velocity.y > 0 and Input.is_action_pressed("p%d_down" % player_id):
			gravity_multiplier = fast_fall_multiplier
		velocity.y += gravity * gravity_multiplier * delta
	else:
		if current_state != State.JUMP:
			jump_count = 0


func handle_input():
	if Input.is_action_just_pressed("p%d_attack1" % player_id):
		handle_attack_input("attack1")
	if Input.is_action_just_pressed("p%d_attack2" % player_id):
		handle_attack_input("attack2")
	if Input.is_action_just_pressed("p%d_jump" % player_id):
		handle_jumping()


# --- State Handlers ---

func handle_ground_state(delta):
	if not is_on_floor():
		current_state = State.FALL
		return
	handle_ground_movement(delta)


func handle_air_state(delta):
	if is_on_floor():
		animated_sprite.play("Land")
		current_state = State.IDLE
		return
	handle_air_movement(delta)


func handle_attack_state(delta):
	# Allow combo weaving
	handle_combo_weaving()
	# Apply some friction during attacks
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0, friction * delta / 2)
	else:
		velocity.x = move_toward(velocity.x, 0, friction * delta * 0.25)


# --- Sub-Handlers (Movement, Attacks, etc.) ---

func handle_ground_movement(delta):
	var direction = Input.get_axis("p%d_left" % player_id, "p%d_right" % player_id)

	if Input.is_action_pressed("p%d_down" % player_id) and direction == 0:
		current_state = State.CROUCH
		velocity.x = move_toward(velocity.x, 0, friction * delta)
		if crouching_shape: collision_shape.shape = crouching_shape
		return
	else:
		if current_state == State.CROUCH:
			current_state = State.IDLE
		if standing_shape: collision_shape.shape = standing_shape
	
	check_for_sprint(direction)
	
	var target_speed = walk_speed
	if current_state == State.SPRINT:
		target_speed = sprint_speed

	if direction != 0:
		velocity.x = move_toward(velocity.x, target_speed * direction, acceleration * delta)
		if current_state != State.SPRINT:
			current_state = State.WALK
	else:
		velocity.x = move_toward(velocity.x, 0, friction * delta)
		if current_state in [State.WALK, State.SPRINT]:
			current_state = State.IDLE


func handle_air_movement(delta):
	var direction = Input.get_axis("p%d_left" % player_id, "p%d_right" % player_id)
	if direction != 0:
		velocity.x = move_toward(velocity.x, walk_speed * direction, acceleration * delta * 0.75)


func handle_jumping():
	if jump_count < max_jumps:
		velocity.y = jump_velocity
		jump_count += 1
		# Don't change state if already in JUMP/FALL (for double jumps)
		if current_state != State.JUMP and current_state != State.FALL:
			current_state = State.JUMP


func check_for_sprint(direction):
	if Input.is_action_pressed("p%d_sprint" % player_id) and direction != 0:
		current_state = State.SPRINT
		return

	if Input.is_action_just_pressed("p%d_left" % player_id) or Input.is_action_just_pressed("p%d_right" % player_id):
		var current_time = Time.get_ticks_msec() / 1000.0
		if current_time - last_tap_time < DOUBLE_TAP_WINDOW and direction == last_tap_dir and direction != 0:
			current_state = State.SPRINT
		last_tap_time = current_time
		last_tap_dir = direction


func handle_attack_input(type: String):
	if current_state == State.ATTACK:
		# Buffer the input if we are already attacking
		attack_input_buffered = type
	elif current_state not in [State.HURT, State.CROUCH]:
		# Otherwise, initiate a new attack
		initiate_attack(type)
		
		
func handle_combo_weaving():
	if attack_input_buffered == "":
		return
	
	var current_anim = animated_sprite.animation
	if not COMBO_RULES.has(current_anim):
		return
		
	var rule = COMBO_RULES[current_anim]
	if attack_input_buffered == rule.next_attack_type and animated_sprite.frame >= rule.window_frame:
		var attack_to_start = attack_input_buffered
		attack_input_buffered = "" # Consume the buffer
		initiate_attack(attack_to_start) # Immediately start the next attack


func initiate_attack(attack_type: String):
	current_state = State.ATTACK
	attack_input_buffered = "" # Clear buffer on successful initiation
	
	# Stop player for the first ground attack for commitment
	if is_on_floor() and not animated_sprite.animation.begins_with("Attack"):
		velocity.x = 0

	var anim_to_play = ""
	if is_on_floor():
		if attack_type == "attack1":
			attack1_combo = (attack1_combo % 3) + 1
			attack2_combo = 0 # Reset other combo chain
			anim_to_play = "Attack1_" + str(attack1_combo)
		elif attack_type == "attack2":
			attack2_combo = (attack2_combo % 4) + 1
			attack1_combo = 0 # Reset other combo chain
			anim_to_play = "Attack2_" + str(attack2_combo)
	else: # Air attacks
		attack1_combo = 0; attack2_combo = 0 # Reset ground combos
		if attack_type == "attack1":
			anim_to_play = "Air_Attack1"
		elif attack_type == "attack2":
			anim_to_play = "Air_Attack2"
	
	if anim_to_play != "":
		animated_sprite.play(anim_to_play)
		enable_hitbox(true)
		combo_timer.start() # This timer is for dropping the combo entirely


func take_damage(attacker_position):
	if current_state == State.HURT: return

	current_state = State.HURT
	animated_sprite.play("Hurt")
	attack1_combo = 0; attack2_combo = 0
	
	var direction_to_attacker = (attacker_position - global_position).normalized()
	velocity = - direction_to_attacker * knockback_force
	velocity.y = jump_velocity * 0.6


func update_animation_and_flip():
	if current_state != State.ATTACK:
		var direction = Input.get_axis("p%d_left" % player_id, "p%d_right" % player_id)
		if direction != 0:
			animated_sprite.flip_h = (direction < 0)
			hitbox_shape.get_parent().scale.x = -1 if animated_sprite.flip_h else 1

	if current_state in [State.ATTACK, State.HURT]:
		return

	var anim_to_play = ""
	match current_state:
		State.IDLE: anim_to_play = "Idle"
		State.WALK: anim_to_play = "Walk"
		State.SPRINT: anim_to_play = "Sprint"
		State.CROUCH: anim_to_play = "Crouch"
		State.JUMP:
			if animated_sprite.animation != "Jump_Start":
				anim_to_play = "Jump_Start"
		State.FALL:
			anim_to_play = "Fall"
	
	if anim_to_play and animated_sprite.animation != anim_to_play:
		animated_sprite.play(anim_to_play)

# --- Signal Callbacks ---

func _on_animation_finished():
	var anim_name = animated_sprite.animation
	
	if anim_name.begins_with("Attack") or anim_name.begins_with("Air_"):
		enable_hitbox(false)
		# If the animation finished and we weren't able to weave into another,
		# the combo is over. Return to a neutral state.
		if current_state == State.ATTACK:
			current_state = State.FALL if not is_on_floor() else State.IDLE
	
	if anim_name in ["Land", "Hurt"]:
		current_state = State.IDLE
	if anim_name == "Jump_Start":
		current_state = State.FALL


func _on_combo_timer_timeout():
	attack1_combo = 0
	attack2_combo = 0


func _on_hurtbox_area_entered(area):
	if area.is_in_group("hitbox") and area.get_parent().get_parent() != self:
		var attacker = area.get_parent().get_parent()
		take_damage(attacker.global_position)


func enable_hitbox(enable: bool):
	hitbox_shape.disabled = not enable