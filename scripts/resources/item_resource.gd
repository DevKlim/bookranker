class_name ItemResource
extends Resource

enum EquipmentType { NONE, TOOL, WEAPON, ARMOR, ACCESSORY, MOD }

@export var item_name: String = "New Item"
@export var icon: Texture2D
@export var color: Color = Color.WHITE
@export var stack_size: int = 50
@export var is_projectile: bool = false
@export var equipment_type: EquipmentType = EquipmentType.NONE

@export_group("Mod Specs")
@export var mod_type: String = ""

@export_group("Combat Specs")
## If this is a weapon, this resource defines its attack behavior.
@export var attack_config: AttackResource
@export var damage: float = 0.0
@export var projectile_scene: PackedScene
@export var element: ElementResource
## The strength/quantity of the element applied.
@export var element_units: int = 1 
## If true, this item ignores the target's internal elemental cooldown.
@export var ignore_element_cooldown: bool = false
@export var modifiers: Dictionary = {}

@export_group("Ore Details")
@export var is_ore: bool = false
@export var ore_block_name: String = ""

@export_group("Tool Specs")
@export var is_tool: bool = false
@export_enum("none", "drill", "wrench") var tool_type: String = "none"
@export var action_time: float = 1.0
## Visual offset for the grid cursor when this tool is equipped.
@export var highlight_offset: Vector3 = Vector3(0, 0, 0)

func get_artifact_instance() -> Variant:
	if has_meta("artifact_instance"):
		return get_meta("artifact_instance")
	
	var id = resource_path.get_file().get_basename()
	var path = "res://scripts/artifacts/" + id + ".gd"
	if ResourceLoader.exists(path):
		var script = load(path)
		if script and script is Script:
			var inst = script.new()
			set_meta("artifact_instance", inst)
			return inst
	
	set_meta("artifact_instance", null)
	return null

