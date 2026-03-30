class_name FormulaHelper
extends RefCounted

static func evaluate(target: Object, equation: String, vars: Dictionary, default_val: float) -> float:
	if equation == "" or not is_instance_valid(target): return default_val
	
	var meta_key = "_expr_" + str(equation.hash())
	var meta_keys_key = meta_key + "_keys"
	
	if not target.has_meta(meta_key):
		var expr = Expression.new()
		var keys = PackedStringArray(vars.keys())
		var err = expr.parse(equation, keys)
		if err == OK:
			target.set_meta(meta_key, expr)
			target.set_meta(meta_keys_key, keys)
		else:
			printerr("Formula Parse Error: ", expr.get_error_text(), " | Eq: ", equation)
			target.set_meta(meta_key, null)
			target.set_meta(meta_keys_key, null)
			
	var expr = target.get_meta(meta_key)
	if expr != null and expr is Expression:
		var keys = target.get_meta(meta_keys_key)
		var vals =[]
		for k in keys:
			vals.append(vars.get(k, 0.0))
		var result = expr.execute(vals)
		if not expr.has_execute_failed():
			return float(result)
			
	return default_val
