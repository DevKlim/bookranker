class_name Player
extends Ally

@onready var visuals: Node3D = $Visual

# Constants
const PLAYER_HEIGHT_OFFSET: float = 1.0

# Movement State
var target_pos: Vector3
var is_moving: bool = false
var _is_mouse_movement: bool = false

func _ready() -> void:
	PlayerManager.player_entity = self
	PlayerManager.player_selection_changed.connect(_on_selection_changed)
	
	if ResourceLoader.exists("res://resources/allies/player.tres"):
		stats = ResourceLoader.load("res://resources/allies/player.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
		print("[DEBUG-PLAYER] Force loaded player.tres. Base speed is: ", stats.speed if stats else "NULL")
	
	super._ready()
	
	add_to_group("player")
	
	if selection_container:
		var rings = selection_container.find_children("", "MeshInstance3D", true)
		for ring in rings:
			if ring.material_override:
				ring.material_override.albedo_color = Color(0.0, 1.0, 0.0, 0.8)
	
	collision_layer = 4 
	collision_mask = 0  
	
	var tile = LaneManager.world_to_tile(global_position)
	var world_base = LaneManager.tile_to_world(tile)
	global_position = Vector3(world_base.x, world_base.y + PLAYER_HEIGHT_OFFSET, world_base.z)
	target_pos = global_position
	
	if move_component:
		move_component.target_position = target_pos

func receive_item(item: Resource, from_node: Node3D = null, extra_data: Dictionary = {}) -> bool:
	if PlayerManager.game_inventory:
		var remainder = PlayerManager.game_inventory.add_item(item)
		return remainder == 0
	return false

func command_move(dest: Vector3) -> void:
	dest.y = global_position.y
	target_pos = dest
	
	if move_component:
		move_component.move_to(target_pos)
		
	is_moving = true
	_is_mouse_movement = true
	
	if move_component and move_component.path.size() > move_component.current_path_index:
		var next_tile = move_component.path[move_component.current_path_index]
		var look_target = Vector3(next_tile.x, global_position.y, next_tile.z)
		
		if global_position.distance_squared_to(look_target) > 0.001:
			look_at(look_target, Vector3.UP)

func _on_selection_changed(is_selected: bool) -> void:
	set_selected(is_selected)

func _physics_process(_delta: float) -> void:
	if is_moving:
		var dist = global_position.distance_to(target_pos)
		var threshold = 0.1
		
		if dist < threshold:
			global_position = target_pos
			is_moving = false
			_is_mouse_movement = false
			