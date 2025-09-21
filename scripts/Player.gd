extends CharacterBody2D
class_name Player

# STATE MACHINE
enum State {IDLE, MOVE, CROUCH, AERIAL, ATTACK, ATTACK_LAG, LANDING_LAG, HURT, HITLAG, DEAD, FREE_FALL, SLIDE}
var current_state = State.AERIAL # Start in the air to trigger landing logic correctly

@export var player_id: int = 1

# NODE REFERENCES (COMPONENTS)
@onready var stats: StatsComponent = $StatsComponent
@onready var movement: MovementComponent = $MovementComponent
@onready var attack_handler: AttackHandlerComponent = $AttackHandlerComponent
@onready var animation_handler: AnimationComponent = $AnimationComponent

# NODE REFERENCES (Other)
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox_area: Area2D = $Hitbox
@onready var hurtbox: Area2D = $Hurtbox
@onready var hitlag_timer: Timer = $HitlagTimer
@onready var hurt_timer: Timer = $HurtTimer
@onready var landing_lag_timer: Timer = $LandingLagTimer
@onready var jump_buffer_timer: Timer = $JumpBufferTimer
@onready var fixed_move_timer: Timer = $FixedMoveTimer
@onready var attack_lag_timer: Timer = $AttackHandlerComponent/AttackLagTimer
@onready var double_tap_timer: Timer = Timer.new()

# STATE VARIABLES
var inputs: Dictionary
var jump_count: int = 0
var jump_input_buffered: bool = false
var was_airborne: bool = true
var is_invincible: bool = false

# SPRINTING
@export_group("Sprinting")
@export var double_tap_time_threshold: float = 0.25
var is_sprinting: bool = false
var double_tap_sprint_enabled: bool = false
var last_tap_dir: int = 0

# ATTACK MOVEMENT
var is_in_fixed_move: bool = false
var fixed_move_velocity: Vector2 = Vector2.ZERO


func _ready():
	# --- Setup Timers ---
	add_child(double_tap_timer)
	double_tap_timer.one_shot = true
	double_tap_timer.wait_time = double_tap_time_threshold
	landing_lag_timer.wait_time = movement.landing_lag_duration

	# --- Setup Input Map ---
	inputs = {
		"left": "p%d_left" % player_id, "right": "p%d_right" % player_id,
		"down": "p%d_down" % player_id, "jump": "p%d_jump" % player_id,
		"sprint": "p%d_sprint" % player_id,
		"attack1": "p%d_attack1" % player_id, "attack2": "p%d_attack2" % player_id,
		"skill1": "p%d_skill1" % player_id, "skill2": "p%d_skill2" % player_id,
		"skill3": "p%d_skill3" % player_id, "skill4": "p%d_skill4" % player_id,
		"skill5": "p%d_skill5" % player_id, "skill6": "p%d_skill6" % player_id,
		"skill7": "p%d_skill7" % player_id, "skill8": "p%d_skill8" % player_id,
		"skill_bar_switch": "p%d_skill_bar_switch" % player_id,
	}
	
	# --- Initialize Components & Connect Signals ---
	attack_handler.initialize(self, stats, animated_sprite, player_id)
	
	stats.died.connect(_die)
	attack_handler.attack_initiated.connect(_on_attack_initiated)
	attack_handler.attack_ended.connect(_on_attack_ended)
	attack_handler.attack_lag_started.connect(_on_attack_lag_started)
	attack_handler.hit_target.connect(start_hitlag)
	animated_sprite.animation_finished.connect(_on_animation_finished)

func _physics_process(delta: float):
	# Early exit for uninterruptible states
	if current_state in [State.HITLAG, State.DEAD]:
		if current_state == State.HITLAG: move_and_slide()
		return

	# --- 1. GATHER INPUTS & UPDATE FLAGS ---
	var direction = Input.get_axis(inputs.left, inputs.right)
	handle_all_inputs(direction)
	update_invincibility()
	
	# --- 2. UPDATE STATE MACHINE ---
	update_state(direction)
	
	# --- 3. CALCULATE VELOCITY ---
	apply_gravity(delta)
	apply_movement(delta, direction)
	
	# --- 4. MOVE ---
	move_and_slide()
	
	# --- 5. POST-MOVE UPDATES ---
	if was_airborne and is_on_floor(): handle_landing()
	was_airborne = not is_on_floor()
	update_active_hitboxes()
	update_animation_and_flip(direction)

