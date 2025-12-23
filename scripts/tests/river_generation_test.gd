extends SceneTree

const HexGridScript = preload("res://scripts/hex_grid.gd")

const BIOME_WATER := 0
const BIOME_SAND := 1
const BIOME_PLAINS := 2
const BIOME_MOUNTAIN := 3

var failures: int = 0


class TileStub:
	var height: float
	var biome: int

	func _init(height_value: float, biome_value: int) -> void:
		height = height_value
		biome = biome_value


func _initialize() -> void:
	_test_rivers_generate_on_slope()
	_test_rivers_disabled_produces_none()

	if failures == 0:
		print("OK: river generation tests passed.")
		quit()
	else:
		push_error("%d river generation tests failed." % failures)
		quit(1)


func _test_rivers_generate_on_slope() -> void:
	var grid = HexGridScript.new()
	_configure_grid_for_test(grid)
	_seed_simple_slope_map(grid)
	grid._generate_rivers()

	var river_tiles: int = _count_river_tiles(grid)
	_assert(river_tiles > 0, "Expected rivers to be generated on a simple slope map.")


func _test_rivers_disabled_produces_none() -> void:
	var grid = HexGridScript.new()
	_configure_grid_for_test(grid)
	_seed_simple_slope_map(grid)
	grid.river_enabled = false
	grid._generate_rivers()

	var river_tiles: int = _count_river_tiles(grid)
	_assert(river_tiles == 0, "Expected no rivers when river_enabled is false.")


func _configure_grid_for_test(grid) -> void:
	grid.map_width = 16
	grid.map_height = 16
	grid.river_enabled = true
	grid.river_count = 2
	grid.river_min_length = 4
	grid.river_max_length = 20
	grid.river_source_min_height = 0.6
	grid.river_uphill_tolerance = 0.05
	grid.river_generation_attempts = 16
	grid.river_allow_merge = true
	grid.randomize_river_seed = false
	grid.river_seed = 1234


func _seed_simple_slope_map(grid) -> void:
	var width: int = grid.map_width
	var height: int = grid.map_height
	var heights := PackedFloat32Array()
	heights.resize(width * height)
	var tiles: Array = []
	tiles.resize(width * height)

	var water_level: float = 0.3
	var sand_level: float = 0.4
	var mountain_level: float = 0.7
	grid.water_level_runtime = water_level
	grid.sand_level_runtime = sand_level
	grid.mountain_level_runtime = mountain_level

	for r in range(height):
		for q in range(width):
			var t: float = float(r) / float(height - 1)
			var h: float = 1.0 - t
			var idx: int = r * width + q
			heights[idx] = h
			var biome: int = BIOME_PLAINS
			if h < water_level:
				biome = BIOME_WATER
			elif h < sand_level:
				biome = BIOME_SAND
			elif h > mountain_level:
				biome = BIOME_MOUNTAIN
			tiles[idx] = TileStub.new(h, biome)

	grid.height_cache = heights
	grid.tile_data = tiles


func _count_river_tiles(grid) -> int:
	var count: int = 0
	var mask: PackedInt32Array = grid.river_mask
	for i in range(mask.size()):
		if mask[i] != 0:
			count += 1
	return count


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error(message)
