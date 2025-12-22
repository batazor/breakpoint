extends Node
class_name HeightGenerator

# Параметры шума
@export var seed: int = 0
@export var frequency: float = 0.005
@export var octaves: int = 6
@export var lacunarity: float = 2.0
@export var gain: float = 0.5
@export var bias: float = -0.10  # опускаем общий уровень, чтобы воды было больше
@export var island_strength: float = 2.5
@export var falloff_power: float = 3.0  # степень для falloff (больше — резче края)
@export var warp_strength: float = 12.0   # домен-варп, чтобы материки не были круглыми
@export var warp_frequency: float = 0.05
@export var height_steps: int = 0  # 0/1 — без квантования
@export var island_noise_strength: float = 0.6  # добавляет вариативность береговой линии
@export var island_noise_frequency: float = 0.05
@export var island_noise_octaves: int = 3
@export var lake_strength: float = 0.35      # глубина озёр
@export var lake_frequency: float = 0.02    # частота озёр
@export var lake_threshold: float = 0.48     # чем выше, тем меньше озёр (0..1)
@export var lake_octaves: int = 2
@export var mountain_strength: float = 0.6
@export var mountain_frequency: float = 0.02
@export var mountain_octaves: int = 4
@export var mountain_ridge_power: float = 1.5
@export var plate_count: int = 12
@export var plate_mountain_strength: float = 0.6
@export var plate_velocity_scale: float = 0.6
@export var plate_edge_sharpness: float = 1.25  # выше → более узкие хребты
@export var plate_jitter: float = 0.2  # разброс центров за границами карты


