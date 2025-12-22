extends Node3D

const HexUtil = preload("res://scripts/hex.gd")
const HeightGenScript = preload("res://scripts/height_generator.gd")
const RAY_LENGTH := 4000.0

@export var map_width: int = 80
@export var map_height: int = 52
@export var hex_radius: float = 1.0
@export var hex_height: float = 0.25
@export var y_offset: float = 0.0
@export var use_multimesh: bool = true
@export var color_even: Color = Color(0.76, 0.81, 0.87)
@export var color_odd: Color = Color(0.70, 0.76, 0.82)
@export var use_height_color: bool = true
@export var color_water: Color = Color(0.12, 0.25, 0.65)
@export var color_sand: Color = Color(0.85, 0.8, 0.45)
@export var color_grass: Color = Color(0.35, 0.6, 0.3)
@export var color_rock: Color = Color(0.6, 0.6, 0.6)
@export var color_shore: Color = Color(0.80, 0.70, 0.45)
@export_range(-1.0, 1.0, 0.01) var height_water_level: float = -0.05  # используется, если use_quantiles=false
@export var use_quantiles: bool = true
@export_range(0.0, 1.0, 0.01) var water_pct: float = 0.45
@export_range(0.0, 1.0, 0.01) var sand_pct: float = 0.10
@export_range(0.0, 1.0, 0.01) var mountain_pct: float = 0.10
@export_range(0.0, 0.5, 0.01) var shoreline_band: float = 0.08
@export_range(-1.0, 1.0, 0.01) var height_sand_level: float = 0.10   # fallback, если use_quantiles=false
@export_range(-1.0, 1.0, 0.01) var height_grass_level: float = 0.55  # fallback, если use_quantiles=false
@export var use_tile_meshes: bool = true
@export_file("*.glb") var tile_mesh_water_path: String = "res://assets/tiles/hex_water.gltf.glb"
@export_file("*.glb") var tile_mesh_shore_path: String = "res://assets/tiles/hex_sand.gltf.glb"
@export_file("*.glb") var tile_mesh_sand_path: String = "res://assets/tiles/hex_sand.gltf.glb"
@export_file("*.glb") var tile_mesh_grass_path: String = "res://assets/tiles/hex_forest.gltf.glb"
@export_file("*.glb") var tile_mesh_rock_path: String = "res://assets/tiles/hex_rock.gltf.glb"
@export var tile_mesh_scale_uniform: Vector3 = Vector3(1.08, 1.0, 1.08)
@export var tile_jitter: float = 0.02
@export var tile_mesh_scale_water: Vector3 = Vector3.ONE
@export var tile_mesh_scale_shore: Vector3 = Vector3.ONE
@export var tile_mesh_scale_sand: Vector3 = Vector3.ONE
@export var tile_mesh_scale_grass: Vector3 = Vector3.ONE
@export var tile_mesh_scale_rock: Vector3 = Vector3.ONE
@export var height_seed: int = 0
@export var height_frequency: float = 0.02
@export var height_octaves: int = 6
@export var height_lacunarity: float = 2.0
@export var height_gain: float = 0.5
@export var height_island_strength: float = 2.5
@export var height_bias: float = -0.10
@export var height_falloff_power: float = 3.0
@export var height_warp_strength: float = 12.0
@export var height_warp_frequency: float = 0.05
@export var height_island_noise_strength: float = 0.6
@export var height_island_noise_frequency: float = 0.05
@export var height_island_noise_octaves: int = 3
@export var height_lake_strength: float = 0.35
@export var height_lake_frequency: float = 0.02
@export var height_lake_threshold: float = 0.48
@export var height_lake_octaves: int = 2
@export var height_mountain_strength: float = 0.6
@export var height_mountain_frequency: float = 0.02
@export var height_mountain_octaves: int = 4
@export var height_mountain_ridge_power: float = 1.5
@export var height_plate_count: int = 12
@export var height_plate_mountain_strength: float = 0.6
@export var height_plate_velocity_scale: float = 0.6
@export var height_plate_edge_sharpness: float = 1.25
@export var height_plate_jitter: float = 0.2
@export var height_vertical_scale: float = 0.6
@export var height_vertical_offset: float = 0.0
@export var water_plane_height: float = 0.0
@export var fallback_to_hex_mesh: bool = true
@export var randomize_height_seed: bool = true
@export var selection_color: Color = Color(1.0, 0.6, 0.2, 0.6)
@export var selection_height: float = 0.05
@export var selection_scale: float = 1.05