#region ======================== INPUT & STATE ========================
func handle_all_inputs(direction: float):
	if current_state in [State.ATTACK_LAG, State.LANDING_LAG, State.HURT, State.FREE_FALL, State.SLIDE]: return
	
	handle_sprint_input(direction)
	handle_attack_inputs()
	handle_jumping_input()

func handle_sprint_input(direction: float):
	# Conditions to stop sprinting
	if not is_on_floor() or direction == 0:
		is_sprinting = false
		double_tap_sprint_enabled = false
		return

	# 1. Check for dedicated sprint button (highest priority)
	if Input.is_action_pressed(inputs.sprint):
		is_sprinting = true
		double_tap_sprint_enabled = false # Button press overrides double-tap state
		return

	# 2. Handle double-tap logic if sprint button is not held
	var current_dir_sign = sign(direction)
	
	# Reset double-tap sprint if direction changes
	if last_tap_dir != 0 and current_dir_sign != last_tap_dir:
		double_tap_sprint_enabled = false

	if Input.is_action_just_pressed(inputs.left) or Input.is_action_just_pressed(inputs.right):
		if not double_tap_timer.is_stopped() and last_tap_dir == current_dir_sign:
			double_tap_sprint_enabled = true
			double_tap_timer.stop()
		else:
			last_tap_dir = current_dir_sign
			double_tap_timer.start()
			double_tap_sprint_enabled = false

	is_sprinting = double_tap_sprint_enabled

func handle_attack_inputs():
	if current_state == State.ATTACK:
		attack_handler.check_for_buffered_attack()
	
	for key in inputs:
		if not (key.begins_with("attack") or key.begins_with("skill")): continue
		
		var action_name = inputs[key]
		if Input.is_action_just_pressed(action_name):
			attack_handler.handle_attack_input(action_name)
			break

func handle_jumping_input():
	if Input.is_action_just_pressed(inputs.jump):
		jump_input_buffered = true
		jump_buffer_timer.start()

	if not jump_input_buffered: return
	if current_state in [State.ATTACK_LAG, State.LANDING_LAG, State.CROUCH, State.HURT, State.FREE_FALL, State.SLIDE]: return
	if jump_count >= movement.max_jumps: return
	
	var can_cancel_attack = false
	if current_state == State.ATTACK and attack_handler.current_attack:
		if animated_sprite.frame >= attack_handler.current_attack.cancel_frame:
			can_cancel_attack = true
	
	if current_state != State.ATTACK or can_cancel_attack:
		jump_input_buffered = false
		jump_buffer_timer.stop()
		velocity.y = movement.jump_velocity
		current_state = State.AERIAL
		jump_count += 1
		# REMOVED animation call from here. It will be handled by update_animation_and_flip.

func update_state(direction: float):
	# MODIFIED: Added State.AERIAL to prevent state override on the same frame as a jump.
	if current_state in [State.AERIAL, State.ATTACK, State.ATTACK_LAG, State.LANDING_LAG, State.HURT, State.FREE_FALL, State.SLIDE]: return
	
	if is_on_floor():
		if is_sprinting and Input.is_action_just_pressed(inputs.down):
			current_state = State.SLIDE
		elif Input.is_action_pressed(inputs.down) and direction == 0:
			current_state = State.CROUCH
		elif direction != 0:
			current_state = State.MOVE
		else:
			current_state = State.IDLE
	else:
		# This case is now mostly for falling off a ledge.
		current_state = State.AERIAL
#endregion

#region ======================== MOVEMENT & PHYSICS ========================
func apply_gravity(delta: float):
	if not is_on_floor():
		var can_ff = current_state not in [State.ATTACK_LAG, State.LANDING_LAG, State.ATTACK, State.HURT]
		var gravity_vec = movement.get_gravity_vector(velocity, Input.is_action_pressed(inputs.jump), Input.is_action_pressed(inputs.down), can_ff)
		velocity += gravity_vec * delta
		
func apply_movement(delta: float, direction: float):
	match current_state:
		State.IDLE:
			velocity = movement.get_ground_velocity(velocity, 0, false, delta)
		State.MOVE:
			velocity = movement.get_ground_velocity(velocity, direction, is_sprinting, delta)
		State.CROUCH:
			velocity = movement.get_ground_velocity(velocity, 0, false, delta)
		State.AERIAL, State.FREE_FALL:
			velocity = movement.get_air_velocity(velocity, direction, delta)
		State.ATTACK:
			handle_attack_movement(delta, direction)
		State.ATTACK_LAG, State.HURT, State.LANDING_LAG, State.SLIDE:
			velocity.x = move_toward(velocity.x, 0, movement.ground_friction * delta * 0.5)

