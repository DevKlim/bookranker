class_name Core
extends StaticBody3D

var health_component: HealthComponent
var power_provider: PowerProviderComponent
var mod_inventory: InventoryComponent
var mod_handler: ModHandlerComponent
var core_mesh: MeshInstance3D

func _ready() -> void:
	add_to_group("core")
	
	health_component = get_node_or_null("HealthComponent")
	power_provider = get_node_or_null("PowerProviderComponent")
	core_mesh = get_node_or_null("Core")
	
	# Core Mod Setup (Equivalent to buildings)
	mod_inventory = InventoryComponent.new()
	mod_inventory.name = "ModInventory"
	mod_inventory.max_slots = 3
	mod_inventory.set_capacity(3)
	
	var ItemResClass = load("res://scripts/resources/item_resource.gd")
	if ItemResClass and "MOD" in ItemResClass.EquipmentType.keys():
		for i in range(3):
			mod_inventory.set_slot_restriction(i, ItemResClass.EquipmentType.MOD)
			
	mod_inventory.custom_filter = func(item):
		var t = item.get("mod_type")
		if not t or t == "":
			if "modifiers" in item and item.modifiers.has("type"):
				t = item.modifiers.get("type")
			elif "type" in item:
				t = item.get("type")
		return t == "core"
		
	add_child(mod_inventory)
	
	mod_handler = ModHandlerComponent.new()
	mod_handler.name = "ModHandlerComponent"
	add_child(mod_handler)
	mod_handler.initialize(self, mod_inventory)

func set_transparent(is_transparent: bool) -> void:
	if is_instance_valid(core_mesh) and core_mesh.mesh:
		var mat = core_mesh.get_active_material(0)
		if not mat:
			mat = StandardMaterial3D.new()
			core_mesh.set_surface_override_material(0, mat)
			
		if mat is StandardMaterial3D:
			if is_transparent:
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mat.albedo_color.a = 0.5
			else:
				mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
				mat.albedo_color.a = 1.0