var bounds_rect: Rect2
var multimesh_instance: MultiMeshInstance3D
var collision_root: Node3D
var shared_shape: ConvexPolygonShape3D
var hex_basis: Basis = Basis(Vector3.UP, deg_to_rad(30.0))  # rotate mesh to flat-top
var selection_indicator: MeshInstance3D
var height_gen: HeightGenerator
var height_cache: PackedFloat32Array = PackedFloat32Array()
var water_level_runtime: float
var sand_level_runtime: float
var mountain_level_runtime: float


func _ready() -> void:
	bounds_rect = HexUtil.bounds_for_rect(map_width, map_height, hex_radius)
	collision_root = Node3D.new()
	collision_root.name = "CollisionRoot"
	add_child(collision_root)
	_init_height_generator()
	_precompute_heights()
	_create_selection_indicator()
	regenerate_grid()


func regenerate_grid() -> void:
	_clear_children()
	_init_height_generator()
	_precompute_heights()
	bounds_rect = HexUtil.bounds_for_rect(map_width, map_height, hex_radius)
	shared_shape = _build_hex_shape()

	if use_multimesh:
		_build_multimesh()
	else:
		_build_mesh_instances()

	_build_colliders()


func _clear_children() -> void:
	if is_instance_valid(multimesh_instance):
		multimesh_instance.queue_free()
		multimesh_instance = null

	if is_instance_valid(collision_root):
		for child in collision_root.get_children():
			child.queue_free()


func _build_hex_mesh() -> Mesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = hex_radius
	mesh.bottom_radius = hex_radius
	mesh.height = hex_height
	mesh.radial_segments = 6
	mesh.rings = 1
	return mesh


func _build_multimesh() -> void:
	if use_tile_meshes:
		_build_multimesh_per_biome()
		return

	var hex_mesh := _build_hex_mesh()

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	hex_mesh.surface_set_material(0, mat)

	var multimesh := MultiMesh.new()
	multimesh.set_use_colors(true)
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = hex_mesh
	multimesh.instance_count = map_width * map_height

	var idx := 0
	for r in range(map_height):
		for q in range(map_width):
			var t := _tile_transform(q, r)
			multimesh.set_instance_transform(idx, t)
			multimesh.set_instance_color(idx, _tile_color(q, r))
			idx += 1

	multimesh_instance = MultiMeshInstance3D.new()
	multimesh_instance.name = "HexMultiMesh"
	multimesh_instance.multimesh = multimesh
	multimesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(multimesh_instance)


func _build_multimesh_per_biome() -> void:
	var mesh_water := _load_tile_mesh(tile_mesh_water_path)
	var mesh_shore := _load_tile_mesh(tile_mesh_shore_path)
	var mesh_sand := _load_tile_mesh(tile_mesh_sand_path)
	var mesh_grass := _load_tile_mesh(tile_mesh_grass_path)
	var mesh_rock := _load_tile_mesh(tile_mesh_rock_path)

	var buckets := {
		"water": [],
		"shore": [],
		"sand": [],
		"grass": [],
		"rock": [],
	}

	for r in range(map_height):
		for q in range(map_width):
			var t := _tile_transform(q, r)
			var biome := _biome_for_height(_get_height(q, r))
			if buckets.has(biome):
				buckets[biome].append(t)

	var total: int = buckets["water"].size() + buckets["shore"].size() + buckets["sand"].size() + buckets["grass"].size() + buckets["rock"].size()
	if total != map_width * map_height:
		push_warning("Tile distribution mismatch: %d vs %d" % [total, map_width * map_height])

	_add_multimesh_bucket("WaterMultiMesh", mesh_water, buckets["water"], color_water, tile_mesh_scale_water)
	_add_multimesh_bucket("ShoreMultiMesh", mesh_shore, buckets["shore"], color_shore, tile_mesh_scale_shore)
	_add_multimesh_bucket("SandMultiMesh", mesh_sand, buckets["sand"], color_sand, tile_mesh_scale_sand)
	_add_multimesh_bucket("GrassMultiMesh", mesh_grass, buckets["grass"], color_grass, tile_mesh_scale_grass)
	_add_multimesh_bucket("RockMultiMesh", mesh_rock, buckets["rock"], color_rock, tile_mesh_scale_rock)


