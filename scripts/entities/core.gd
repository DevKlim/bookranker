extends StaticBody3D
class_name Core

@onready var health_component: HealthComponent = $HealthComponent
@onready var power_component: PowerProviderComponent = $PowerProviderComponent

var mod_inventory: Node

var beacon_mesh: MeshInstance3D
var boundary_mesh: MeshInstance3D
var beacon_mat: ShaderMaterial

var current_health_stage: int = 2 # 2 = Normal, 1 = 50%, 0 = 10%
var target_alpha: float = 1.0
var current_alpha: float = 1.0

func _ready() -> void:
	add_to_group("core")
	
	if health_component:
		health_component.health_changed.connect(_on_health_changed)
		health_component.died.connect(_on_died)

	mod_inventory = get_node_or_null("ModInventory")
	
	# Fallback: Safely inject the ModInventory component if missing from Main.tscn
	if not is_instance_valid(mod_inventory):
		var inv_script = load("res://scripts/components/inventory_component.gd")
		if inv_script:
			mod_inventory = inv_script.new()
			mod_inventory.name = "ModInventory"
			mod_inventory.set("max_slots", 3)
			add_child(mod_inventory)
		
	# Properly initialize the ModInventory slots and restrictions
	if is_instance_valid(mod_inventory):
		# FIX: Force unlocking of the inventory so the UI actually accepts Drag & Drop
		mod_inventory.set("can_receive", true)
		mod_inventory.set("can_output", true)
		
		if mod_inventory.get("max_slots") != 3:
			mod_inventory.set("max_slots", 3)
		
		# Guarantee capacity initialization (Avert 0-size arrays preventing UI loops)
		if mod_inventory.slots.size() != 3:
			if mod_inventory.has_method("set_capacity"):
				mod_inventory.set_capacity(3)
			else:
				mod_inventory.slots.resize(3)
		
		var ItemResClass = load("res://scripts/resources/item_resource.gd")
		if ItemResClass and "MOD" in ItemResClass.EquipmentType.keys():
			for i in range(mod_inventory.get("max_slots")): 
				if mod_inventory.has_method("set_slot_restriction"):
					mod_inventory.set_slot_restriction(i, ItemResClass.EquipmentType.MOD)
		
		mod_inventory.custom_filter = func(item):
			var t = item.get("mod_type")
			if not t or t == "":
				if "modifiers" in item and item.modifiers.has("type"): t = item.modifiers.get("type")
				elif "type" in item: t = item.get("type")
			return t == "core"

	# Fallback: Safely inject the ModHandlerComponent
	var mhand = get_node_or_null("ModHandlerComponent")
	if not is_instance_valid(mhand):
		var mhand_script = load("res://scripts/components/mod_handler_component.gd")
		if mhand_script:
			mhand = mhand_script.new()
			mhand.name = "ModHandlerComponent"
			add_child(mhand)
			
	if is_instance_valid(mhand) and is_instance_valid(mod_inventory):
		mhand.initialize(self, mod_inventory)

	# Register dynamic bounds
	if LaneManager.has_signal("lane_added"):
		LaneManager.lane_added.connect(func(_idx): call_deferred("_setup_visuals"))
		
	# Called deferred to ensure LaneManager has loaded num_lanes completely
	call_deferred("_setup_visuals")

func _setup_visuals() -> void:
	# Clean up only the boundary/beacons, NOT the StaticBody "Core" mesh itself
	var old_beacon = get_node_or_null("BeaconMesh")
	if old_beacon: old_beacon.queue_free()
	
	var old_bound = get_node_or_null("BoundaryMesh")
	if old_bound: old_bound.queue_free()
	
	# Determine perfectly centered Z based on min/max edges
	var middle_z = (LaneManager.max_lane + LaneManager.min_lane) * 0.5 * LaneManager.GRID_SCALE
	var bounds_width = max(LaneManager.num_lanes * LaneManager.GRID_SCALE, 50.0)
	
	# 1. Beacon of Light (Massive Core Pillar)
	beacon_mesh = MeshInstance3D.new()
	beacon_mesh.name = "BeaconMesh"
	var cyl = CylinderMesh.new()
	cyl.top_radius = middle_z - 3
	cyl.bottom_radius = middle_z
	cyl.height = 100.0
	beacon_mesh.mesh = cyl
	beacon_mesh.top_level = true 
	
	beacon_mat = ShaderMaterial.new()
	beacon_mat.shader = load("res://shaders/y2k_core_beacon.gdshader")
	var noise = load("res://assets/textures/noise/Techno/Techno_01-256x256.png")
	if noise: beacon_mat.set_shader_parameter("noise_tex", noise)
	beacon_mat.set_shader_parameter("core_color", Color(0.0, 1.0, 0.8, 1.0))
	beacon_mat.set_shader_parameter("damage_intensity", 0.0)
	beacon_mat.set_shader_parameter("alpha_multiplier", 1.0)
	beacon_mesh.material_override = beacon_mat
	
	add_child(beacon_mesh)
	beacon_mesh.global_position = Vector3(-20.0, 25.0, middle_z) 
	
	# 2. Tech Boundary Indicator at X=0
	boundary_mesh = MeshInstance3D.new()
	boundary_mesh.name = "BoundaryMesh"
	var plane = PlaneMesh.new()
	plane.size = Vector2(50.0, bounds_width * 4.0) # Extend far visually
	boundary_mesh.mesh = plane
	boundary_mesh.top_level = true
	
	var bound_mat = ShaderMaterial.new()
	bound_mat.shader = load("res://shaders/y2k_core_boundary.gdshader")
	bound_mat.set_shader_parameter("grid_color", Color(0.0, 0.5, 1.0, 0.3))
	boundary_mesh.material_override = bound_mat
	
	add_child(boundary_mesh)
	boundary_mesh.global_position = Vector3(-25.0, 1.01, middle_z) 

func _process(delta: float) -> void:
	if current_alpha != target_alpha:
		current_alpha = lerp(current_alpha, target_alpha, delta * 5.0)
		if beacon_mat:
			beacon_mat.set_shader_parameter("alpha_multiplier", current_alpha)

func set_transparent(is_transparent: bool) -> void:
	target_alpha = 0.15 if is_transparent else 1.0

func _on_health_changed(new_amount: float, max_amount: float) -> void:
	var pct = new_amount / max_amount
	var new_stage = 2
	if pct <= 0.1: new_stage = 0
	elif pct <= 0.5: new_stage = 1
	
	if beacon_mat:
		var intensity = 1.0 - pct
		beacon_mat.set_shader_parameter("damage_intensity", intensity)
		
		if new_stage == 0:
			beacon_mat.set_shader_parameter("core_color", Color(1.0, 0.0, 0.2, 1.0)) 
		elif new_stage == 1:
			beacon_mat.set_shader_parameter("core_color", Color(1.0, 0.6, 0.0, 1.0)) 
		else:
			beacon_mat.set_shader_parameter("core_color", Color(0.0, 1.0, 0.8, 1.0)) 
			
	if new_stage < current_health_stage:
		if is_instance_valid(GameManager) and GameManager.get("vfx_manager"):
			GameManager.vfx_manager.play_vfx("y2k_reaction", global_position)
			
	current_health_stage = new_stage

func _on_died(_node) -> void:
	if is_instance_valid(GameManager):
		GameManager.end_game(false)
