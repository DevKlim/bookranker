extends Node2D

@onready var player1 = $Player1
@onready var player2 = $Player2
@onready var camera = $Camera2D

# Store initial spawn positions
var p1_spawn_pos: Vector2
var p2_spawn_pos: Vector2

# Camera settings
const MIN_ZOOM = 0.8
const MAX_ZOOM = 1.5
const ZOOM_MARGIN = 200 # Extra space around players
const CAMERA_SMOOTHING = 5.0

func _ready():
	# Connect death zone signals for both players
	var death_zones = get_tree().get_nodes_in_group("death_zone")
	for zone in death_zones:
		zone.body_entered.connect(_on_death_zone_body_entered)
		
	# Store spawn positions
	p1_spawn_pos = player1.global_position
	p2_spawn_pos = player2.global_position

func _process(delta):
	handle_camera(delta)

func handle_camera(delta):
	# Calculate the midpoint between the players
	var midpoint = player1.global_position.lerp(player2.global_position, 0.5)
	
	# Smoothly move the camera to the midpoint
	camera.global_position = camera.global_position.lerp(midpoint, delta * CAMERA_SMOOTHING)

	# Calculate required zoom to keep both players on screen
	var screen_size = get_viewport().get_visible_rect().size / camera.zoom
	var distance_x = abs(player1.global_position.x - player2.global_position.x) + ZOOM_MARGIN
	var distance_y = abs(player1.global_position.y - player2.global_position.y) + ZOOM_MARGIN
	
	var zoom_x = screen_size.x / distance_x
	var zoom_y = screen_size.y / distance_y
	
	# Choose the smaller zoom level to ensure both are visible
	var target_zoom = min(zoom_x, zoom_y)
	
	# Clamp the zoom between min and max values
	target_zoom = clamp(target_zoom, MIN_ZOOM, MAX_ZOOM)
	
	# Smoothly apply the new zoom
	camera.zoom = lerp(camera.zoom, Vector2(target_zoom, target_zoom), delta * CAMERA_SMOOTHING)

func _on_death_zone_body_entered(body):
	# Check if the body that entered is a player
	if body is CharacterBody2D and (body == player1 or body == player2):
		# Respawn the player at their initial position
		if body == player1:
			body.global_position = p1_spawn_pos
		else:
			body.global_position = p2_spawn_pos
		# Reset their velocity
		body.velocity = Vector2.ZERO
