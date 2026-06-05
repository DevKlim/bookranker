class_name CoreModsHUD extends Control

var disks: Array[Control] = []
var container: VBoxContainer
var last_slots: Array = []

func _ready() -> void:
	set_anchors_preset(Control.PRESET_LEFT_WIDE)
	custom_minimum_size = Vector2(256, 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	container = VBoxContainer.new()
	container.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_theme_constant_override("separation", -120) # Overlap the larger disks heavily
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(container)
	
	call_deferred("_setup_connection")

func _setup_connection() -> void:
	var core = get_tree().get_first_node_in_group("core")
	if core and core.has_node("ModInventory"):
		var inv = core.get_node("ModInventory")
		inv.inventory_changed.connect(_on_inventory_changed)
		_on_inventory_changed()

func _on_inventory_changed() -> void:
	var core = get_tree().get_first_node_in_group("core")
	if not core: return
	var inv = core.get_node_or_null("ModInventory")
	if not inv: return
	
	var current_items = []
	for slot in inv.slots:
		if slot and slot.item:
			current_items.append(slot.item)
			
	if current_items == last_slots: return
	last_slots = current_items
	
	for c in container.get_children():
		c.queue_free()
	
	disks.clear()
	for item in current_items:
		_add_disk(item)

func _add_disk(item: ItemResource) -> void:
	var disk_control = Control.new()
	disk_control.custom_minimum_size = Vector2(256, 256)
	disk_control.mouse_filter = Control.MOUSE_FILTER_PASS
	disk_control.set_meta("is_popped_out", false)
	
	var disk_wrapper = Control.new()
	disk_wrapper.set_anchors_preset(Control.PRESET_FULL_RECT)
	disk_wrapper.position.x = -180 # Mostly obscured to the left
	disk_wrapper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disk_control.add_child(disk_wrapper)
	
	var svc = SubViewportContainer.new()
	svc.set_anchors_preset(Control.PRESET_FULL_RECT)
	svc.stretch = true
	svc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disk_wrapper.add_child(svc)
	
	var vp = SubViewport.new()
	vp.size = Vector2i(256, 256) # Larger, high-res render target for the disk
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	svc.add_child(vp)
	
	var cam = Camera3D.new()
	cam.position = Vector3(0, 1.8, 0)
	cam.rotation_degrees = Vector3(-90, 0, 0) # Look straight down onto the disk
	vp.add_child(cam)
	
	var disk_node = Node3D.new()
	vp.add_child(disk_node)
	
	# Disk Top (Cover Art embedded in Metal)
	var top_mesh = MeshInstance3D.new()
	var top_quad = QuadMesh.new()
	top_quad.size = Vector2(2, 2)
	top_mesh.mesh = top_quad
	top_mesh.rotation_degrees.x = -90
	top_mesh.position.y = 0.01
	
	var top_mat = ShaderMaterial.new()
	top_mat.shader = _get_cd_shader()
	top_mat.set_shader_parameter("is_top", true)
	if item.icon:
		top_mat.set_shader_parameter("cover_tex", item.icon)
	top_mesh.material_override = top_mat
	disk_node.add_child(top_mesh)
	
	# Disk Bottom (Iridescent Metal)
	var bottom_mesh = MeshInstance3D.new()
	var bottom_quad = QuadMesh.new()
	bottom_quad.size = Vector2(2, 2)
	bottom_mesh.mesh = bottom_quad
	bottom_mesh.rotation_degrees.x = 90
	bottom_mesh.position.y = -0.01
	
	var bottom_mat = ShaderMaterial.new()
	bottom_mat.shader = _get_cd_shader()
	bottom_mat.set_shader_parameter("is_top", false)
	bottom_mesh.material_override = bottom_mat
	disk_node.add_child(bottom_mesh)
	
	# Rotation animation
	var script = GDScript.new()
	script.source_code = """
extends Node3D
var speed = 2.0
func _process(delta):
	rotation.y += speed * delta
"""
	script.reload()
	disk_node.set_script(script)
	disk_node.set_process(true)
	
	disk_control.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var is_popped_out = disk_control.get_meta("is_popped_out")
			var new_state = not is_popped_out
			disk_control.set_meta("is_popped_out", new_state)
			
			var tween = disk_control.create_tween()
			if new_state:
				tween.tween_property(disk_wrapper, "position:x", 10.0, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
				disk_node.set("speed", 0.4)
				disk_control.move_to_front()
			else:
				tween.tween_property(disk_wrapper, "position:x", -180.0, 0.4).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
				disk_node.set("speed", 2.0)
	)
	
	var tt = load("res://scripts/ui/custom_tooltip.gd")
	if tt:
		disk_control.set_meta("tooltip_res", item)
		disk_control.tooltip_text = " "
		var tooltip_script = GDScript.new()
		tooltip_script.source_code = """
extends Control
func _make_custom_tooltip(for_text: String) -> Object:
	var res = get_meta("tooltip_res")
	if res:
		var tt = load("res://scripts/ui/custom_tooltip.gd")
		if tt: return tt.new(res)
	return null
"""
		tooltip_script.reload()
		disk_control.set_script(tooltip_script)
		
	if item.modifiers.get("permanent", false):
		var trojan_icon = TextureRect.new()
		var t_tex = load("res://assets/icons/trojan.png")
		if t_tex:
			trojan_icon.texture = t_tex
		trojan_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		trojan_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		trojan_icon.custom_minimum_size = Vector2(48, 48)
		trojan_icon.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		trojan_icon.position = Vector2(-56, -56)
		trojan_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		disk_wrapper.add_child(trojan_icon)
		
	container.add_child(disk_control)

func _get_cd_shader() -> Shader:
	var shader = Shader.new()
	shader.code = """
shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled;
uniform sampler2D cover_tex : filter_nearest;
uniform bool is_top = false;

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float d = length(uv);
	
	// Cut out the CD shape (hole and outer edge)
	if (d > 1.0 || d < 0.15) {
		discard;
	}
	
	// Angle for anisotropic / iridescent effects
	float angle = atan(uv.y, uv.x);
	
	// Base silver metallic
	vec3 metal = vec3(0.8, 0.85, 0.9);
	
	// Iridescent reflection (Y2K CD rainbow mapping)
	vec3 rainbow = 0.5 + 0.5 * cos(TIME * 0.5 + angle * 3.0 + d * 20.0 + vec3(0.0, 2.0, 4.0));
	vec3 base_color = mix(metal, rainbow, 0.4);
	
	// Add a specular swipe across the metal
	float spec = pow(sin(angle * 2.0 + TIME * 1.5) * 0.5 + 0.5, 8.0);
	base_color += vec3(spec * 0.6);
	
	if (d < 0.25) {
		// Inner transparent/plastic ring
		ALBEDO = base_color * vec3(0.7, 0.8, 0.9);
	} else {
		if (is_top) {
			vec4 tex = texture(cover_tex, UV);
			// Treat texture as a sticker/label printed on the metal disk
			// We let 10% of the metal sheen pass through the sticker
			vec3 final_top = mix(base_color, tex.rgb, tex.a * 0.9);
			ALBEDO = final_top + vec3(spec * 0.3); // specular gloss resting on top
		} else {
			ALBEDO = base_color;
		}
	}
	
	// Smooth outer edge antialiasing via Alpha
	float alpha = smoothstep(1.0, 0.98, d) * smoothstep(0.15, 0.17, d);
	ALPHA = alpha;
}
"""
	return shader
