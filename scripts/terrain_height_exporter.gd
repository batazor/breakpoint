@tool
extends Node

# Экспортирует heightmap ([-1..1] → [0..1]) в файл для Terrain3D.

@export var map_width: int = 512
@export var map_height: int = 512
@export var output_path: String = "res://terrain/heightmap.png"

# Параметры шума (прокидываем в HeightGenerator)
@export var seed: int = 0
@export var frequency: float = 0.005
@export var octaves: int = 6
@export var lacunarity: float = 2.0
@export var gain: float = 0.5
@export var island_strength: float = 2.0

const HeightGenerator = preload("res://scripts/height_generator.gd")


func _export_heightmap() -> void:
	if map_width <= 0 or map_height <= 0:
		push_error("Map size must be positive")
		return

	var gen := HeightGenerator.new()
	gen.seed = seed
	gen.frequency = frequency
	gen.octaves = octaves
	gen.lacunarity = lacunarity
	gen.gain = gain
	gen.island_strength = island_strength

	var img := Image.create(map_width, map_height, false, Image.FORMAT_RF)  # один канал float

	for y in range(map_height):
		for x in range(map_width):
			var h := gen.get_height(x, y, map_width, map_height)  # [-1..1]
			var v := clampf((h + 1.0) * 0.5, 0.0, 1.0)  # в [0..1] для сохранения
			img.set_pixel(x, y, Color(v, v, v, 1.0))

	var dir := DirAccess.open("res://")
	if dir and not dir.dir_exists(output_path.get_base_dir()):
		dir.make_dir_recursive(output_path.get_base_dir())

	var err := img.save_png(output_path)
	if err != OK:
		push_error("Failed to save heightmap: %s" % error_string(err))
	else:
		print("Heightmap saved to: %s" % output_path)

