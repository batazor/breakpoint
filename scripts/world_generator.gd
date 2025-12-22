extends RefCounted
class_name WorldGenerator

const HeightGenerator = preload("res://scripts/height_generator.gd")

enum Biome { WATER, SAND, PLAINS, MOUNTAIN }

class WorldTileData:
	var height: float
	var biome: int

	func _init(height_value: float, biome_value: int) -> void:
		height = height_value
		biome = biome_value


var height_gen: HeightGenerator = HeightGenerator.new()
var map_width: int = 0
var map_height: int = 0
var raw_heights: PackedFloat32Array = PackedFloat32Array()
var heights: PackedFloat32Array = PackedFloat32Array()
var height_min: float = 0.0
var height_max: float = 0.0
var tiles: Array = []
var water_level: float = 0.0
var sand_level: float = 0.0
var mountain_level: float = 0.0

var water_pct: float = 0.45
var sand_pct: float = 0.10
var mountain_pct: float = 0.10


func generate(width: int, height: int) -> void:
	map_width = width
	map_height = height
	_generate_raw_heights()
	_normalize_heights()
	_compute_quantile_thresholds()
	_classify_tiles()


func get_tile(q: int, r: int) -> WorldTileData:
	var idx := _index(q, r)
	if idx < 0 or idx >= tiles.size():
		return null
	return tiles[idx]


func _index(q: int, r: int) -> int:
	return r * map_width + q


func _generate_raw_heights() -> void:
	var count := map_width * map_height
	raw_heights.resize(count)
	var idx := 0
	for r in range(map_height):
		for q in range(map_width):
			raw_heights[idx] = height_gen.get_height(q, r, map_width, map_height)
			idx += 1


func _normalize_heights() -> void:
	heights.resize(raw_heights.size())
	if raw_heights.is_empty():
		height_min = 0.0
		height_max = 0.0
		return
	var min_val := raw_heights[0]
	var max_val := raw_heights[0]
	for h in raw_heights:
		min_val = min(min_val, h)
		max_val = max(max_val, h)
	height_min = min_val
	height_max = max_val
	var span := max_val - min_val
	if is_equal_approx(span, 0.0):
		for i in range(raw_heights.size()):
			heights[i] = 0.5
		return
	for i in range(raw_heights.size()):
		heights[i] = clampf((raw_heights[i] - min_val) / span, 0.0, 1.0)


func _compute_quantile_thresholds() -> void:
	if heights.is_empty():
		water_level = 0.0
		sand_level = 0.0
		mountain_level = 0.0
		return

	var sorted := heights.duplicate()
	sorted.sort()
	var sz := sorted.size()
	var wi := int(clamp(floor((sz - 1) * water_pct), 0.0, float(sz - 1)))
	var si := int(clamp(floor((sz - 1) * (water_pct + sand_pct)), 0.0, float(sz - 1)))
	var mi := int(clamp(floor((sz - 1) * (1.0 - mountain_pct)), 0.0, float(sz - 1)))
	water_level = sorted[wi]
	sand_level = sorted[si]
	mountain_level = sorted[mi]

	var eps := 0.0005
	if sand_level <= water_level:
		sand_level = water_level + eps
	if mountain_level <= sand_level:
		mountain_level = sand_level + eps


func _classify_tiles() -> void:
	tiles.resize(heights.size())
	for i in heights.size():
		var h := heights[i]
		var biome := Biome.PLAINS
		if h < water_level:
			biome = Biome.WATER
		elif h < sand_level:
			biome = Biome.SAND
		elif h > mountain_level:
			biome = Biome.MOUNTAIN
		tiles[i] = WorldTileData.new(h, biome)


func _biome_name(biome: int) -> String:
	match biome:
		Biome.WATER:
			return "water"
		Biome.SAND:
			return "sand"
		Biome.MOUNTAIN:
			return "mountain"
		_:
			return "plains"


func to_serializable_dict() -> Dictionary:
	var tiles_payload: Array = []
	tiles_payload.resize(map_width * map_height)
	for r in range(map_height):
		for q in range(map_width):
			var idx := _index(q, r)
			var t: WorldTileData = tiles[idx]
			var raw_h: float = 0.0
			if idx >= 0 and idx < raw_heights.size():
				raw_h = raw_heights[idx]
			tiles_payload[idx] = {
				"q": q,
				"r": r,
				"height": t.height,
				"height_raw": raw_h,
				"biome": t.biome,
				"biome_name": _biome_name(t.biome),
			}

	var raw_heights_payload: Array = []
	raw_heights_payload.resize(raw_heights.size())
	for i in raw_heights.size():
		raw_heights_payload[i] = raw_heights[i]

	var heights_payload: Array = []
	heights_payload.resize(heights.size())
	for i in heights.size():
		heights_payload[i] = heights[i]

	return {
		"width": map_width,
		"height": map_height,
		"water_pct": water_pct,
		"sand_pct": sand_pct,
		"mountain_pct": mountain_pct,
		"water_level": water_level,
		"sand_level": sand_level,
		"mountain_level": mountain_level,
		"height_min": height_min,
		"height_max": height_max,
		"seed": height_gen.seed if height_gen != null else null,
		"tiles": tiles_payload,
		"raw_heights": raw_heights_payload,
		"heights": heights_payload,
	}
