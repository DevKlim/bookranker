class_name Projectile
extends Area3D

@export var default_scale: Vector3 = Vector3(1.0, 1.0, 1.0)
@export var visual_offset: Vector3 = Vector3.ZERO

var _velocity: Vector3 = Vector3.ZERO
var _damage: float = 0.0
var _element: Resource = null
var lane_id: int = -1
var speed: float = 0.0
var lifetime: float = 5.0

@onready var sprite: Sprite3D = $Sprite3D

const OUTLINE_SHADER_CODE = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix; 
uniform sampler2D texture_albedo : source_color, filter_nearest;
uniform vec4 outline_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float width : hint_range(0.0, 10.0) = 1.0;
void fragment() {
	vec4 tex = texture(texture_albedo, UV);
	vec4 base_col = tex * COLOR; 
	vec2 size = vec2(textureSize(texture_albedo, 0));
	float px_x = width / size.x;
	float px_y = width / size.y;
	float a = texture(texture_albedo, UV + vec2(px_x, 0.0)).a;
	a += texture(texture_albedo, UV + vec2(-px_x, 0.0)).a;
	a += texture(texture_albedo, UV + vec2(0.0, px_y)).a;
	a += texture(texture_albedo, UV + vec2(0.0, -px_y)).a;
	if (base_col.a < 0.1 && a > 0.1) { ALBEDO = outline_color.rgb; ALPHA = 1.0; } 
	else { ALBEDO = base_col.rgb; ALPHA = base_col.a; if (base_col.a < 0.05) discard; }
}
"""

func _ready() -> void:
	collision_mask = 2 # Enemies
	collision_layer = 0
	
	if sprite:
		sprite.scale = default_scale
		sprite.position = visual_offset

func _physics_process(delta: float) -> void:
	if _velocity == Vector3.ZERO:
		lifetime -= delta
		if lifetime <= 0: queue_free()
		return

	position += _velocity * delta
	
	lifetime -= delta
	if lifetime <= 0:
		queue_free()

func initialize(start_pos: Vector3, dir: Vector3, p_speed: float, dmg: float, p_lane: int, p_elem: Resource = null, tex: Texture2D = null, col: Color = Color.WHITE, _use_path: bool = false, extra_params: Dictionary = {}) -> void:
	global_position = start_pos
	
	# Scale speed. ~600px/s -> 12m/s
	speed = p_speed * 0.02
	if speed < 2.0: speed = 10.0
	
	_velocity = dir.normalized() * speed
	
	print("Projectile Init: Pos %s | Vel %s | Dmg %s | Lane %d" % [str(start_pos), str(_velocity), str(dmg), p_lane])
	
	if dir != Vector3.ZERO:
		look_at(global_position + dir, Vector3.UP)
		
	_damage = dmg
	lane_id = p_lane
	_element = p_elem
	
	if sprite:
		sprite.position = visual_offset
		if tex: sprite.texture = tex
		
		if _element and "color" in _element:
			sprite.modulate = _element.color
		else:
			sprite.modulate = col
			
		var s = extra_params.get("scale", 1.0)
		if typeof(s) == TYPE_FLOAT or typeof(s) == TYPE_INT:
			sprite.scale = default_scale * float(s)

		var shader = Shader.new()
		shader.code = OUTLINE_SHADER_CODE
		var mat = ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("texture_albedo", tex)
		mat.resource_local_to_scene = true
		sprite.material_override = mat

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	# Debug print for any collision attempt
	print("Projectile Collision with: %s at %s" % [body.name, body.global_position])
	
	if not (body is CharacterBody3D): return

	var e_lane = -1
	if body.has_method("get_lane_id"):
		e_lane = body.get_lane_id()
	
	if self.lane_id == -1 or e_lane == self.lane_id or e_lane == -1:
		print(">> VALID HIT on %s! Applying %s damage." % [body.name, _damage])
		var hc = body.get_node_or_null("HealthComponent")
		if hc: 
			hc.take_damage(_damage, _element)
		elif body.has_method("take_damage"):
			body.take_damage(_damage)
		
		if _element: 
			ElementManager.apply_element(body, _element)
			
		queue_free()
	else:
		print(">> Lane Mismatch! Proj Lane: %d, Enemy Lane: %d" % [self.lane_id, e_lane])
