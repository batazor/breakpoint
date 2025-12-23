extends RefCounted
class_name HexGridTileSides

var side_map: Dictionary = {}
var patterns: Dictionary = {}
var patterns_loaded: bool = false


func load_side_map(path: String) -> void:
	side_map.clear()
	if path.is_empty():
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Failed to open tile sides yaml at %s" % path)
		return
	var text := file.get_as_text()
	file.close()
	side_map = _parse_tile_side_yaml(text)


func load_patterns(path: String) -> void:
	if patterns_loaded:
		return
	patterns_loaded = true
	patterns.clear()
	if path.is_empty():
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Tile sides file not found: %s" % path)
		return
	var current_key := ""
	var reading_sides := false
	var sides: Array[String] = []
	while not file.eof_reached():
		var line := file.get_line()
		var trimmed := line.strip_edges()
		if trimmed.is_empty() or trimmed.begins_with("#"):
			continue
		if trimmed.begins_with("side:"):
			reading_sides = true
			sides.clear()
			continue
		if trimmed.ends_with(":") and not trimmed.begins_with("-"):
			var key := trimmed.substr(0, trimmed.length() - 1)
			if key == "tiles":
				current_key = ""
				reading_sides = false
				sides.clear()
				continue
			current_key = key
			reading_sides = false
			sides.clear()
			continue
		if reading_sides and trimmed.begins_with("-"):
			var value := trimmed.substr(1, trimmed.length() - 1).strip_edges()
			sides.append(value)
			if current_key != "" and sides.size() == 6:
				patterns[current_key] = sides.duplicate()
				reading_sides = false
	file.close()


func reset_patterns() -> void:
	patterns_loaded = false
	patterns.clear()


func match_pattern(pattern: Array, neighbor_types: Array[String]) -> int:
	if pattern.size() != 6 or neighbor_types.size() != 6:
		return -1
	for rot in range(6):
		var ok := true
		for i in range(6):
			var expected: String = pattern[(i - rot + 6) % 6]
			if neighbor_types[i] != expected:
				ok = false
				break
		if ok:
			return rot
	return -1


func rotation_from_side_map(key: String, neighbor_water: Array[bool], fallback_steps: int) -> int:
	if side_map.is_empty():
		return fallback_steps
	if not side_map.has(key):
		return fallback_steps
	var entry: Variant = side_map[key]
	if entry == null or not entry.has("side"):
		return fallback_steps
	var sides: Array = entry["side"]
	if sides.size() != 6:
		return fallback_steps
	if neighbor_water.size() != 6:
		return fallback_steps

	var best_steps := fallback_steps
	var best_score := -1
	for rot in range(6):
		var score := _score_side_match(sides, neighbor_water, rot)
		if score > best_score or (score == best_score and rot == fallback_steps):
			best_score = score
			best_steps = rot
	return best_steps


func _score_side_match(sides: Array, neighbor_water: Array[bool], rotation_steps: int) -> int:
	var score := 0
	for side_idx in range(6):
		var side_val := String(sides[side_idx]).to_lower()
		var side_is_water := side_val == "water"
		var world_dir := (side_idx + rotation_steps) % 6
		var is_water_neighbor := neighbor_water[world_dir]
		if side_is_water == is_water_neighbor:
			score += 1
	return score


func _parse_tile_side_yaml(text: String) -> Dictionary:
	var result: Dictionary = {}
	var lines := text.split("\n")
	var in_tiles := false
	var current_tile := ""
	var collecting_side := false
	var sides: Array = []

	for line in lines:
		var trimmed := line.strip_edges()
		if trimmed.is_empty() or trimmed.begins_with("#"):
			continue

		if not in_tiles:
			if trimmed == "tiles:":
				in_tiles = true
			continue

		if line.begins_with("  ") and not line.begins_with("    "):
			_commit_tile_to_map(result, current_tile, sides)
			current_tile = trimmed.rstrip(":")
			sides = []
			collecting_side = false
			continue

		if not line.begins_with("    "):
			continue

		if trimmed == "side:":
			collecting_side = true
			continue

		if collecting_side and trimmed.begins_with("-"):
			var val := trimmed.substr(1, trimmed.length()).strip_edges()
			sides.append(val)

	_commit_tile_to_map(result, current_tile, sides)
	return result


func _commit_tile_to_map(result: Dictionary, tile_key: String, sides: Array) -> void:
	if tile_key.is_empty():
		return
	if sides.is_empty():
		return
	result[tile_key] = {"side": sides.duplicate()}
