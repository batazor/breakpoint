extends RefCounted
class_name HexGridRivers

const WorldGeneratorScript = preload("res://scripts/world_generator.gd")

var grid
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var variant_seed: int = 0


func _init(owner) -> void:
	grid = owner


func clear() -> void:
	grid.river_bucket_instances.clear()
	grid.river_mask.resize(0)


func generate() -> void:
	var count: int = grid.map_width * grid.map_height
	grid.river_mask.resize(count)
	for i in range(count):
		grid.river_mask[i] = 0
	if count <= 0 or grid.height_cache.is_empty():
		return
	if not grid.river_enabled:
		return
	_init_rng()
	var sources: Array[Vector2i] = _river_source_candidates()
	if sources.is_empty():
		return
	var attempts: int = max(grid.river_generation_attempts, grid.river_count)
	var created: int = 0
	var tries: int = 0
	while created < grid.river_count and tries < attempts:
		if sources.is_empty():
			break
		var idx: int = rng.randi_range(0, sources.size() - 1)
		var source: Vector2i = sources[idx]
		sources.remove_at(idx)
		tries += 1
		if _river_has_any(source.x, source.y):
			continue
		var steps: Array = _build_river_path(source)
		if steps.is_empty():
			continue
		_apply_river_path(steps)
		created += 1


func build_multimesh() -> void:
	grid.river_bucket_instances.clear()
	if not grid.river_enabled or grid.river_mask.is_empty():
		return
	var river_meshes := {
		"A": grid._load_tile_mesh(grid.river_mesh_a_path),
		"A_curvy": grid._load_tile_mesh(grid.river_mesh_a_curvy_path),
		"B": grid._load_tile_mesh(grid.river_mesh_b_path),
		"C": grid._load_tile_mesh(grid.river_mesh_c_path),
		"D": grid._load_tile_mesh(grid.river_mesh_d_path),
		"E": grid._load_tile_mesh(grid.river_mesh_e_path),
		"F": grid._load_tile_mesh(grid.river_mesh_f_path),
		"G": grid._load_tile_mesh(grid.river_mesh_g_path),
		"H": grid._load_tile_mesh(grid.river_mesh_h_path),
		"I": grid._load_tile_mesh(grid.river_mesh_i_path),
		"J": grid._load_tile_mesh(grid.river_mesh_j_path),
		"K": grid._load_tile_mesh(grid.river_mesh_k_path),
		"L": grid._load_tile_mesh(grid.river_mesh_l_path),
		"crossing_A": grid._load_tile_mesh(grid.river_mesh_crossing_a_path),
		"crossing_B": grid._load_tile_mesh(grid.river_mesh_crossing_b_path),
	}
	var buckets: Dictionary = {}
	for r in range(grid.map_height):
		for q in range(grid.map_width):
			var info := _river_mesh_info(q, r)
			if info.is_empty():
				continue
			var variant: String = info["variant"]
			var mesh: Mesh = river_meshes.get(variant, null)
			if mesh == null:
				continue
			var rotation_steps: int = int(info["rotation"])
			var t: Transform3D = grid._tile_transform(q, r, rotation_steps)
			t.origin.y += grid.river_height_offset
			_append_river_bucket(buckets, "river_" + variant, mesh, t, grid.river_mesh_tint, grid.river_mesh_scale)

	for key in buckets.keys():
		var entry: Dictionary = buckets[key]
		var bucket_name := "%sMultiMesh" % key
		var inst: MultiMeshInstance3D = grid._add_multimesh_bucket(bucket_name, entry["mesh"], entry["transforms"], entry["tint"], entry["scale"])
		if inst:
			grid.river_bucket_instances[key] = inst


func get_mesh_info(q: int, r: int) -> Dictionary:
	return _river_mesh_info(q, r)


func _init_rng() -> void:
	rng = RandomNumberGenerator.new()
	if grid.randomize_river_seed:
		rng.randomize()
	elif grid.river_seed != 0:
		rng.seed = grid.river_seed
	else:
		rng.seed = grid.height_seed
	variant_seed = int(rng.seed)


func _river_source_candidates() -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	var min_height: float = max(grid.river_source_min_height, grid.mountain_level_runtime)
	for r in range(grid.map_height):
		for q in range(grid.map_width):
			if grid._tile_biome(q, r) != WorldGeneratorScript.Biome.MOUNTAIN:
				continue
			if grid._get_height(q, r) < min_height:
				continue
			candidates.append(Vector2i(q, r))
	return candidates