func _build_mesh_instances() -> void:
	# Slower than MultiMesh, but useful for debugging.
	var mesh := _build_hex_mesh()
	for r in range(map_height):
		for q in range(map_width):
			var mesh_instance := MeshInstance3D.new()
			mesh_instance.mesh = mesh
			mesh_instance.transform = _tile_transform(q, r)
			mesh_instance.modulate = _tile_color(q, r)
			mesh_instance.name = "Hex_%s_%s" % [q, r]
			add_child(mesh_instance)


func _build_colliders() -> void:
	if shared_shape == null:
		return

	for r in range(map_height):
		for q in range(map_width):
			var body := StaticBody3D.new()
			body.collision_layer = 1
			body.collision_mask = 1
			body.position = _tile_transform(q, r).origin
			body.set_meta("axial", Vector2i(q, r))

			var shape := CollisionShape3D.new()
			shape.shape = shared_shape
			body.add_child(shape)

			collision_root.add_child(body)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_pick_tile(event.position)


func _pick_tile(screen_pos: Vector2) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return

	var origin := camera.project_ray_origin(screen_pos)
	var direction := camera.project_ray_normal(screen_pos)

	var params: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + direction * RAY_LENGTH)
	params.collide_with_areas = false
	params.collide_with_bodies = true
	params.collision_mask = 1

	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(params)
	if hit.is_empty():
		return

	var collider: Object = hit.get("collider")
	if collider and collider.has_meta("axial"):
		var axial: Vector2i = collider.get_meta("axial")
		_show_selection(axial)
		print("Clicked hex q=%d r=%d" % [axial.x, axial.y])


func get_bounds_rect() -> Rect2:
	return bounds_rect


func get_map_center() -> Vector3:
	return HexUtil.center_of_rect(map_width, map_height, hex_radius) + Vector3(0.0, y_offset, 0.0)


func _build_hex_shape() -> ConvexPolygonShape3D:
	var corners := HexUtil.hex_corners(hex_radius)
	var verts := PackedVector3Array()

	var half_height := hex_height * 0.5
	for c in corners:
		verts.append(Vector3(c.x, half_height, c.z))
	for c in corners:
		verts.append(Vector3(c.x, -half_height, c.z))

	var shape := ConvexPolygonShape3D.new()
	shape.points = verts
	return shape


func _create_selection_indicator() -> void:
	selection_indicator = MeshInstance3D.new()
	selection_indicator.name = "Selection"
	var mesh := CylinderMesh.new()
	mesh.top_radius = hex_radius * selection_scale
	mesh.bottom_radius = hex_radius * selection_scale
	mesh.height = selection_height
	mesh.radial_segments = 6
	mesh.rings = 1

	var mat := StandardMaterial3D.new()
	mat.albedo_color = selection_color
	mat.emission_enabled = true
	mat.emission = selection_color
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.surface_set_material(0, mat)

	selection_indicator.mesh = mesh
	selection_indicator.visible = false
	add_child(selection_indicator)


func _show_selection(axial: Vector2i) -> void:
	if selection_indicator == null:
		return
	var pos := HexUtil.axial_to_world(axial.x, axial.y, hex_radius)
	var y := _tile_height(axial.x, axial.y) + hex_height * 0.5 + selection_height * 0.5 + 0.01
	selection_indicator.transform = Transform3D(hex_basis, Vector3(pos.x, y, pos.z))
	selection_indicator.visible = true


func _get_height(q: int, r: int) -> float:
	var idx := r * map_width + q
	if idx >= 0 and idx < height_cache.size():
		return height_cache[idx]
	if height_gen == null:
		return 0.0
	return height_gen.get_height(q, r, map_width, map_height)


func _tile_color(q: int, r: int) -> Color:
	if use_height_color and height_gen:
		var h := _get_height(q, r)
		return _color_from_height(h)
	return color_even if ((q + r) % 2 == 0) else color_odd


func _biome_for_height(h: float) -> String:
	if h <= water_level_runtime:
		return "water"
	if h <= min(sand_level_runtime, water_level_runtime + shoreline_band):
		return "shore"
	if h <= sand_level_runtime:
		return "sand"
	if h >= mountain_level_runtime:
		return "rock"
	return "grass"


