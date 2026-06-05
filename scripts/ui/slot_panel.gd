extends Panel

func _make_custom_tooltip(for_text: String) -> Object:
	var res = get_meta("tooltip_res")
	if res:
		var tt = load("res://scripts/ui/custom_tooltip.gd")
		if tt: return tt.new(res)
	return null
	