func handle_attack_movement(delta: float, direction: float):
	var attack = attack_handler.current_attack
	if not attack: return
	var frame = animated_sprite.frame
	
	if is_in_fixed_move:
		velocity = fixed_move_velocity
		return
	elif attack.movement_type == "Fixed Distance" and frame >= attack.move_start_frame:
		is_in_fixed_move = true
		var dist = attack.move_distance
		dist.x *= -1 if animated_sprite.flip_h else 1
		fixed_move_velocity = dist / attack.move_duration
		fixed_move_timer.wait_time = attack.move_duration
		fixed_move_timer.start()
		velocity = fixed_move_velocity
		return
	
	if attack.movement_type == "Apply Velocity" and frame == attack.applied_velocity_frame:
		var vel_to_add = attack.applied_velocity
		vel_to_add.x *= -1 if animated_sprite.flip_h else 1
		velocity += vel_to_add

	if not is_on_floor():
		velocity = movement.get_air_velocity(velocity, direction, delta)
	else:
		velocity.x = move_toward(velocity.x, 0, movement.ground_friction * delta * 0.2)
#endregion

#region ======================== ACTIONS & REACTIONS ========================
func check_required_state(req_string: String) -> bool:
	if req_string.is_empty(): return true
	for condition in req_string.split("&", false):
		match condition.strip_edges():
			"Grounded": if not is_on_floor(): return false
			"Aerial": if is_on_floor(): return false
			"Sprint": if not is_sprinting: return false
	return true

func handle_landing():
	if current_state in [State.AERIAL, State.ATTACK, State.HURT, State.FREE_FALL]:
		attack_handler.on_land()
		jump_count = 0
		current_state = State.LANDING_LAG
		landing_lag_timer.start()

func take_damage(hitbox: HitboxData, attacker: Node2D):
	if current_state in [State.HURT, State.DEAD] or is_invincible: return
	stats.take_damage(hitbox.damage)
	
	var knockback_dir = hitbox.knockback_direction.normalized()
	if attacker.global_position.x > self.global_position.x: knockback_dir.x *= -1.0
	
	velocity = knockback_dir * hitbox.knockback_amount
	is_in_fixed_move = false
	fixed_move_timer.stop()
	attack_handler.on_hurt()
	
	current_state = State.HURT
	animated_sprite.play(animation_handler.hurt)
	hurt_timer.wait_time = hitbox.stun_duration
	hurt_timer.start()
	
func start_hitlag(duration: float):
	if duration > 0:
		current_state = State.HITLAG
		hitlag_timer.wait_time = duration
		hitlag_timer.start()
		animated_sprite.speed_scale = 0

func _die():
	current_state = State.DEAD
	animated_sprite.play(animation_handler.death)
	set_physics_process(false)
#endregion

#region ======================== VISUALS & HITBOXES ========================
func update_invincibility():
	var should_be_invincible = false
	if current_state == State.ATTACK and attack_handler.current_attack:
		var attack = attack_handler.current_attack
		if attack.invincibility_start_frame >= 0 and attack.invincibility_end_frame >= 0:
			var frame = animated_sprite.frame
			if frame >= attack.invincibility_start_frame and frame < attack.invincibility_end_frame:
				should_be_invincible = true
	
	if should_be_invincible != is_invincible:
		is_invincible = should_be_invincible
		hurtbox.set_deferred("monitorable", not is_invincible)
		animated_sprite.modulate.a = 0.6 if is_invincible else 1.0