func _color_from_height(h: float) -> Color:
	var hw: float = water_level_runtime
	var shore_hi: float = min(sand_level_runtime, water_level_runtime + shoreline_band)
	var hs: float = sand_level_runtime
	var hg: float = mountain_level_runtime

	if h <= hw:
		return color_water
	if h <= shore_hi:
		return color_shore
	if h <= hs:
		return _lerp_color(color_shore, color_sand, _lerp01(h, hw, hs))
	if h <= hg:
		return _lerp_color(color_sand, color_grass, _lerp01(h, hs, hg))
	return color_rock


func _lerp01(v: float, a: float, b: float) -> float:
	if is_equal_approx(a, b):
		return 0.0
	return clampf((v - a) / (b - a), 0.0, 1.0)


func _lerp_color(c1: Color, c2: Color, t: float) -> Color:
	return c1.lerp(c2, clampf(t, 0.0, 1.0))


func _init_height_generator() -> void:
	height_gen = HeightGenerator.new()
	var seed_to_use := height_seed
	if randomize_height_seed:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		seed_to_use = int(rng.randi())
	height_gen.seed = seed_to_use
	height_gen.frequency = height_frequency
	height_gen.octaves = height_octaves
	height_gen.lacunarity = height_lacunarity
	height_gen.gain = height_gain
	height_gen.island_strength = height_island_strength
	height_gen.bias = height_bias
	height_gen.falloff_power = height_falloff_power
	height_gen.warp_strength = height_warp_strength
	height_gen.warp_frequency = height_warp_frequency
	height_gen.island_noise_strength = height_island_noise_strength
	height_gen.island_noise_frequency = height_island_noise_frequency
	height_gen.island_noise_octaves = height_island_noise_octaves
	height_gen.lake_strength = height_lake_strength
	height_gen.lake_frequency = height_lake_frequency
	height_gen.lake_threshold = height_lake_threshold
	height_gen.lake_octaves = height_lake_octaves
	height_gen.mountain_strength = height_mountain_strength
	height_gen.mountain_frequency = height_mountain_frequency
	height_gen.mountain_octaves = height_mountain_octaves
	height_gen.mountain_ridge_power = height_mountain_ridge_power
	height_gen.plate_count = height_plate_count
	height_gen.plate_mountain_strength = height_plate_mountain_strength
	height_gen.plate_velocity_scale = height_plate_velocity_scale
	height_gen.plate_edge_sharpness = height_plate_edge_sharpness
	height_gen.plate_jitter = height_plate_jitter


func _load_tile_mesh(path: String) -> Mesh:
	if path.is_empty():
		return _hex_mesh_singleton() if fallback_to_hex_mesh else null
	var res := load(path)
	if res == null:
		push_warning("Failed to load tile mesh at %s" % path)
		return _hex_mesh_singleton() if fallback_to_hex_mesh else null
	if res is Mesh:
		return res
	if res is PackedScene:
		var inst: Node = res.instantiate()
		if inst is MeshInstance3D and inst.mesh:
			var m: Mesh = inst.mesh
			inst.queue_free()
			return m
		# поиск первого MeshInstance3D в сцене
		var queue: Array[Node] = [inst]
		while not queue.is_empty():
			var node: Node = queue.pop_front()
			if node is MeshInstance3D and node.mesh:
				var m: Mesh = node.mesh
				inst.queue_free()
				return m
			for child in node.get_children():
				queue.append(child)
		inst.queue_free()
		push_warning("Tile mesh not found or has no MeshInstance: %s" % path)
		return _hex_mesh_singleton() if fallback_to_hex_mesh else null
	# Если ничего не подошло (редкий случай), вернём fallback или null.
	return _hex_mesh_singleton() if fallback_to_hex_mesh else null


func _add_multimesh_bucket(bucket_name: String, mesh: Mesh, transforms: Array, tint: Color, bucket_scale: Vector3) -> void:
	if transforms.is_empty():
		return
	var use_mesh := mesh if mesh != null else _hex_mesh_singleton()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = use_mesh
	mm.instance_count = transforms.size()
	mm.set_use_colors(true)
	for i in mm.instance_count:
		var t: Transform3D = transforms[i]
		var final_scale := Vector3(
			bucket_scale.x * tile_mesh_scale_uniform.x,
			bucket_scale.y * tile_mesh_scale_uniform.y,
			bucket_scale.z * tile_mesh_scale_uniform.z
		)
		mm.set_instance_transform(i, t.scaled(final_scale))
		mm.set_instance_color(i, tint)

	# Если это наш внутренний хекс-меш, зададим материал с vertex color.
	if use_mesh == _hex_mesh_singleton():
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		use_mesh.surface_set_material(0, mat)

	var inst := MultiMeshInstance3D.new()
	inst.name = bucket_name
	inst.multimesh = mm
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(inst)

