extends RefCounted

static func execute(target: Node, source: Node, ctx: Dictionary) -> void:
	var units = ctx.get("reaction_units", 1)
	
	var ec = target.get_node_or_null("ElementalComponent")
	if ec:
		ec.remove_status("abyss")
	
	if target.has_node("AbyssShell"):
		var existing = target.get_node("AbyssShell")
		# Prevent ElementManager double-triggering apply_direct and pop in the same frame
		if Engine.get_frames_drawn() == existing.get_meta("created_frame", -1):
			return
			
		existing.pop()
		return
		
	var shell = load("res://scripts/components/abyss_shell_component.gd").new()
	shell.name = "AbyssShell"
	shell.set_meta("created_frame", Engine.get_frames_drawn())
	target.add_child(shell)
	shell.setup(target, source, units)
	
	if target.is_inside_tree() and target.get_tree().root.has_node("GameManager"):
		var gm = target.get_tree().root.get_node("GameManager")
		if gm.get("vfx_manager"):
			gm.vfx_manager.play_vfx("abyss_start", target.global_position)

static func apply_direct(target: Node, source: Node, units: int) -> bool:
	execute(target, source, {"reaction_units": units})
	return true
