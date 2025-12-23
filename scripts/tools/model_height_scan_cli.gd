extends SceneTree
class_name ModelHeightScannerCLI

@export var root_dir: String = "res://assets"
@export var output_path: String = "res://artifacts/model_heights.json"
@export var include_glb: bool = true
@export var include_gltf: bool = true
@export var include_tscn: bool = false
@export var print_summary: bool = true


func _init() -> void:
	call_deferred("_run_scan")


func _run_scan() -> void:
	var paths: Array[String] = _collect_paths(root_dir)
	paths.sort()
	var results: Array[Dictionary] = []
	for path in paths:
		var info: Dictionary = _scan_model(path)
		if info.is_empty():
			continue
		results.append(info)

	var payload := {
		"generated_at": Time.get_datetime_string_from_system(),
		"root_dir": root_dir,
		"count": results.size(),
		"models": results,
	}
	var json: String = JSON.stringify(payload, "\t")
	_write_text(output_path, json)
	if print_summary:
		print("Model height scan: %d models -> %s" % [results.size(), output_path])
	quit()


func _collect_paths(dir_path: String) -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("Model scan: directory not found: %s" % dir_path)
		return result
	var err: int = dir.list_dir_begin()
	if err != OK:
		push_warning("Model scan: failed to list dir: %s" % dir_path)
		return result
	while true:
		var name: String = dir.get_next()
		if name == "":
			break
		if name.begins_with("."):
			continue
		var path: String = dir_path.path_join(name)
		if dir.current_is_dir():
			result.append_array(_collect_paths(path))
		else:
			if _matches_extension(name):
				result.append(path)
	dir.list_dir_end()
	return result


func _matches_extension(filename: String) -> bool:
	var ext: String = filename.get_extension().to_lower()
	if ext == "glb":
		return include_glb
	if ext == "gltf":
		return include_gltf
	if ext == "tscn":
		return include_tscn
	return false


func _scan_model(path: String) -> Dictionary:
	var res: Resource = load(path)
	if res == null:
		push_warning("Model scan: failed to load %s" % path)
		return {}
	if res is PackedScene:
		var root: Node = (res as PackedScene).instantiate()
		var info: Dictionary = _scan_root(path, root)
		root.free()
		return info
	push_warning("Model scan: unsupported resource type at %s" % path)
	return {}


func _scan_root(path: String, root: Node) -> Dictionary:
	var combined := AABB()
	var has_bounds := false
	var mesh_count := 0
	var node_count := 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		node_count += 1
		if node is MeshInstance3D:
			var mi := node as MeshInstance3D
			if mi.mesh != null:
				var aabb: AABB = mi.get_aabb()
				var global_aabb: AABB = _aabb_to_global(mi, aabb)
				if not has_bounds:
					combined = global_aabb
					has_bounds = true
				else:
					combined = combined.merge(global_aabb)
				mesh_count += 1
		for child in node.get_children():
			if child is Node:
				stack.append(child)
	if not has_bounds:
		return {}
	var min_y: float = combined.position.y
	var max_y: float = combined.position.y + combined.size.y
	return {
		"path": path,
		"height": max_y - min_y,
		"min_y": min_y,
		"max_y": max_y,
		"mesh_count": mesh_count,
		"node_count": node_count,
		"bounds": {
			"x": combined.position.x,
			"y": combined.position.y,
			"z": combined.position.z,
			"sx": combined.size.x,
			"sy": combined.size.y,
			"sz": combined.size.z,
		},
	}


func _write_text(path: String, text: String) -> void:
	var base_dir := path.get_base_dir()
	var dir := DirAccess.open("res://")
	if dir and not dir.dir_exists(base_dir):
		dir.make_dir_recursive(base_dir)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Model scan: failed to write %s" % path)
		return
	file.store_string(text)
	file.close()


func _aabb_to_global(node: Node3D, aabb: AABB) -> AABB:
	var corners: Array[Vector3] = _aabb_corners(aabb)
	var world_t: Transform3D = _node_global_transform(node)
	var min_x := INF
	var min_y := INF
	var min_z := INF
	var max_x := -INF
	var max_y := -INF
	var max_z := -INF
	for corner in corners:
		var world: Vector3 = world_t * corner
		min_x = minf(min_x, world.x)
		min_y = minf(min_y, world.y)
		min_z = minf(min_z, world.z)
		max_x = maxf(max_x, world.x)
		max_y = maxf(max_y, world.y)
		max_z = maxf(max_z, world.z)
	return AABB(Vector3(min_x, min_y, min_z), Vector3(max_x - min_x, max_y - min_y, max_z - min_z))


func _aabb_corners(aabb: AABB) -> Array[Vector3]:
	var pos: Vector3 = aabb.position
	var size: Vector3 = aabb.size
	return [
		pos,
		pos + Vector3(size.x, 0.0, 0.0),
		pos + Vector3(0.0, size.y, 0.0),
		pos + Vector3(0.0, 0.0, size.z),
		pos + Vector3(size.x, size.y, 0.0),
		pos + Vector3(size.x, 0.0, size.z),
		pos + Vector3(0.0, size.y, size.z),
		pos + Vector3(size.x, size.y, size.z),
	]


func _node_global_transform(node: Node3D) -> Transform3D:
	var t: Transform3D = node.transform
	var parent: Node = node.get_parent()
	while parent is Node3D:
		t = (parent as Node3D).transform * t
		parent = parent.get_parent()
	return t
