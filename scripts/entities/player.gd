class_name Player
extends Ally

@onready var visuals: Node3D = $Visuals

# Constants
const PLAYER_HEIGHT_OFFSET: float = 1.0

# Movement State
var target_pos: Vector3
var is_moving: bool = false
var _is_mouse_movement: bool = false

func _ready() -> void:
	PlayerManager.player_entity = self
	PlayerManager.player_selection_changed.connect(_on_selection_changed)
	
	# Note: We do NOT override inventory_component here. 
	# The Player Entity keeps its own local 'ally_player_inventory' (inherited from Ally)
	# which serves as Equipment Slots (Tool, Armor, etc).
	# The Global Backpack is managed by PlayerManager.game_inventory.
	
	# Ensure we have the player stats resource loaded for Ally configuration
	if not stats:
		if ResourceLoader.exists("res://resources/allies/player.tres"):
			stats = load("res://resources/allies/player.tres")
	
	# Call super (Ally) ready to setup generic components and apply stats
	super._ready()
	
	# Add to specific player group
	add_to_group("player")
	
	# Update selection ring/arrow color to indicate Player (Green)
	if selection_container:
		var rings = selection_container.find_children("", "MeshInstance3D", true)
		for ring in rings:
			if ring.material_override:
				ring.material_override.albedo_color = Color(0.0, 1.0, 0.0, 0.8)
	
	# Player Picking Layer
	collision_layer = 4 
	collision_mask = 0  
	
	# Snap to Grid + Height Offset
	var tile = LaneManager.world_to_tile(global_position)
	var world_base = LaneManager.tile_to_world(tile)
	global_position = Vector3(world_base.x, world_base.y + PLAYER_HEIGHT_OFFSET, world_base.z)
	target_pos = global_position
	
	if move_component:
		move_component.target_position = target_pos

# Override receive_item to send picked-up items to the Global Backpack (Game Inventory)
# instead of the limited local equipment slots.
func receive_item(item: Resource, from_node: Node3D = null, extra_data: Dictionary = {}) -> bool:
	if PlayerManager.game_inventory:
		var remainder = PlayerManager.game_inventory.add_item(item)
		return remainder == 0
	return false

func command_move(dest: Vector3) -> void:
	# Ensure destination is at correct height
	dest.y = global_position.y
	target_pos = dest
	if move_component:
		move_component.target_position = target_pos
	is_moving = true
	_is_mouse_movement = true
	
	# Orient visuals immediately
	visuals.look_at(target_pos, Vector3.UP)
	visuals.rotation.x = 0
	visuals.rotation.z = 0

func _on_selection_changed(is_selected: bool) -> void:
	# Utilize base Ally logic to show ring and arrow
	set_selected(is_selected)

func _physics_process(_delta: float) -> void:
	# Check distance to finish move flag (physics move handled by MoveComponent)
	if is_moving:
		var dist = global_position.distance_to(target_pos)
		var threshold = 0.1
		
		if dist < threshold:
			global_position = target_pos
			is_moving = false
			_is_mouse_movement = false