func _build_river_path(source: Vector2i) -> Array:
	var steps: Array = []
	var current: Vector2i = source
	var visited: Dictionary = {}
	visited[current] = true
	var reached_end := false
	for i in range(max(grid.river_max_length, 1)):
		var next_info: Dictionary = _pick_next_river_step(current, visited)
		if next_info.is_empty():
			break
		var dir: int = int(next_info["dir"])
		steps.append({
			"from": current,
			"dir": dir,
		})
		if bool(next_info["end"]):
			reached_end = true
			break
		var next_pos: Vector2i = next_info["pos"]
		current = next_pos
		visited[current] = true
	if not reached_end:
		return []
	if steps.size() < grid.river_min_length:
		return []
	return steps


func _pick_next_river_step(current: Vector2i, visited: Dictionary) -> Dictionary:
	var cur_height: float = grid._get_height(current.x, current.y)
	var best_score: float = 999.0
	var best_dirs: Array[int] = []
	for dir in range(grid.HEX_DIRS.size()):
		var nq: int = current.x + grid.HEX_DIRS[dir].x
		var nr: int = current.y + grid.HEX_DIRS[dir].y
		if nq < 0 or nq >= grid.map_width or nr < 0 or nr >= grid.map_height:
			continue
		var next_pos := Vector2i(nq, nr)
		if visited.has(next_pos):
			continue
		var next_biome: int = grid._tile_biome(nq, nr)
		var is_water: bool = next_biome == WorldGeneratorScript.Biome.WATER
		var is_merge: bool = grid.river_allow_merge and _river_has_any(nq, nr)
		if not is_water and not is_merge:
			var next_height: float = grid._get_height(nq, nr)
			if next_height > cur_height + grid.river_uphill_tolerance:
				continue
		var score: float = grid._get_height(nq, nr)
		if is_water:
			score -= 1.0
		if is_merge:
			score -= 0.5
		if score < best_score - 0.0001:
			best_score = score
			best_dirs = [dir]
		elif is_equal_approx(score, best_score):
			best_dirs.append(dir)
	if best_dirs.is_empty():
		return {}
	var pick: int = rng.randi_range(0, best_dirs.size() - 1)
	var dir: int = best_dirs[pick]
	var target := Vector2i(current.x + grid.HEX_DIRS[dir].x, current.y + grid.HEX_DIRS[dir].y)
	var target_biome: int = grid._tile_biome(target.x, target.y)
	var end: bool = target_biome == WorldGeneratorScript.Biome.WATER
	if grid.river_allow_merge and _river_has_any(target.x, target.y):
		end = true
	return {
		"dir": dir,
		"pos": target,
		"end": end,
	}


func _apply_river_path(steps: Array) -> void:
	for step in steps:
		var from: Vector2i = step["from"]
		var dir: int = int(step["dir"])
		_add_river_edge(from, dir)


func _add_river_edge(from: Vector2i, dir: int) -> void:
	if dir < 0 or dir >= grid.HEX_DIRS.size():
		return
	var idx: int = from.y * grid.map_width + from.x
	if idx < 0 or idx >= grid.river_mask.size():
		return
	grid.river_mask[idx] = grid.river_mask[idx] | (1 << dir)
	var nq: int = from.x + grid.HEX_DIRS[dir].x
	var nr: int = from.y + grid.HEX_DIRS[dir].y
	if nq < 0 or nq >= grid.map_width or nr < 0 or nr >= grid.map_height:
		return
	if grid._tile_biome(nq, nr) == WorldGeneratorScript.Biome.WATER:
		return
	var n_idx: int = nr * grid.map_width + nq
	if n_idx < 0 or n_idx >= grid.river_mask.size():
		return
	var opposite := (dir + 3) % 6
	grid.river_mask[n_idx] = grid.river_mask[n_idx] | (1 << opposite)


func _river_mask_at(q: int, r: int) -> int:
	var idx: int = r * grid.map_width + q
	if idx < 0 or idx >= grid.river_mask.size():
		return 0
	return int(grid.river_mask[idx])


func _river_has_any(q: int, r: int) -> bool:
	return _river_mask_at(q, r) != 0


func _river_mesh_info(q: int, r: int) -> Dictionary:
	if grid._tile_biome(q, r) == WorldGeneratorScript.Biome.WATER:
		return {}
	var mask := _river_mask_at(q, r)
	if mask == 0:
		return {}
	grid.tile_sides.load_patterns(grid.TILE_SIDES_PATH)
	var neighbor_types := _river_neighbor_types(mask)
	var matches: Array[Dictionary] = []
	var variants: Array[String] = [
		"A",
		"A_curvy",
		"B",
		"C",
		"D",
		"E",
		"F",
		"G",
		"H",
		"I",
		"J",
		"K",
		"L",
		"crossing_A",
		"crossing_B",
	]
	for variant in variants:
		var key := "river_%s" % variant
		if not grid.tile_sides.patterns.has(key):
			continue
		var pattern: Array = grid.tile_sides.patterns[key]
		var rot: int = grid.tile_sides.match_pattern(pattern, neighbor_types)
		if rot >= 0:
			matches.append({"variant": variant, "rotation": rot})
	if matches.is_empty():
		return _river_mesh_fallback(mask)
	return _pick_variant_match(q, r, matches)