# Храним один общий хекс-меш для fallback, чтобы не плодить копии.
var __hex_mesh_cache: Mesh
func _hex_mesh_singleton() -> Mesh:
	if __hex_mesh_cache == null:
		__hex_mesh_cache = _build_hex_mesh()
	return __hex_mesh_cache


func _precompute_heights() -> void:
	var count := map_width * map_height
	height_cache.resize(count)
	var idx := 0
	for r in range(map_height):
		for q in range(map_width):
			# Используем сырую высоту без террасирования для корректного распределения и биомов.
			height_cache[idx] = height_gen.get_height_raw(q, r, map_width, map_height)
			idx += 1

	if height_cache.size() == 0:
		water_level_runtime = height_water_level
		sand_level_runtime = height_sand_level
		mountain_level_runtime = height_grass_level
		return

	if use_quantiles:
		var sorted := height_cache.duplicate()
		sorted.sort()
		var sz := sorted.size()
		var wi := int(clamp(floor((sz - 1) * water_pct), 0.0, float(sz - 1)))
		var si := int(clamp(floor((sz - 1) * (water_pct + sand_pct)), 0.0, float(sz - 1)))
		var mi := int(clamp(floor((sz - 1) * (1.0 - mountain_pct)), 0.0, float(sz - 1)))
		water_level_runtime = sorted[wi]
		sand_level_runtime = sorted[si]
		mountain_level_runtime = sorted[mi]
	else:
		water_level_runtime = height_water_level
		sand_level_runtime = height_sand_level
		mountain_level_runtime = height_grass_level

	# Гарантируем строгий порядок порогов, чтобы диапазоны не схлопывались из-за квантования.
	var eps := 0.0005
	var min_sand_gap: float = max(shoreline_band, 0.02)
	if water_level_runtime + min_sand_gap > sand_level_runtime:
		sand_level_runtime = water_level_runtime + min_sand_gap
	if mountain_level_runtime <= sand_level_runtime + eps:
		mountain_level_runtime = sand_level_runtime + eps

	# Быстрая проверка распределения для отладки: сколько тайлов попало в каждый биом.
	var water_cnt := 0
	var shore_cnt := 0
	var sand_cnt := 0
	var grass_cnt := 0
	var rock_cnt := 0
	for h in height_cache:
		if h <= water_level_runtime:
			water_cnt += 1
		elif h <= min(sand_level_runtime, water_level_runtime + shoreline_band):
			shore_cnt += 1
		elif h <= sand_level_runtime:
			sand_cnt += 1
		elif h >= mountain_level_runtime:
			rock_cnt += 1
		else:
			grass_cnt += 1
	var total: float = float(max(1, height_cache.size()))
	print("Biome counts: water=%.2f%% shore=%.2f%% sand=%.2f%% grass=%.2f%% rock=%.2f%%" % [
		100.0 * float(water_cnt) / total,
		100.0 * float(shore_cnt) / total,
		100.0 * float(sand_cnt) / total,
		100.0 * float(grass_cnt) / total,
		100.0 * float(rock_cnt) / total
	])


func _tile_height(q: int, r: int) -> float:
	var h := _get_height(q, r)
	if _biome_for_height(h) == "water":
		return y_offset + water_plane_height
	return y_offset + height_vertical_offset + h * height_vertical_scale


func _tile_offset(q: int, r: int) -> Vector3:
	var mag := tile_jitter
	if mag <= 0.0:
		return Vector3.ZERO
	var n := sin(float(q) * 12.9898 + float(r) * 78.233) * 43758.5453
	var frac: float = n - floor(n)
	var ang: float = frac * TAU
	var dist: float = mag * frac
	return Vector3(cos(ang), 0.0, sin(ang)) * dist


func _tile_transform(q: int, r: int) -> Transform3D:
	var pos := HexUtil.axial_to_world(q, r, hex_radius) + _tile_offset(q, r)
	var y := _tile_height(q, r)
	return Transform3D(hex_basis, Vector3(pos.x, y, pos.z))