func update_animation_and_flip(direction: float):
	if direction != 0:
		var attack = attack_handler.current_attack
		var can_turn = not (current_state == State.ATTACK and attack and not attack.can_turn_around)
		if can_turn:
			var is_flipped = direction < 0
			animated_sprite.flip_h = is_flipped
			hitbox_area.scale.x = -1 if is_flipped else 1

	if current_state in [State.ATTACK, State.ATTACK_LAG, State.HURT, State.HITLAG, State.DEAD]: return

	var anim_to_play: StringName
	match current_state:
		State.IDLE: anim_to_play = animation_handler.idle
		State.MOVE: anim_to_play = animation_handler.run if is_sprinting else animation_handler.walk
		State.CROUCH: anim_to_play = animation_handler.crouch_idle
		# MODIFIED: Reworked aerial animation logic
		State.AERIAL, State.FREE_FALL:
			var current_anim = animated_sprite.animation
			var valid_aerial_anims = [animation_handler.jump_start, animation_handler.sprint_jump_start, animation_handler.fall]
			
			# If we are in the air but not playing an aerial animation, it means we just jumped.
			if not current_anim in valid_aerial_anims:
				anim_to_play = animation_handler.sprint_jump_start if is_sprinting else animation_handler.jump_start
			# If we are playing a jump animation and start falling, switch to the fall animation.
			elif velocity.y > 0 and current_anim != animation_handler.fall:
				anim_to_play = animation_handler.fall
		State.LANDING_LAG: anim_to_play = animation_handler.land
		State.SLIDE: anim_to_play = animation_handler.running_slide
			
	if anim_to_play and animated_sprite.animation != anim_to_play:
		animated_sprite.play(anim_to_play)

func clear_active_hitboxes():
	for child in hitbox_area.get_children(): child.queue_free()

func update_active_hitboxes():
	clear_active_hitboxes()
	if current_state != State.ATTACK: return
	
	var attack = attack_handler.current_attack
	if not attack: return
	
	var frame = animated_sprite.frame
	for hitbox_data in attack.hitboxes:
		if frame >= hitbox_data.start_frame and frame < hitbox_data.end_frame:
			var shape_node = CollisionShape2D.new()
			shape_node.shape = hitbox_data.shape.duplicate()
			shape_node.position = hitbox_data.position
			hitbox_area.add_child(shape_node)
#endregion

#region ======================== SIGNAL CALLBACKS ========================
func _on_hurtbox_area_entered(area: Area2D):
	if not area.is_in_group("hitbox"): return
	var attacker: Node = area.get_owner()
	if attacker == self or not attacker is Player: return
	
	var attack: Attack = attacker.attack_handler.current_attack
	if not attack: return
	
	if attacker.attack_handler.hit_targets_this_attack.has(self): return
	attacker.attack_handler.hit_targets_this_attack.append(self)
	
	var hitbox_to_apply = attack.hitboxes[0] if not attack.hitboxes.is_empty() else null
	if not hitbox_to_apply: return
	
	attacker.attack_handler.on_hit_target(hitbox_to_apply)
	take_damage(hitbox_to_apply, attacker)

func _on_animation_finished():
	var anim_name = animated_sprite.animation
	
	attack_handler.on_animation_finished(anim_name)

	if attack_handler.current_attack and anim_name == attack_handler.current_attack.animation_name:
		if not is_on_floor() and attack_handler.current_attack.enter_free_fall:
			current_state = State.FREE_FALL
			return

	# This logic is now handled correctly by the AERIAL state in update_animation_and_flip
	# The check for anim_name against jump_start/sprint_jump_start is no longer needed here.
	
	if anim_name == animation_handler.running_slide:
		_on_attack_ended()
	elif anim_name == animation_handler.death:
		pass

func _on_attack_initiated(attack_data: Attack):
	is_in_fixed_move = false
	current_state = State.ATTACK
	animated_sprite.play(attack_data.animation_name)

func _on_attack_ended():
	if current_state not in [State.HURT, State.HITLAG, State.DEAD]:
		current_state = State.IDLE if is_on_floor() else State.AERIAL

func _on_attack_lag_started(duration: float):
	current_state = State.ATTACK_LAG
	attack_lag_timer.wait_time = duration
	attack_lag_timer.start()

func _on_attack_lag_timer_timeout(): _on_attack_ended()

func _on_hitlag_timer_timeout():
	current_state = State.ATTACK if attack_handler.current_attack else (State.IDLE if is_on_floor() else State.AERIAL)
	animated_sprite.speed_scale = 1.0

func _on_hurt_timer_timeout(): _on_attack_ended()

func _on_landing_lag_timer_timeout():
	if current_state == State.LANDING_LAG: current_state = State.IDLE

func _on_jump_buffer_timer_timeout(): jump_input_buffered = false

func _on_fixed_move_timer_timeout():
	is_in_fixed_move = false
	if is_on_floor(): velocity = Vector2.ZERO
#endregion