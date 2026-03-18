class_name Projectile
extends Area3D

@export var default_scale: Vector3 = Vector3(0.5, 1.0, 0.5)
@export var visual_offset: Vector3 = Vector3(0, 0.0, 0) # Raise default Y

var _velocity: Vector3 = Vector3.ZERO
var _damage: float = 0.0
var _element: Resource = null
var _source_attacker: Node = null
var _attack_resource: AttackResource = null
var _element_units: int = 1
var _ignore_element_cd: bool = false
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
	collision_layer = 4 # Projectiles
	
	monitoring = true
	monitorable = true
	
	if sprite:
		sprite.scale = default_scale
		sprite.position = visual_offset

func _physics_process(delta: float) -> void:
	if _velocity == Vector3.ZERO:
		lifetime -= delta
		if lifetime <= 0: queue_free()
		return

	global_position += _velocity * delta
	lifetime -= delta
	if lifetime <= 0:
		queue_free()

func initialize(start_pos: Vector3, dir: Vector3, p_speed: float, dmg: float, p_lane: int, p_elem: Resource = null, tex: Texture2D = null, col: Color = Color.WHITE, _use_path: bool = false, extra_params: Dictionary = {}) -> void:
	global_position = start_pos
	
	speed = p_speed * 0.02
	if speed < 2.0: speed = 10.0
	
	_velocity = dir.normalized() * speed
	_damage = dmg
	lane_id = p_lane
	_element = p_elem
	_source_attacker = extra_params.get("source", null)
	_attack_resource = extra_params.get("attack_resource", null)
	
	# Parse explicit unit/CD data
	_element_units = extra_params.get("element_units", 1)
	_ignore_element_cd = extra_params.get("ignore_element_cd", false)
	
	if dir != Vector3.ZERO:
		look_at(global_position + dir, Vector3.UP)

	if sprite:
		sprite.position = visual_offset
		if tex: 
			sprite.texture = tex
			sprite.pixel_size = 0.04 # Make slightly bigger
			sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			sprite.axis = Vector3.AXIS_Y
		
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
		mat.set_shader_parameter("texture_albedo", tex)
		mat.resource_local_to_scene = true
		sprite.material_override = mat

	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	# Validate Target
	var valid_target = false
	if body is Enemy: valid_target = true
	if body.has_method("take_damage"): valid_target = true
	if body.has_node("HealthComponent"): valid_target = true
	
	if not valid_target: return

	var e_lane = -1
	if body.has_method("get_lane_id"):
		e_lane = body.get_lane_id()
	
	if self.lane_id == -1 or e_lane == self.lane_id or e_lane == -1:
		
		var handled = false
		if _attack_resource and is_instance_valid(_source_attacker) and _source_attacker.has_node("AttackerComponent"):
			# Delegate damage/AoE logic to the attacker component
			var attacker = _source_attacker.get_node("AttackerComponent")
			attacker.call("_apply_hit", body, global_position, _damage, _attack_resource, _source_attacker)
			handled = true
			
		if not handled:
			if _element:
				# Pass new unit and cooldown parameters to ElementManager
				ElementManager.apply_element(body, _element, _source_attacker, _damage, _element_units, _ignore_element_cd)
			
			if body.has_method("take_damage"):
				body.take_damage(_damage, _element, _source_attacker)
			elif body.has_node("HealthComponent"):
				body.get_node("HealthComponent").take_damage(_damage, _element, _source_attacker)
				
			# Hook for ElementManager Reactions (e.g. Ripple / Conduct)
			ElementManager.on_damage_dealt(body, _damage, _source_attacker)
		
		queue_free()
