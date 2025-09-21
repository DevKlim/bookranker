extends Node2D

@export var player_ui_scene: PackedScene
@export var skill_bar_scene: PackedScene

@onready var player1 = $Player1
@onready var player2 = $Player2
@onready var camera = $Camera2D

var p1_spawn_pos: Vector2
var p2_spawn_pos: Vector2

const MIN_ZOOM = 0.8
const MAX_ZOOM = 1.5
const ZOOM_MARGIN = 200
const CAMERA_SMOOTHING = 5.0

func _ready():
	var death_zones = get_tree().get_nodes_in_group("death_zone")
	for zone in death_zones:
		zone.body_entered.connect(_on_death_zone_body_entered)
		
	if is_instance_valid(player1):
		p1_spawn_pos = player1.global_position
		setup_player_interfaces(player1, $UI/P1_UI_Anchor, $UI/P1_SkillBar_Anchor)
	
	if is_instance_valid(player2):
		p2_spawn_pos = player2.global_position
		setup_player_interfaces(player2, $UI/P2_UI_Anchor, $UI/P2_SkillBar_Anchor)

func setup_player_interfaces(player_node: CharacterBody2D, ui_anchor: Control, skill_anchor: Control):
	if player_ui_scene:
		var player_ui = player_ui_scene.instantiate()
		ui_anchor.add_child(player_ui)
		player_ui.link_to_player(player_node)

	if skill_bar_scene:
		var skill_bar = skill_bar_scene.instantiate()
		skill_anchor.add_child(skill_bar)
		skill_bar.link_to_player(player_node)

func _process(delta):
	if not is_instance_valid(player1) or not is_instance_valid(player2):
		return
	handle_camera(delta)

func handle_camera(delta):
	var midpoint = player1.global_position.lerp(player2.global_position, 0.5)
	camera.global_position = camera.global_position.lerp(midpoint, delta * CAMERA_SMOOTHING)

	var screen_size = get_viewport().get_visible_rect().size / camera.zoom
	var distance_x = abs(player1.global_position.x - player2.global_position.x) + ZOOM_MARGIN
	var distance_y = abs(player1.global_position.y - player2.global_position.y) + ZOOM_MARGIN
	
	var zoom_x = screen_size.x / distance_x
	var zoom_y = screen_size.y / distance_y
	
	var target_zoom = min(zoom_x, zoom_y)
	target_zoom = clamp(target_zoom, MIN_ZOOM, MAX_ZOOM)
	camera.zoom = lerp(camera.zoom, Vector2(target_zoom, target_zoom), delta * CAMERA_SMOOTHING)

func _on_death_zone_body_entered(body):
	if body is CharacterBody2D and body.is_in_group("player"):
		var spawn_pos = p1_spawn_pos if body == player1 else p2_spawn_pos
		respawn_player(body, spawn_pos)

func respawn_player(player: CharacterBody2D, spawn_pos):
	player.global_position = spawn_pos
	player.velocity = Vector2.ZERO
	player.get_node("StatsComponent").reset()
	player.current_state = player.State.IDLE
