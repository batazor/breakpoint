extends RefCounted
class_name HexGridForest

var grid
var root: Node3D
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var positions: Array[Vector3] = []


func _init(owner) -> void:
	grid = owner


func clear() -> void:
	positions.clear()
	if is_instance_valid(root):
		for child in root.get_children():
			child.queue_free()


func scatter(blocked_tiles: Array[Vector2i] = []) -> void:
	if not grid.forest_enabled:
		return
	_ensure_scenes()
	if grid.forest_scenes.is_empty():
		return
	_ensure_root()
	_init_rng()
	positions.clear()
	if is_instance_valid(root):
		for child in root.get_children():
			child.queue_free()

	var blocked: Dictionary = {}
	for tile: Vector2i in blocked_tiles:
		blocked[tile] = true

	var min_count: int = max(grid.forest_min_trees, 0)
	var max_count: int = max(grid.forest_max_trees, min_count)

	for r in range(grid.map_height):
		for q in range(grid.map_width):
			if blocked.has(Vector2i(q, r)):
				continue
			if not _is_forest_biome(q, r):
				continue
			if rng.randf() > grid.forest_spawn_chance:
				continue
			var tile_pos: Vector3 = grid.get_tile_surface_position(Vector2i(q, r))
			var count: int = rng.randi_range(min_count, max_count)
			for i in range(count):
				_scatter_on_tile(tile_pos)


func _ensure_root() -> void:
	if is_instance_valid(root):
		return
	root = Node3D.new()
	root.name = "ForestRoot"
	grid.add_child(root)


func _init_rng() -> void:
	rng = RandomNumberGenerator.new()
	if grid.randomize_forest_seed:
		rng.randomize()
	elif grid.forest_seed != 0:
		rng.seed = grid.forest_seed
	else:
		rng.seed = grid.height_seed


func _scatter_on_tile(tile_pos: Vector3) -> void:
	var attempts: int = max(grid.forest_position_attempts, 1)
	for i in range(attempts):
		var offset: Vector3 = _random_offset()
		var pos: Vector3 = tile_pos + offset
		if _can_place(pos):
			_spawn_tree(pos)
			return


func _random_offset() -> Vector3:
	var radius: float = max(grid.forest_tile_radius, 0.0)
	var angle: float = rng.randf() * TAU
	var dist: float = sqrt(rng.randf()) * radius
	return Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)


func _can_place(pos: Vector3) -> bool:
	var min_dist: float = max(grid.forest_min_distance, 0.0)
	if min_dist <= 0.0:
		return true
	for p: Vector3 in positions:
		if p.distance_to(pos) < min_dist:
			return false
	return true


func _spawn_tree(pos: Vector3) -> void:
	var scene: PackedScene = _pick_scene()
	if scene == null:
		return
	var inst: Node = scene.instantiate()
	var node: Node3D
	if inst is Node3D:
		node = inst
	else:
		node = Node3D.new()
		node.add_child(inst)
	node.position = pos + Vector3(0.0, grid.forest_y_offset, 0.0)
	if grid.forest_random_yaw:
		node.rotation.y = rng.randf() * TAU
	var scale := rng.randf_range(grid.forest_scale_min, grid.forest_scale_max)
	node.scale = Vector3.ONE * scale
	root.add_child(node)
	positions.append(pos)


func _pick_scene() -> PackedScene:
	if grid.forest_scenes.is_empty():
		return null
	var idx: int = rng.randi_range(0, grid.forest_scenes.size() - 1)
	var candidate: PackedScene = grid.forest_scenes[idx]
	if candidate is PackedScene:
		return candidate
	for scene: PackedScene in grid.forest_scenes:
		if scene is PackedScene:
			return scene
	return null


func _is_forest_biome(q: int, r: int) -> bool:
	var biome_name: String = grid._biome_name_runtime(grid._tile_biome(q, r))
	if grid.forest_allowed_biomes.is_empty():
		return true
	for allowed in grid.forest_allowed_biomes:
		if String(allowed) == biome_name:
			return true
	return false


func _ensure_scenes() -> void:
	if grid.forest_scenes.is_empty():
		grid.forest_scenes = grid.DEFAULT_FOREST_SCENES