func _river_neighbor_types(mask: int) -> Array[String]:
	var types: Array[String] = []
	types.resize(grid.HEX_DIRS.size())
	for dir in range(grid.HEX_DIRS.size()):
		var has_river := (mask & (1 << dir)) != 0
		types[dir] = "river" if has_river else "land"
	return types


func _river_mesh_fallback(mask: int) -> Dictionary:
	var dirs: Array[int] = _river_dirs_from_mask(mask)
	var count: int = dirs.size()
	if count == 1:
		return {"variant": "A", "rotation": dirs[0]}
	if count == 2:
		var rot_c: int = _rotation_for_pattern([0, 1], dirs)
		if rot_c >= 0:
			return {"variant": "C", "rotation": rot_c}
		var rot_b: int = _rotation_for_pattern([0, 3], dirs)
		if rot_b >= 0:
			return {"variant": "B", "rotation": rot_b}
		var rot_f: int = _rotation_for_pattern([0, 2], dirs)
		if rot_f >= 0:
			return {"variant": "F", "rotation": rot_f}
		return {"variant": "B", "rotation": dirs[0]}
	if count == 3:
		var rot_d: int = _rotation_for_pattern([0, 1, 2], dirs)
		if rot_d >= 0:
			return {"variant": "D", "rotation": rot_d}
		var rot_g: int = _rotation_for_pattern([0, 2, 4], dirs)
		if rot_g >= 0:
			return {"variant": "G", "rotation": rot_g}
		var rot_h: int = _rotation_for_pattern([0, 1, 3], dirs)
		if rot_h >= 0:
			return {"variant": "H", "rotation": rot_h}
		return {"variant": "D", "rotation": dirs[0]}
	if count == 4:
		var rot_e: int = _rotation_for_pattern([0, 1, 3, 4], dirs)
		if rot_e >= 0:
			return {"variant": "E", "rotation": rot_e}
		var rot_i: int = _rotation_for_pattern([2, 3, 4, 5], dirs)
		if rot_i >= 0:
			return {"variant": "I", "rotation": rot_i}
		var rot_j: int = _rotation_for_pattern([1, 3, 4, 5], dirs)
		if rot_j >= 0:
			return {"variant": "J", "rotation": rot_j}
		return {"variant": "E", "rotation": dirs[0]}
	if count == 5:
		var rot_k: int = _rotation_for_pattern([1, 2, 3, 4, 5], dirs)
		if rot_k >= 0:
			return {"variant": "K", "rotation": rot_k}
		return {"variant": "K", "rotation": 0}
	if count >= 6:
		return {"variant": "L", "rotation": 0}
	return {}


func _pick_variant_match(q: int, r: int, matches: Array[Dictionary]) -> Dictionary:
	if matches.is_empty():
		return {}
	if matches.size() == 1:
		return matches[0]
	var idx: int = _variant_pick_index(q, r, matches.size())
	return matches[idx]


func _variant_pick_index(q: int, r: int, count: int) -> int:
	if count <= 1:
		return 0
	var h: int = int(q * 73856093) ^ int(r * 19349663) ^ int(variant_seed * 83492791)
	if h < 0:
		h = -h
	return h % count


func _river_dirs_from_mask(mask: int) -> Array[int]:
	var dirs: Array[int] = []
	for dir in range(grid.HEX_DIRS.size()):
		if (mask & (1 << dir)) != 0:
			dirs.append(dir)
	return dirs


func _rotation_for_pattern(pattern_dirs: Array[int], dirs: Array[int]) -> int:
	if pattern_dirs.size() != dirs.size():
		return -1
	var dir_set: Dictionary = {}
	for d in dirs:
		dir_set[d] = true
	for rot in range(6):
		var ok := true
		for d in pattern_dirs:
			var world_dir := (d + rot) % 6
			if not dir_set.has(world_dir):
				ok = false
				break
		if ok:
			return rot
	return -1


func _is_adjacent_dir(a: int, b: int) -> bool:
	return b == (a + 1) % 6 or a == (b + 1) % 6


func _append_river_bucket(buckets: Dictionary, key: String, mesh: Mesh, t: Transform3D, tint: Color, scale: Vector3) -> void:
	if not buckets.has(key):
		buckets[key] = {
			"mesh": mesh,
			"transforms": [],
			"tint": tint,
			"scale": scale,
		}
	var entry: Dictionary = buckets[key]
	var transforms: Array = entry["transforms"]
	transforms.append(t)
	entry["transforms"] = transforms
