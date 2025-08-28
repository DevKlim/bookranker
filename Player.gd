extends CharacterBody2D

@export var player_id: int = 1

# Movement variables
const SPEED = 300.0
const FRICTION = 800.0 # How quickly the player stops
const JUMP_VELOCITY = -800.0
const KNOCKBACK_FORCE = 800.0

# Jump variables
const MAX_JUMPS = 2
var jump_count = 0

# References to nodes
@onready var sprite = $Sprite2D
@onready var hitbox = $Hitbox/CollisionShape2D
@onready var hitbox_timer = $Hitbox/Timer

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func _ready():
	# Differentiate players by color
	if player_id == 1:
		sprite.modulate = Color("4169e1") # Royal Blue
	else:
		sprite.modulate = Color("dc143c") # Crimson

	# Disable hitbox on start
	hitbox.disabled = true

func _physics_process(delta):
	# Add gravity.
	if not is_on_floor():
		velocity.y += gravity * delta
	else:
		# Reset jump count when on the floor
		jump_count = 0

	# Handle horizontal movement.
	var direction = Input.get_axis("p%d_left" % player_id, "p%d_right" % player_id)
	if direction:
		velocity.x = direction * SPEED
		sprite.flip_h = (direction < 0) # Flip sprite based on direction
	else:
		# Apply friction when no input is given
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)

	# Handle Jump.
	if Input.is_action_just_pressed("p%d_jump" % player_id):
		if jump_count < MAX_JUMPS:
			velocity.y = JUMP_VELOCITY
			jump_count += 1
			
	# Handle Attack
	if Input.is_action_just_pressed("p%d_attack" % player_id):
		attack()

	move_and_slide()

func attack():
	# Enable the hitbox for a short duration
	if hitbox.disabled:
		hitbox.disabled = false
		hitbox_timer.start()

func take_knockback(attacker_position):
	# Calculate knockback direction and apply it
	var knockback_direction = (global_position - attacker_position).normalized()
	velocity = knockback_direction * KNOCKBACK_FORCE
	# Add some upward force to the knockback
	velocity.y = -400.0
	
func _on_hitbox_timer_timeout():
	hitbox.disabled = true

func _on_hurtbox_area_entered(area):
	# Check if the area that entered is a hitbox and belongs to another player
	if area.is_in_group("hitbox") and area.get_parent().get_parent() != self:
		var attacker = area.get_parent().get_parent()
		take_knockback(attacker.global_position)