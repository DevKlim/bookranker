extends ModChip

var applied: bool = false

func _on_apply() -> void:
	print("[MOD-PATH-NOT-TAKEN] _on_apply triggered. Applied status: ", applied)
	if not applied:
		if is_instance_valid(GameManager) and GameManager.get("vfx_manager"):
			print("[MOD-PATH-NOT-TAKEN] Playing VFX.")
			# Swapped 'mod_install_cursed' for verified VFX to avoid the TorusMesh crash
			GameManager.vfx_manager.play_vfx("y2k_glitch", target.global_position)
			GameManager.vfx_manager.play_vfx("y2k_reaction", target.global_position)
			
		print("[MOD-PATH-NOT-TAKEN] Firing _animate_lane_addition().")
		_animate_lane_addition()
		applied = true

func _animate_lane_addition() -> void:
	print("[MOD-PATH-NOT-TAKEN] Modifying core limits. Adding positive lane (1).")
	LaneManager.add_lane(1)
	
	# Add second lane to negative side directly after the first cascading animation starts
	var t = get_tree().create_timer(1.2)
	t.timeout.connect(func():
		print("[MOD-PATH-NOT-TAKEN] Sequence continued. Adding negative lane (-1).")
		LaneManager.add_lane(-1)
	)
