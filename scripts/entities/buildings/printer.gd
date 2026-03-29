class_name PrinterBuilding
extends BaseBuilding

var _print_timer: float = 0.0
const PRINT_TIME = 5.0
var paper_res: ItemResource

func _ready() -> void:
	display_name = "Printer"
	super._ready()
	if Engine.is_editor_hint(): return
	
	paper_res = load("res://resources/items/paper.tres")

func get_slot_tooltip(idx: int) -> String:
	return "Paper Output"

func get_slot_label(idx: int) -> String:
	return "OUT"

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if Engine.is_editor_hint(): return
	if not is_active: return
	
	_print_timer += delta
	if _print_timer >= PRINT_TIME:
		_print_timer = 0.0
		if inventory_component and paper_res:
			if inventory_component.has_space_for(paper_res):
				inventory_component.add_item(paper_res, 1)

