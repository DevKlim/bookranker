class_name DewArea
extends Area3D

var tile: Vector2i
var timer: float = 10.0
var source: Node

@onready var puddle_mesh: MeshInstance3D = $PuddleMesh
@onready var mist_particles: GPUParticles3D = $MistParticles

func setup(p_tile: Vector2i, duration: float, p_source: Node) -> void:
	tile = p_tile
	timer = 10.0
	source = p_source
	
	global_position = LaneManager.tile_to_world(tile)
	
	if puddle_mesh and puddle_mesh.mesh:
		var mat = puddle_mesh.mesh.surface_get_material(0)
		if mat:
			puddle_mesh.material_override = mat.duplicate()
			
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func refresh(duration: float) -> void:
	timer = 10.0

func _process(delta: float) -> void:
	timer -= delta
	
	if puddle_mesh and puddle_mesh.material_override:
		puddle_mesh.material_override.uv1_offset += Vector3(0.1, 0.1, 0) * delta
	
	if timer <= 0.5 and not is_queued_for_deletion():
		if puddle_mesh and puddle_mesh.material_override:
			var mat = puddle_mesh.material_override as StandardMaterial3D
			if mat.albedo_color.a > 0.0:
				mat.albedo_color.a -= delta * 2.0
		if mist_particles:
			mist_particles.emitting = false
			
	if timer <= 0:
		queue_free()

func _on_body_entered(body: Node3D) -> void:
	if body is Enemy or body.has_node("ElementalComponent"):
		var em = get_tree().root.get_node_or_null("ElementManager")
		if em:
			var dew_res = em.get_element("dew")
			if dew_res:
				var safe_source = source if is_instance_valid(source) else null
				em.apply_element(body, dew_res, safe_source, 0.0, 1, true)
