class_name AttackResource
extends Resource

@export_group("General")
@export var id: String = "basic_attack"
@export var cooldown: float = 1.0
@export var animation_name: String = "attack"

@export_group("Casting")
@export var cast_time: float = 0.0
@export var on_cast_scene: PackedScene

@export_group("Damage & Scaling")
@export var base_damage: float = 10.0
## The stat name on the source entity to scale off (e.g. "attack_damage", "lux_stat").
@export var scaling_stat: String = "attack_damage"
@export var scaling_factor: float = 1.0

@export_group("Formulas & Scaling")
@export var damage_equation: String = ""
@export var stat_weights: Dictionary = {}

@export_group("Elemental")
@export var element: ElementResource
@export var element_units: int = 1
@export var ignore_element_cd: bool = false

@export_group("Range & Area")
@export var min_range: int = 0
@export var max_range: int = 1
@export var range_width: int = 0
@export var is_aoe: bool = false
@export var custom_aoe_tiles: Array[Vector2i] =[]
@export var hitbox_extents: Vector3 = Vector3.ZERO
@export var hitbox_offset: Vector3 = Vector3.ZERO
## Orients the physical layout/hitbox to match the source's current 3D rotation
@export var orient_to_source_direction: bool = false

@export_group("Visuals")
@export var spawn_projectile: bool = false
@export var projectile_scene: PackedScene
@export var projectile_texture: Texture2D
@export var projectile_speed: float = 10.0
@export var projectile_lifetime: float = 0.0
@export var projectile_color: Color = Color.WHITE

@export var visual_scene: PackedScene
@export_enum("Attacker", "Target", "Midpoint") var visual_spawn_point: int = 0
@export var attach_visual_to_source: bool = false
@export var visual_offset: Vector3 = Vector3(0, 0.5, 0)
@export var visual_duration: float = 0.5

@export_group("Chaining")
@export var chain_next: AttackResource
@export var chain_delay: float = 0.5
