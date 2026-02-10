@tool
class_name BlockImporter
extends BaseImporter

const DEBUG_MESH_LIBRARY_PATH_RES = "res://resources/debug_mesh_library.tres"

func import_blocks(list: Array, lib_path: String) -> void:
	if not ResourceLoader.exists(lib_path): return
	var lib = load(lib_path)
	if not lib: return
	
	for entry in list:
		if not entry is Dictionary: continue
		var id = int(entry.get("id", -1))
		if id == -1: continue
		var b_name = str(entry.get("name", "Block"))
		var tex_base = str(entry.get("texture_base", ""))
		if tex_base != "":
			_create_mesh_item_in_library(lib, id, b_name, tex_base, Vector3(1, 1, 1), false)
	
	ResourceSaver.save(lib, lib_path)

func import_debug_blocks(list: Array) -> void:
	if not ResourceLoader.exists(DEBUG_MESH_LIBRARY_PATH_RES): return
	var lib = load(DEBUG_MESH_LIBRARY_PATH_RES)
	if not lib: return
	
	for entry in list:
		if not entry is Dictionary: continue
		var id = int(entry.get("id", -1))
		if id == -1: continue
		var b_name = str(entry.get("name", "DebugBlock"))
		var tex_base = str(entry.get("texture_base", ""))
		if tex_base != "":
			_create_mesh_item_in_library(lib, id, b_name, tex_base, Vector3(1, 1, 1), false)

	ResourceSaver.save(lib, DEBUG_MESH_LIBRARY_PATH_RES)

func _create_mesh_item_in_library(lib: MeshLibrary, id: int, block_name: String, base_path: String, size: Vector3, is_on: bool) -> void:
	var mesh = _create_advanced_block_mesh(base_path, size, is_on, false)
	var target_id = id
	var exists = false
	for ex_id in lib.get_item_list():
		if lib.get_item_name(ex_id) == block_name:
			target_id = ex_id
			exists = true
			break
	if not exists: lib.create_item(target_id)
	lib.set_item_name(target_id, block_name)
	lib.set_item_mesh(target_id, mesh)
	var shape = BoxShape3D.new()
	shape.size = size
	lib.set_item_shapes(target_id, [shape, Transform3D.IDENTITY])
