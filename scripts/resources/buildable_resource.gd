class_name BuildableResource
extends Resource

## Defines a buildable item for the game, including its type, scene/tile data, and UI info.

enum BuildLayer {
	WIRING, # For items like dust and levers, placed on the Wiring TileMap
	MECH,   # For items like turrets and drills, placed as scenes
	TOOL,   # For non-placing tools like the remover
	ADDON   # For items placed on top of MECHs (e.g. Mystapus on Slipstream)
}

@export var buildable_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var layer: BuildLayer = BuildLayer.MECH

@export_group("Classification")
@export var rarity: String = "C"
@export var build_category: String = "Building"
@export var custom_tooltip_labels: Dictionary = {}

## Time in seconds before another building of this type can be placed
@export var build_cooldown: float = 0.0

@export_group("Stats")
## Maximum HP capacity.
@export var max_health: float = 100.0
## Gives a separate flat health bar that can regenerate. No defenses are applied to it.
@export var security: float = 0.0
@export var max_energy: float = 50.0
@export var power_consumption: float = 5.0
## Conveyor belt / transport stream speed.
@export var speed: float = 5.0
## Power grid drain divisor (2.0 = uses 50% power).
@export var compute: float = 1.0 
## Magic damage scaling for spells, reactions, and ticks & increase elemental-based production.
@export var networking: float = 0.0 
## Percentage chance to produce double outputs.
@export var luck_stat: float = 0.0
## Flat bonus/Multiplier to emitted projectiles (turrets/fans).
@export var attack_damage: float = 0.0
## Machine crafting/processing tick speed.
@export var process_speed: float = 1.0
## Armor rating (flat damage reduction).
@export var defense: float = 0.0
## Resistance to environmental/elemental damage.
@export var firewall: float = 0.0
## Environmental effects check (gimicky).
@export var space: float = 10.0
## Increase size of output.
@export var scale: float = 1.0
## Mult against CC duration.
@export var ping: float = 1.0
## Vulnerability (+10% extra damage taken).
@export var malware: float = 0.0

@export_group("Formulas")
@export var max_health_equation: String = ""
@export var security_equation: String = ""
@export var speed_equation: String = ""
@export var process_speed_equation: String = ""
@export var attack_damage_equation: String = ""
@export var defense_equation: String = ""
@export var firewall_equation: String = ""
@export var networking_equation: String = ""
@export var space_equation: String = ""
@export var luck_stat_equation: String = ""
@export var compute_equation: String = ""
@export var scale_equation: String = ""
@export var ping_equation: String = ""
@export var malware_equation: String = ""
@export var power_usage_equation: String = ""
@export var stat_weights: Dictionary = {}

@export_group("Dimensions")
@export var width: int = 1
@export var height: int = 1

@export_group("Functional Settings")
@export var has_input: bool = true
@export var has_output: bool = true

## Bitmasks for default allowed directions (relative to building facing).
## 1=Down(Back), 2=Left, 4=Up(Front), 8=Right (Using Godot Direction Enum logic: 1<<Val)
@export_flags("Down:1", "Left:2", "Up:4", "Right:8") var default_input_mask: int = 15 # Default All
@export_flags("Down:1", "Left:2", "Up:4", "Right:8") var default_output_mask: int = 15 # Default All

@export_group("Visual Settings")
## The visual offset from the tile center (snapped position) for this building.
@export var display_offset: Vector2 = Vector2.ZERO

## For MECH layer items
@export_group("Mech Settings")
@export var scene: PackedScene

## For WIRING layer items
@export_group("Wiring Settings")
@export var tile_source_id: int = 0
@export var tile_atlas_coords: Vector2i = Vector2i.ZERO
