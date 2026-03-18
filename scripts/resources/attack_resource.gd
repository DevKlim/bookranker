class_name AttackResource
extends Resource

@export_group("General")
@export var id: String = "basic_attack"
@export var cooldown: float = 1.0
@export var animation_name: String = "attack"

@export_group("Damage & Scaling")
@export var base_damage: float = 10.0
## The stat name on the source entity to scale off (e.g. "attack_damage", "lux_stat").
@export var scaling_stat: String = "attack_damage"
@export var scaling_factor: float = 1.0

@export_group("Elemental")
@export var element: ElementResource
@export var element_units: int = 1
@export var ignore_element_cd: bool = false

@export_group("Range & Area")
## Minimum distance in tiles.
@export var min_range: int = 0
## Maximum distance in tiles.
@export var max_range: int = 1
## Width in lanes (0 = same lane, 1 = 3 lanes total).
@export var range_width: int = 0
## If true, hits all entities in the target tile(s).
@export var is_aoe: bool = false
## If aoe is false and this is set, does a physics overlap check instead of grid
@export var hitbox_extents: Vector3 = Vector3.ZERO

@export_group("Visuals")
@export var spawn_projectile: bool = false
@export var projectile_scene: PackedScene
@export var projectile_texture: Texture2D
@export var projectile_speed: float = 10.0
@export var projectile_color: Color = Color.WHITE

## Scene to spawn at the attacker/target location (e.g. Swing effect, Particle burst)
@export var visual_scene: PackedScene
## Where to spawn the visual: 0 = Attacker, 1 = Target, 2 = Midpoint
@export_enum("Attacker", "Target", "Midpoint") var visual_spawn_point: int = 0
## If true, the visual becomes a child of the spawn target (moves with them).
@export var attach_visual_to_source: bool = false
@export var visual_offset: Vector3 = Vector3(0, 0.5, 0)
@export var visual_duration: float = 0.5

@export_group("Chaining")
## The next attack to trigger automatically after this one.
@export var chain_next: AttackResource
@export var chain_delay: float = 0.5