# Основная функция: возвращает высоту в диапазоне [-1.0, 1.0] для координаты (q, r)
func get_height(q: int, r: int, map_width: int, map_height: int) -> float:
	# Создаём экземпляр FastNoiseLite
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = seed
	# Тип шума: сглаженный симплекс
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	# Фрактальный режим (FBM — многослойный шум)
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = octaves
	noise.fractal_lacunarity = lacunarity
	noise.fractal_gain = gain
	noise.frequency = frequency

	# Вспомогательный шум для домен-варпа
	var warp := FastNoiseLite.new()
	warp.seed = seed + 1337
	warp.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	warp.frequency = warp_frequency

	# Нойз для вариативности берегов (маска островов)
	var coast: FastNoiseLite = FastNoiseLite.new()
	coast.seed = seed + 9001
	coast.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	coast.fractal_type = FastNoiseLite.FRACTAL_FBM
	coast.fractal_octaves = island_noise_octaves
	coast.frequency = island_noise_frequency

	# Озёрный шум — вырезаем «карманы» на суше
	var lakes := FastNoiseLite.new()
	lakes.seed = seed + 4242
	lakes.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	lakes.fractal_type = FastNoiseLite.FRACTAL_FBM
	lakes.fractal_octaves = lake_octaves
	lakes.frequency = lake_frequency

	# Нойз для гор (ридж)
	var mount := FastNoiseLite.new()
	mount.seed = seed + 777
	mount.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	mount.fractal_type = FastNoiseLite.FRACTAL_FBM
	mount.fractal_octaves = mountain_octaves
	mount.frequency = mountain_frequency

	# Масштабируем координаты, чтобы шум не был слишком частым
	var nx: float = (float(q) / map_width - 0.5) * map_width
	var ny: float = (float(r) / map_height - 0.5) * map_height

	# Домен-варп для разрыва симметрии
	var wx: float = warp.get_noise_2d(nx, ny) * warp_strength
	var wy: float = warp.get_noise_2d(nx + 123.45, ny - 678.9) * warp_strength
	nx += wx
	ny += wy

	var noise_value: float = noise.get_noise_2d(nx, ny)

	# Falloff (градиент к берегам)
	var dx: float = float(q) / map_width - 0.5
	var dy: float = float(r) / map_height - 0.5
	var dist: float = sqrt(dx * dx + dy * dy)
	var falloff_base: float = clamp(1.0 - pow(dist * island_strength, falloff_power), 0.0, 1.0)
	# Варьируем края шумом, чтобы получить больше островов/заливов.
	var coast_mask: float = coast.get_noise_2d(nx * 0.25, ny * 0.25)  # более гладкий масштаб
	var falloff: float = falloff_base * clamp(1.0 + coast_mask * island_noise_strength, 0.0, 1.0)

	# Комбинируем шум и falloff, добавляем смещение (bias), оставляем в [-1..1]
	var h: float = noise_value * falloff + bias

	# Добавляем горы только на суше через ridge-маску.
	if mountain_strength != 0.0:
		var mval: float = mount.get_noise_2d(nx * 0.7, ny * 0.7)
		var ridge: float = pow(1.0 - abs(mval), mountain_ridge_power)  # 0..1
		var land_mask: float = clamp((h + 0.2) / 0.6, 0.0, 1.0)  # активнее там, где суша
		h += ridge * mountain_strength * land_mask

	# Плитный рельеф (псевдо-plate tectonics) — горы на границах плит.
	if plate_count > 1 and plate_mountain_strength > 0.0:
		_ensure_plates(map_width, map_height)
		var p: Vector2 = Vector2(float(q), float(r))
		var nearest: int = -1
		var second: int = -1
		var d1: float = INF
		var d2: float = INF
		for i in plate_centers.size():
			var d := p.distance_squared_to(plate_centers[i])
			if d < d1:
				d2 = d1
				second = nearest
				d1 = d
				nearest = i
			elif d < d2:
				d2 = d
				second = i

		if nearest >= 0 and second >= 0:
			var nvec: Vector2 = (plate_centers[second] - plate_centers[nearest]).normalized()
			var rel_vel: Vector2 = plate_vels[second] - plate_vels[nearest]
			var converge: float = clamp(-rel_vel.dot(nvec), 0.0, 1.0)
			var edge_factor: float = clamp(pow(1.0 - sqrt(d1) / (map_width * 0.25 + 0.01), plate_edge_sharpness), 0.0, 1.0)
			var land_mask2: float = clamp((h + 0.15) / 0.5, 0.0, 1.0)
			h += converge * edge_factor * plate_mountain_strength * land_mask2

	# Вырезаем озёра: если значение маски выше порога, утапливаем участок.
	if lake_strength > 0.0 and lake_threshold < 1.0:
		var ln: float = (lakes.get_noise_2d(nx * 0.5, ny * 0.5) + 1.0) * 0.5  # 0..1
		if ln > lake_threshold:
			var t: float = (ln - lake_threshold) / max(0.001, 1.0 - lake_threshold)
			h -= lake_strength * t

	if height_steps > 1:
		var step: float = 2.0 / float(height_steps - 1)  # шаг по диапазону [-1..1]
		h = round(h / step) * step
	return clamp(h, -1.0, 1.0)


var plate_centers: Array[Vector2] = []
var plate_vels: Array[Vector2] = []
var plate_cache_seed: int = 0
var plate_cache_w: int = 0
var plate_cache_h: int = 0


func _ensure_plates(w: int, h: int) -> void:
	if plate_centers.size() == plate_count and plate_cache_seed == seed and plate_cache_w == w and plate_cache_h == h:
		return
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed
	plate_centers.clear()
	plate_vels.clear()
	var jitter := plate_jitter
	for i in range(max(1, plate_count)):
		var cx: float = rng.randf_range(-jitter, 1.0 + jitter) * float(w)
		var cy: float = rng.randf_range(-jitter, 1.0 + jitter) * float(h)
		plate_centers.append(Vector2(cx, cy))
		var ang: float = rng.randf_range(-PI, PI)
		var vel: Vector2 = Vector2(cos(ang), sin(ang)) * plate_velocity_scale
		plate_vels.append(vel)
	plate_cache_seed = seed
	plate_cache_w = w
	plate_cache_h = h
