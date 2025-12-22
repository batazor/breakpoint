extends Node3D

const HexUtil = preload("res://scripts/hex.gd")
const WorldGeneratorScript = preload("res://scripts/world_generator.gd")
const RAY_LENGTH := 4000.0
const HEX_DIRS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(1, -1),
	Vector2i(0, -1),
	Vector2i(-1, 0),
	Vector2i(-1, 1),
	Vector2i(0, 1),
]
const ROT_STEP := deg_to_rad(60.0)
const TILE_SIDES_PATH := "res://tile_sides.yaml"
const DEFAULT_FOREST_SCENES: Array[PackedScene] = [
	preload("res://assets/resources/forest/forest.gltf.glb"),
	preload("res://assets/resources/forest/detail_forestA.gltf.glb"),
	preload("res://assets/resources/forest/detail_forestB.gltf.glb"),
]

signal tile_selected(axial: Vector2i, biome_name: String, surface_pos: Vector3)

@export var map_width: int = 3
@export var map_height: int = 3
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
@export_range(0.0, 1.0, 0.01) var water_pct: float = 0.45
@export_range(0.0, 1.0, 0.01) var sand_pct: float = 0.10
@export_range(0.0, 1.0, 0.01) var mountain_pct: float = 0.10
@export var use_tile_meshes: bool = true
@export_file("*.glb") var tile_mesh_water_path: String = "res://assets/tiles/hex_water.gltf.glb"
@export_file("*.glb") var tile_mesh_sand_path: String = "res://assets/tiles/hex_sand.gltf.glb"
@export_file("*.glb") var tile_mesh_grass_path: String = "res://assets/tiles/hex_forest.gltf.glb"
@export_file("*.glb") var tile_mesh_rock_path: String = "res://assets/tiles/hex_rock.gltf.glb"
@export_file("*.glb") var tile_mesh_sand_water_a_path: String = "res://assets/tiles/hex_sand_waterA_detail.gltf.glb"
@export_file("*.glb") var tile_mesh_sand_water_b_path: String = "res://assets/tiles/hex_sand_waterB_detail.gltf.glb"
@export_file("*.glb") var tile_mesh_sand_water_c_path: String = "res://assets/tiles/hex_sand_waterC_detail.gltf.glb"
@export_file("*.glb") var tile_mesh_sand_water_d_path: String = "res://assets/tiles/hex_sand_waterD_detail.gltf.glb"
@export_file("*.glb") var tile_mesh_grass_water_a_path: String = "res://assets/tiles/hex_forest_waterA_detail.gltf.glb"
@export_file("*.glb") var tile_mesh_grass_water_b_path: String = "res://assets/tiles/hex_forest_waterB_detail.gltf.glb"
@export_file("*.glb") var tile_mesh_grass_water_c_path: String = "res://assets/tiles/hex_forest_waterC_detail.gltf.glb"
@export_file("*.glb") var tile_mesh_grass_water_d_path: String = "res://assets/tiles/hex_forest_waterD_detail.gltf.glb"
@export_file("*.glb") var tile_mesh_rock_water_a_path: String = "res://assets/tiles/hex_rock_waterA_detail.gltf.glb"
@export_file("*.glb") var tile_mesh_rock_water_b_path: String = "res://assets/tiles/hex_rock_waterB_detail.gltf.glb"
@export_file("*.glb") var tile_mesh_rock_water_c_path: String = "res://assets/tiles/hex_rock_waterC_detail.gltf.glb"
@export_file("*.glb") var tile_mesh_rock_water_d_path: String = "res://assets/tiles/hex_rock_waterD_detail.gltf.glb"
@export var tile_mesh_scale_uniform: Vector3 = Vector3.ONE
@export var tile_jitter: float = 0.02
@export var tile_mesh_scale_water: Vector3 = Vector3.ONE
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
@export_range(-1.0, 1.0, 0.01) var sand_height_offset: float = 0.04
@export_range(-1.0, 1.0, 0.01) var plains_height_offset: float = 0.10
@export_range(-1.0, 2.0, 0.01) var mountain_height_offset: float = 0.20
@export_range(0.0, 3.0, 0.01) var mountain_height_scale: float = 1.45
@export var water_plane_height: float = 0.0
@export var fallback_to_hex_mesh: bool = true
@export var randomize_height_seed: bool = false
@export var debug_lock_height_seed: bool = true
@export var debug_seed_value: int = 12345
@export var save_map_snapshot: bool = true
@export var map_snapshot_path: String = "res://last_map.json"
@export var selection_color: Color = Color(1.0, 0.6, 0.2, 0.6)
@export var hover_color: Color = Color(1.0, 1.0, 0.2, 0.35)
@export var hover_emission_energy: float = 0.8
@export var selection_emission_energy: float = 1.6
@export var use_rim_highlight: bool = true
@export var rim_color: Color = Color(1.0, 1.0, 0.2)
@export var rim_power: float = 2.0
@export_range(0.0, 1.0, 0.01) var highlight_fill_strength: float = 0.25
@export_range(0.0, 1.0, 0.01) var highlight_rim_min: float = 0.2
@export var use_overlay_highlight: bool = true
@export var overlay_height: float = 0.04
@export var overlay_scale: float = 1.03
@export var overlay_offset: float = 0.02
@export_file("*.yaml", "*.yml") var tile_sides_yaml_path: String = "res://tile_sides.yaml"

@export var forest_enabled: bool = true
@export var forest_scenes: Array[PackedScene] = DEFAULT_FOREST_SCENES
@export_range(0.0, 1.0, 0.01) var forest_spawn_chance: float = 0.4
@export var forest_min_trees: int = 1
@export var forest_max_trees: int = 4
@export var forest_tile_radius: float = 0.5
@export var forest_min_distance: float = 0.4
@export var forest_scale_min: float = 0.85
@export var forest_scale_max: float = 1.15
@export var forest_random_yaw: bool = true
@export var forest_y_offset: float = 0.0
@export var forest_seed: int = 0
@export var randomize_forest_seed: bool = false
@export var forest_allowed_biomes: Array[String] = ["plains"]
@export var forest_position_attempts: int = 6

var bounds_rect: Rect2
var multimesh_instance: MultiMeshInstance3D
var collision_root: Node3D
var shared_shape: ConvexPolygonShape3D
var hex_basis: Basis = Basis.IDENTITY
var world_gen
var height_cache: PackedFloat32Array = PackedFloat32Array()
var tile_data: Array = []
var water_level_runtime: float
var sand_level_runtime: float
var mountain_level_runtime: float
var mesh_radius_cache: Dictionary = {}
var mesh_top_cache: Dictionary = {}
var mesh_height_cache: Dictionary = {}
var mesh_center_cache: Dictionary = {}
var tile_side_patterns: Dictionary = {}
var tile_sides_loaded: bool = false
var tile_instance_map: Array = []
var multimesh_bucket_instances: Dictionary = {}
var mesh_instances: Array = []
var hover_axial: Vector2i = Vector2i(-1, -1)
var selection_axial: Vector2i = Vector2i(-1, -1)
var highlight_material: ShaderMaterial
var selection_indicator: MeshInstance3D
var hover_indicator: MeshInstance3D
var overlay_mesh: Mesh
var _left_was_down: bool = false
var _last_mouse_pos: Vector2 = Vector2(-1, -1)
var tile_side_map: Dictionary = {}
var forest_root: Node3D
var forest_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var forest_positions: Array[Vector3] = []


func _ready() -> void:
	set_process(true)
	_load_tile_side_map()
	bounds_rect = HexUtil.bounds_for_rect(map_width, map_height, hex_radius)
	collision_root = Node3D.new()
	collision_root.name = "CollisionRoot"
	add_child(collision_root)
	_ensure_forest_root()
	_init_world_generator()
	_precompute_heights()
	_ensure_highlight_material()
	_ensure_overlay_indicators()
	regenerate_grid()


func regenerate_grid() -> void:
	_clear_children()
	_load_tile_side_map()
	_init_world_generator()
	_precompute_heights()
	bounds_rect = HexUtil.bounds_for_rect(map_width, map_height, hex_radius)
	shared_shape = _build_hex_shape()

	if use_multimesh:
		_build_multimesh()
	else:
		_build_mesh_instances()

	_build_colliders()


func _process(_delta: float) -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	var mouse_pos := viewport.get_mouse_position()
	if mouse_pos != _last_mouse_pos:
		_update_hover(mouse_pos)
		_last_mouse_pos = mouse_pos
	var left_down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if left_down and not _left_was_down:
		_pick_tile(mouse_pos)
	_left_was_down = left_down


func _clear_children() -> void:
	if is_instance_valid(multimesh_instance):
		multimesh_instance.queue_free()
		multimesh_instance = null

	if is_instance_valid(collision_root):
		for child in collision_root.get_children():
			child.queue_free()

	multimesh_bucket_instances.clear()
	tile_instance_map.clear()
	mesh_instances.clear()
	hover_axial = Vector2i(-1, -1)
	selection_axial = Vector2i(-1, -1)
	if selection_indicator != null:
		selection_indicator.visible = false
	if hover_indicator != null:
		hover_indicator.visible = false
	if is_instance_valid(forest_root):
		for child in forest_root.get_children():
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
	_ensure_highlight_material()

	var hex_mesh := _build_hex_mesh()

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	hex_mesh.surface_set_material(0, mat)
	_ensure_mesh_highlight(hex_mesh)

	var multimesh := MultiMesh.new()
	multimesh.set_use_colors(true)
	multimesh.set_use_custom_data(true)
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = hex_mesh
	multimesh.instance_count = map_width * map_height

	var idx := 0
	for r in range(map_height):
		for q in range(map_width):
			var t := _tile_transform(q, r)
			multimesh.set_instance_transform(idx, t)
			multimesh.set_instance_color(idx, _tile_color(q, r))
			multimesh.set_instance_custom_data(idx, Color(0.0, 0.0, 0.0, 0.0))
			idx += 1

	multimesh_instance = MultiMeshInstance3D.new()
	multimesh_instance.name = "HexMultiMesh"
	multimesh_instance.multimesh = multimesh
	multimesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	multimesh_instance.material_overlay = highlight_material
	add_child(multimesh_instance)


func _build_multimesh_per_biome() -> void:
	var mesh_water := _load_tile_mesh(tile_mesh_water_path)
	var mesh_sand := _load_tile_mesh(tile_mesh_sand_path)
	var mesh_grass := _load_tile_mesh(tile_mesh_grass_path)
	var mesh_rock := _load_tile_mesh(tile_mesh_rock_path)
	tile_instance_map.resize(map_width * map_height)
	for i in range(tile_instance_map.size()):
		tile_instance_map[i] = null
	multimesh_bucket_instances.clear()

	var sand_water_meshes := {
		"A": _load_tile_mesh(tile_mesh_sand_water_a_path),
		"B": _load_tile_mesh(tile_mesh_sand_water_b_path),
		"C": _load_tile_mesh(tile_mesh_sand_water_c_path),
		"D": _load_tile_mesh(tile_mesh_sand_water_d_path),
	}
	var grass_water_meshes := {
		"A": _load_tile_mesh(tile_mesh_grass_water_a_path),
		"B": _load_tile_mesh(tile_mesh_grass_water_b_path),
		"C": _load_tile_mesh(tile_mesh_grass_water_c_path),
		"D": _load_tile_mesh(tile_mesh_grass_water_d_path),
	}
	var rock_water_meshes := {
		"A": _load_tile_mesh(tile_mesh_rock_water_a_path),
		"B": _load_tile_mesh(tile_mesh_rock_water_b_path),
		"C": _load_tile_mesh(tile_mesh_rock_water_c_path),
		"D": _load_tile_mesh(tile_mesh_rock_water_d_path),
	}

	var buckets: Dictionary = {}
	for r in range(map_height):
		for q in range(map_width):
			var tile_idx := r * map_width + q
			var biome := _tile_biome(q, r)
			var rotation_steps := 0
			var mesh: Mesh = mesh_water
			var tint := color_water
			var scale := tile_mesh_scale_water
			var key := "water"

			if biome == WorldGeneratorScript.Biome.SAND:
				mesh = mesh_sand
				tint = color_sand
				scale = tile_mesh_scale_sand
				key = "sand"
				var transition := _water_transition_info(q, r)
				if not transition.is_empty():
					var variant: String = transition["variant"]
					var candidate: Mesh = sand_water_meshes.get(variant, null)
					if candidate != null:
						mesh = candidate
						key = "sand_water" + variant
						rotation_steps = int(transition["rotation"])
						if variant == "D":
							var neighbor_dir := _d_neighbor_dir(q, r, WorldGeneratorScript.Biome.SAND)
							if neighbor_dir >= 0:
								var nq := q + HEX_DIRS[neighbor_dir].x
								var nr := r + HEX_DIRS[neighbor_dir].y
								var neighbor_idx := nr * map_width + nq
								if tile_idx > neighbor_idx:
									rotation_steps = (rotation_steps + 3) % 6
			elif biome == WorldGeneratorScript.Biome.PLAINS:
				mesh = mesh_grass
				tint = color_grass
				scale = tile_mesh_scale_grass
				key = "plains"
				var transition := _water_transition_info(q, r)
				if not transition.is_empty():
					var variant: String = transition["variant"]
					var candidate: Mesh = grass_water_meshes.get(variant, null)
					if candidate != null:
						mesh = candidate
						key = "plains_water" + variant
						rotation_steps = int(transition["rotation"])
						if variant == "D":
							var neighbor_dir := _d_neighbor_dir(q, r, WorldGeneratorScript.Biome.PLAINS)
							if neighbor_dir >= 0:
								var nq := q + HEX_DIRS[neighbor_dir].x
								var nr := r + HEX_DIRS[neighbor_dir].y
								var neighbor_idx := nr * map_width + nq
								if tile_idx > neighbor_idx:
									rotation_steps = (rotation_steps + 3) % 6
			elif biome == WorldGeneratorScript.Biome.MOUNTAIN:
				mesh = mesh_rock
				tint = color_rock
				scale = tile_mesh_scale_rock
				key = "mountain"
				var transition := _water_transition_info(q, r)
				if not transition.is_empty():
					var variant: String = transition["variant"]
					var candidate: Mesh = rock_water_meshes.get(variant, null)
					if candidate != null:
						mesh = candidate
						key = "mountain_water" + variant
						rotation_steps = int(transition["rotation"])

			rotation_steps = _rotation_from_mesh_side_map(key, q, r, rotation_steps)
			var t := _tile_transform(q, r, rotation_steps)
			_append_bucket(buckets, key, mesh, t, tint, scale, tile_idx)

	var total := 0
	for key in buckets.keys():
		total += buckets[key]["transforms"].size()
	if total != map_width * map_height:
		push_warning("Tile distribution mismatch: %d vs %d" % [total, map_width * map_height])

	for key in buckets.keys():
		var entry: Dictionary = buckets[key]
		var bucket_name := "%sMultiMesh" % key
		var inst := _add_multimesh_bucket(bucket_name, entry["mesh"], entry["transforms"], entry["tint"], entry["scale"])
		if inst:
			multimesh_bucket_instances[key] = inst


func _append_bucket(buckets: Dictionary, key: String, mesh: Mesh, t: Transform3D, tint: Color, scale: Vector3, tile_idx: int) -> void:
	if not buckets.has(key):
		buckets[key] = {
			"mesh": mesh,
			"transforms": [],
			"tint": tint,
			"scale": scale,
		}
	var entry: Dictionary = buckets[key]
	var transforms: Array = entry["transforms"]
	var index: int = transforms.size()
	transforms.append(t)
	tile_instance_map[tile_idx] = {
		"key": key,
		"index": index,
	}
	entry["transforms"] = transforms


func _water_transition_info(q: int, r: int) -> Dictionary:
	var biome := _tile_biome(q, r)
	if biome == WorldGeneratorScript.Biome.WATER:
		return {}
	if _is_edge_tile(q, r):
		return {}
	_load_tile_sides()
	if tile_side_patterns.is_empty():
		return {}
	var biome_name := _biome_name_runtime(biome)
	var neighbor_types := _neighbor_types(q, r)
	var water_count := 0
	var same_count := 0
	for t in neighbor_types:
		if t == "water":
			water_count += 1
		elif t == biome_name:
			same_count += 1
	var land_count := 6 - water_count
	if land_count < 2 or water_count < 2:
		return {}
	if same_count < 2:
		return {}
	for variant in ["A", "B", "C", "D"]:
		var key := "%s_water%s" % [biome_name, variant]
		if not tile_side_patterns.has(key):
			continue
		var pattern: Array = tile_side_patterns[key]
		var rot := _match_tile_pattern(pattern, neighbor_types)
		if rot >= 0:
			return {"variant": variant, "rotation": rot}
	return {}


func _d_neighbor_dir(q: int, r: int, biome: int) -> int:
	for i in range(HEX_DIRS.size()):
		var nq := q + HEX_DIRS[i].x
		var nr := r + HEX_DIRS[i].y
		if nq < 0 or nq >= map_width or nr < 0 or nr >= map_height:
			continue
		if _tile_biome(nq, nr) != biome:
			continue
		var transition := _water_transition_info(nq, nr)
		if not transition.is_empty() and transition.get("variant", "") == "D":
			return i
	return -1


func _is_edge_tile(q: int, r: int) -> bool:
	return q == 0 or r == 0 or q == map_width - 1 or r == map_height - 1


func _load_tile_sides() -> void:
	if tile_sides_loaded:
		return
	tile_sides_loaded = true
	tile_side_patterns.clear()
	var file := FileAccess.open(TILE_SIDES_PATH, FileAccess.READ)
	if file == null:
		push_warning("Tile sides file not found: %s" % TILE_SIDES_PATH)
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
				tile_side_patterns[current_key] = sides.duplicate()
				reading_sides = false
	file.close()


func _neighbor_types(q: int, r: int) -> Array[String]:
	var types: Array[String] = []
	types.resize(HEX_DIRS.size())
	for i in range(HEX_DIRS.size()):
		var nq := q + HEX_DIRS[i].x
		var nr := r + HEX_DIRS[i].y
		if nq < 0 or nq >= map_width or nr < 0 or nr >= map_height:
			types[i] = "water"
			continue
		var nb := _tile_biome(nq, nr)
		types[i] = _biome_name_runtime(nb)
	return types


func _match_tile_pattern(pattern: Array, neighbor_types: Array[String]) -> int:
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


func _tile_mesh_key_and_rotation(q: int, r: int) -> Dictionary:
	var biome := _tile_biome(q, r)
	var rotation_steps := 0
	var key := "water"

	if biome == WorldGeneratorScript.Biome.SAND:
		key = "sand"
		var transition := _water_transition_info(q, r)
		if not transition.is_empty():
			var variant: String = transition["variant"]
			rotation_steps = int(transition["rotation"])
			key = "sand_water" + variant
	elif biome == WorldGeneratorScript.Biome.PLAINS:
		key = "plains"
		var transition := _water_transition_info(q, r)
		if not transition.is_empty():
			var variant: String = transition["variant"]
			rotation_steps = int(transition["rotation"])
			key = "plains_water" + variant
	elif biome == WorldGeneratorScript.Biome.MOUNTAIN:
		key = "mountain"
		var transition := _water_transition_info(q, r)
		if not transition.is_empty():
			var variant: String = transition["variant"]
			rotation_steps = int(transition["rotation"])
			key = "mountain_water" + variant

	rotation_steps = _rotation_from_mesh_side_map(key, q, r, rotation_steps)
	return {
		"key": key,
		"rotation_steps": rotation_steps,
		"rotation_deg": float(rotation_steps) * rad_to_deg(ROT_STEP),
	}


func _rotation_from_mesh_side_map(key: String, q: int, r: int, fallback_steps: int) -> int:
	if tile_side_map.is_empty():
		return fallback_steps
	if not tile_side_map.has(key):
		return fallback_steps
	var entry = tile_side_map[key]
	if entry == null or not entry.has("side"):
		return fallback_steps
	var sides: Array = entry["side"]
	if sides.size() != 6:
		return fallback_steps
	var neighbor_water := _neighbor_water_mask(q, r)
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


func _neighbor_water_mask(q: int, r: int) -> Array[bool]:
	var mask: Array[bool] = []
	for i in range(HEX_DIRS.size()):
		var nq := q + HEX_DIRS[i].x
		var nr := r + HEX_DIRS[i].y
		var is_water := false
		if nq >= 0 and nq < map_width and nr >= 0 and nr < map_height:
			is_water = _tile_biome(nq, nr) == WorldGeneratorScript.Biome.WATER
		mask.append(is_water)
	return mask


func _load_tile_side_map() -> void:
	tile_side_map.clear()
	if tile_sides_yaml_path.is_empty():
		return
	var file := FileAccess.open(tile_sides_yaml_path, FileAccess.READ)
	if file == null:
		push_warning("Failed to open tile sides yaml at %s" % tile_sides_yaml_path)
		return
	var text := file.get_as_text()
	file.close()
	tile_side_map = _parse_tile_side_yaml(text)


func _parse_tile_side_yaml(text: String) -> Dictionary:
	# Minimal YAML subset parser for the expected structure:
	# tiles:
	#   key:
	#     side:
	#       - water
	#       - mountain
	#       ...
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

		# Tile name lines (2-space indent, not more)
		if line.begins_with("  ") and not line.begins_with("    "):
			_commit_tile_to_map(result, current_tile, sides)
			current_tile = trimmed.rstrip(":")
			sides = []
			collecting_side = false
			continue

		# Nested lines under tile (4+ spaces)
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


func _build_mesh_instances() -> void:
	# Slower than MultiMesh, but useful for debugging.
	var mesh := _build_hex_mesh()
	mesh_instances.resize(map_width * map_height)
	for r in range(map_height):
		for q in range(map_width):
			var idx := r * map_width + q
			var mesh_instance := MeshInstance3D.new()
			mesh_instance.mesh = mesh
			mesh_instance.transform = _tile_transform(q, r)
			mesh_instance.modulate = _tile_color(q, r)
			mesh_instance.name = "Hex_%s_%s" % [q, r]
			add_child(mesh_instance)
			mesh_instances[idx] = mesh_instance


func _build_colliders() -> void:
	if shared_shape == null:
		return

	for r in range(map_height):
		for q in range(map_width):
			var info := _tile_render_info(q, r)
			if info.is_empty():
				continue
			var body := StaticBody3D.new()
			body.collision_layer = 1
			body.collision_mask = 1
			body.position = _tile_transform(q, r).origin
			body.set_meta("axial", Vector2i(q, r))

			var shape := CollisionShape3D.new()
			shape.shape = shared_shape
			if info.has("mesh") and info.has("transform"):
				var mesh: Mesh = info["mesh"]
				var t: Transform3D = info["transform"]
				var scale := t.basis.get_scale().abs()
				var mesh_height := _mesh_height(mesh)
				var height_scale := 1.0
				if not is_equal_approx(hex_height, 0.0):
					height_scale = mesh_height / hex_height
				shape.scale = Vector3(
					scale.x,
					scale.y * height_scale,
					scale.z
				)
				var center_y := _mesh_center_y(mesh) * scale.y
				shape.position = Vector3(0.0, center_y, 0.0)
			body.add_child(shape)

			collision_root.add_child(body)


func _unhandled_input(event: InputEvent) -> void:
	pass


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
	else:
		_hide_hover()


func _update_hover(screen_pos: Vector2) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		_hide_hover()
		return
	var origin := camera.project_ray_origin(screen_pos)
	var direction := camera.project_ray_normal(screen_pos)
	var params: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + direction * RAY_LENGTH)
	params.collide_with_areas = false
	params.collide_with_bodies = true
	params.collision_mask = 1
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(params)
	if hit.is_empty():
		_hide_hover()
		return
	var collider: Object = hit.get("collider")
	if collider and collider.has_meta("axial"):
		var axial: Vector2i = collider.get_meta("axial")
		_show_hover(axial)
	else:
		_hide_hover()


func _log_tile_debug(axial: Vector2i) -> void:
	if world_gen == null:
		return
	var biome := _tile_biome(axial.x, axial.y)
	var biome_name := _biome_name_runtime(biome)
	var h_norm := _get_height(axial.x, axial.y)
	var h_raw := h_norm
	if world_gen != null and world_gen.raw_heights.size() > 0:
		var idx := axial.y * map_width + axial.x
		if idx >= 0 and idx < world_gen.raw_heights.size():
			h_raw = world_gen.raw_heights[idx]
	var h_world := _tile_height(axial.x, axial.y)
	var info := "Tile q=%d r=%d | biome=%s | h_norm=%.4f | h_raw=%.4f | h_world=%.4f | levels (water=%.4f sand=%.4f mountain=%.4f)" \
		% [
			axial.x,
			axial.y,
			biome_name,
			h_norm,
			h_raw,
			h_world,
			water_level_runtime,
			sand_level_runtime,
			mountain_level_runtime,
		]
	print(info)


func _biome_name_runtime(biome: int) -> String:
	match biome:
		WorldGeneratorScript.Biome.WATER:
			return "water"
		WorldGeneratorScript.Biome.SAND:
			return "sand"
		WorldGeneratorScript.Biome.MOUNTAIN:
			return "mountain"
		_:
			return "plains"


func get_bounds_rect() -> Rect2:
	return bounds_rect


func get_map_center() -> Vector3:
	return HexUtil.center_of_rect(map_width, map_height, hex_radius) + Vector3(0.0, y_offset, 0.0)


func get_selected_axial() -> Vector2i:
	return selection_axial


func get_tile_biome_name(axial: Vector2i) -> String:
	if axial.x < 0 or axial.y < 0 or axial.x >= map_width or axial.y >= map_height:
		return ""
	return _biome_name_runtime(_tile_biome(axial.x, axial.y))


func get_tile_surface_position(axial: Vector2i) -> Vector3:
	if axial.x < 0 or axial.y < 0 or axial.x >= map_width or axial.y >= map_height:
		return Vector3.ZERO
	var info := _tile_render_info(axial.x, axial.y)
	if info.is_empty():
		var fallback := _tile_transform(axial.x, axial.y)
		return fallback.origin + Vector3(0.0, hex_height * 0.5, 0.0)
	var t: Transform3D = info["transform"]
	var mesh: Mesh = info["mesh"]
	var scale := t.basis.get_scale()
	var top_offset := _mesh_top_offset(mesh) * scale.y
	return Vector3(t.origin.x, t.origin.y + top_offset, t.origin.z)


func _ensure_forest_root() -> void:
	if is_instance_valid(forest_root):
		return
	forest_root = Node3D.new()
	forest_root.name = "ForestRoot"
	add_child(forest_root)


func _init_forest_rng() -> void:
	forest_rng = RandomNumberGenerator.new()
	if randomize_forest_seed:
		forest_rng.randomize()
	elif forest_seed != 0:
		forest_rng.seed = forest_seed
	else:
		forest_rng.seed = height_seed


func scatter_forest(blocked_tiles: Array[Vector2i] = []) -> void:
	if not forest_enabled:
		return
	_ensure_forest_scenes()
	if forest_scenes.is_empty():
		return
	_ensure_forest_root()
	_init_forest_rng()
	forest_positions.clear()
	if is_instance_valid(forest_root):
		for child in forest_root.get_children():
			child.queue_free()

	var blocked: Dictionary = {}
	for tile: Vector2i in blocked_tiles:
		blocked[tile] = true

	var min_count: int = max(forest_min_trees, 0)
	var max_count: int = max(forest_max_trees, min_count)

	for r in range(map_height):
		for q in range(map_width):
			if blocked.has(Vector2i(q, r)):
				continue
			if not _is_forest_biome(q, r):
				continue
			if forest_rng.randf() > forest_spawn_chance:
				continue
			var tile_pos: Vector3 = get_tile_surface_position(Vector2i(q, r))
			var count: int = forest_rng.randi_range(min_count, max_count)
			for i in range(count):
				_scatter_forest_on_tile(tile_pos)


func _scatter_forest_on_tile(tile_pos: Vector3) -> void:
	var attempts: int = max(forest_position_attempts, 1)
	for i in range(attempts):
		var offset: Vector3 = _random_forest_offset()
		var pos: Vector3 = tile_pos + offset
		if _can_place_forest(pos):
			_spawn_tree_at(pos)
			return


func _random_forest_offset() -> Vector3:
	var radius: float = max(forest_tile_radius, 0.0)
	var angle: float = forest_rng.randf() * TAU
	var dist: float = sqrt(forest_rng.randf()) * radius
	return Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)


func _can_place_forest(pos: Vector3) -> bool:
	var min_dist: float = max(forest_min_distance, 0.0)
	if min_dist <= 0.0:
		return true
	for p: Vector3 in forest_positions:
		if p.distance_to(pos) < min_dist:
			return false
	return true


func _spawn_tree_at(pos: Vector3) -> void:
	var scene: PackedScene = _pick_forest_scene()
	if scene == null:
		return
	var inst := scene.instantiate()
	var node: Node3D
	if inst is Node3D:
		node = inst
	else:
		node = Node3D.new()
		node.add_child(inst)
	node.position = pos + Vector3(0.0, forest_y_offset, 0.0)
	if forest_random_yaw:
		node.rotation.y = forest_rng.randf() * TAU
	var scale := forest_rng.randf_range(forest_scale_min, forest_scale_max)
	node.scale = Vector3.ONE * scale
	forest_root.add_child(node)
	forest_positions.append(pos)


func _pick_forest_scene() -> PackedScene:
	if forest_scenes.is_empty():
		return null
	var idx: int = forest_rng.randi_range(0, forest_scenes.size() - 1)
	var candidate: PackedScene = forest_scenes[idx]
	if candidate is PackedScene:
		return candidate
	for scene: PackedScene in forest_scenes:
		if scene is PackedScene:
			return scene
	return null


func _is_forest_biome(q: int, r: int) -> bool:
	var biome_name := _biome_name_runtime(_tile_biome(q, r))
	if forest_allowed_biomes.is_empty():
		return true
	for allowed in forest_allowed_biomes:
		if String(allowed) == biome_name:
			return true
	return false


func _ensure_forest_scenes() -> void:
	if forest_scenes.is_empty():
		forest_scenes = DEFAULT_FOREST_SCENES


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


func _show_selection(axial: Vector2i) -> void:
	if axial == selection_axial:
		return
	var prev := selection_axial
	selection_axial = axial
	_refresh_highlight(prev)
	_refresh_highlight(selection_axial)
	_update_overlay_indicator(selection_indicator, selection_axial, selection_color, selection_emission_energy)
	_log_tile_debug(axial)
	var biome_name := _biome_name_runtime(_tile_biome(axial.x, axial.y))
	var surface_pos := get_tile_surface_position(axial)
	emit_signal("tile_selected", axial, biome_name, surface_pos)


func _show_hover(axial: Vector2i) -> void:
	if axial == hover_axial:
		return
	var prev := hover_axial
	hover_axial = axial
	_refresh_highlight(prev)
	_refresh_highlight(hover_axial)
	_update_overlay_indicator(hover_indicator, hover_axial, hover_color, hover_emission_energy)


func _hide_hover() -> void:
	if hover_axial == Vector2i(-1, -1):
		return
	var prev := hover_axial
	hover_axial = Vector2i(-1, -1)
	_refresh_highlight(prev)
	_update_overlay_indicator(hover_indicator, hover_axial, hover_color, hover_emission_energy)


func _refresh_highlight(axial: Vector2i) -> void:
	if axial.x < 0 or axial.y < 0:
		return
	var is_selected := axial == selection_axial
	var is_hover := axial == hover_axial
	if not is_selected and not is_hover:
		_apply_highlight(axial, Color(0.0, 0.0, 0.0, 0.0), 0.0, false)
		return
	var color := selection_color if is_selected else hover_color
	var energy := selection_emission_energy if is_selected else hover_emission_energy
	var use_rim := use_rim_highlight
	_apply_highlight(axial, color, energy, use_rim)


func _ensure_overlay_indicators() -> void:
	if not use_overlay_highlight:
		return
	if selection_indicator != null and hover_indicator != null:
		return
	overlay_mesh = CylinderMesh.new()
	var mesh := overlay_mesh as CylinderMesh
	mesh.top_radius = hex_radius * overlay_scale
	mesh.bottom_radius = hex_radius * overlay_scale
	mesh.height = overlay_height
	mesh.radial_segments = 6
	mesh.rings = 1

	selection_indicator = MeshInstance3D.new()
	selection_indicator.name = "SelectionOverlay"
	selection_indicator.mesh = overlay_mesh
	selection_indicator.material_override = _build_overlay_material(selection_color)
	selection_indicator.visible = false
	add_child(selection_indicator)

	hover_indicator = MeshInstance3D.new()
	hover_indicator.name = "HoverOverlay"
	hover_indicator.mesh = overlay_mesh
	hover_indicator.material_override = _build_overlay_material(hover_color)
	hover_indicator.visible = false
	add_child(hover_indicator)


func _build_overlay_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.set("emission_energy_multiplier", 1.0)
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _update_overlay_indicator(indicator: MeshInstance3D, axial: Vector2i, color: Color, energy: float) -> void:
	if not use_overlay_highlight:
		if indicator != null:
			indicator.visible = false
		return
	_ensure_overlay_indicators()
	if indicator == null:
		return
	if axial.x < 0 or axial.y < 0:
		indicator.visible = false
		return
	var info := _tile_render_info(axial.x, axial.y)
	if info.is_empty():
		indicator.visible = false
		return
	var t: Transform3D = info["transform"]
	var mesh: Mesh = info["mesh"]
	var pos := t.origin
	var scale := t.basis.get_scale()
	var top_offset := _mesh_top_offset(mesh) * scale.y
	var y := pos.y + top_offset + overlay_height * 0.5 + overlay_offset
	indicator.transform = Transform3D(hex_basis, Vector3(pos.x, y, pos.z))
	indicator.visible = true
	var mat: Material = indicator.material_override
	if mat is StandardMaterial3D:
		var smat := mat as StandardMaterial3D
		smat.albedo_color = color
		_apply_emission(smat, color, energy, false)


func _tile_render_info(q: int, r: int) -> Dictionary:
	if use_multimesh:
		if use_tile_meshes:
			var idx := r * map_width + q
			if idx < 0 or idx >= tile_instance_map.size():
				return {}
			var entry = tile_instance_map[idx]
			if entry == null:
				return {}
			var key: String = entry["key"]
			var inst_idx: int = int(entry["index"])
			var inst: MultiMeshInstance3D = multimesh_bucket_instances.get(key, null)
			if inst == null or inst.multimesh == null:
				return {}
			var t := inst.multimesh.get_instance_transform(inst_idx)
			return {"transform": t, "mesh": inst.multimesh.mesh}
		else:
			if multimesh_instance == null or multimesh_instance.multimesh == null:
				return {}
			var idx := r * map_width + q
			if idx < 0 or idx >= multimesh_instance.multimesh.instance_count:
				return {}
			var t := multimesh_instance.multimesh.get_instance_transform(idx)
			return {"transform": t, "mesh": multimesh_instance.multimesh.mesh}
	else:
		var idx := r * map_width + q
		if idx < 0 or idx >= mesh_instances.size():
			return {}
		var inst: MeshInstance3D = mesh_instances[idx]
		if inst == null or inst.mesh == null:
			return {}
		return {"transform": inst.transform, "mesh": inst.mesh}


func _apply_highlight(axial: Vector2i, color: Color, energy: float, use_rim: bool) -> void:
	if use_multimesh:
		_set_multimesh_highlight(axial, color, energy, use_rim)
	else:
		_set_mesh_instance_highlight(axial, color, energy, use_rim)


func _set_multimesh_highlight(axial: Vector2i, color: Color, energy: float, use_rim: bool) -> void:
	_ensure_highlight_material()
	_sync_highlight_shader_params()
	var data := Color(color.r, color.g, color.b, max(energy, 0.0))
	var idx := axial.y * map_width + axial.x
	if use_tile_meshes:
		if idx < 0 or idx >= tile_instance_map.size():
			return
		var entry = tile_instance_map[idx]
		if entry == null:
			return
		var key: String = entry["key"]
		var inst_idx: int = int(entry["index"])
		var inst: MultiMeshInstance3D = multimesh_bucket_instances.get(key, null)
		if inst and inst.multimesh:
			inst.multimesh.set_instance_custom_data(inst_idx, data)
	else:
		if multimesh_instance and multimesh_instance.multimesh:
			if idx < 0 or idx >= multimesh_instance.multimesh.instance_count:
				return
			multimesh_instance.multimesh.set_instance_custom_data(idx, data)


func _set_mesh_instance_highlight(axial: Vector2i, color: Color, energy: float, use_rim: bool) -> void:
	var idx := axial.y * map_width + axial.x
	if idx < 0 or idx >= mesh_instances.size():
		return
	var inst: MeshInstance3D = mesh_instances[idx]
	if inst == null or inst.mesh == null:
		return
	var surface_count := inst.mesh.get_surface_count()
	if energy <= 0.0:
		for surface_idx in range(surface_count):
			inst.set_surface_override_material(surface_idx, null)
		return
	for surface_idx in range(surface_count):
		var src_mat: Material = inst.mesh.surface_get_material(surface_idx)
		var dup := src_mat.duplicate() if src_mat != null else StandardMaterial3D.new()
		_apply_emission(dup, color, energy, use_rim)
		inst.set_surface_override_material(surface_idx, dup)


func _ensure_highlight_material() -> void:
	if highlight_material != null:
		return
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, depth_draw_never, depth_test_disabled, blend_mix;

uniform vec3 rim_color = vec3(1.0, 1.0, 0.2);
uniform float rim_power = 2.0;
uniform float use_rim = 1.0;
uniform float fill_strength = 0.25;
uniform float rim_min = 0.2;

varying vec4 instance_custom;

void vertex() {
	instance_custom = INSTANCE_CUSTOM;
}

void fragment() {
	vec4 data = instance_custom;
	float strength = data.a;
	if (strength <= 0.0) {
		ALBEDO = vec3(0.0);
		EMISSION = vec3(0.0);
		ALPHA = 0.0;
		return;
	}
	float rim = 1.0;
	if (use_rim > 0.5) {
		float ndv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
		rim = mix(rim_min, 1.0, pow(1.0 - ndv, rim_power));
	}
	vec3 glow = data.rgb;
	float alpha = clamp(strength * fill_strength, 0.0, 1.0);
	alpha = max(alpha, rim_min);
	EMISSION = glow * strength * rim;
	ALBEDO = glow;
	ALPHA = alpha;
}
"""
	highlight_material = ShaderMaterial.new()
	highlight_material.shader = shader
	highlight_material.render_priority = 1
	_sync_highlight_shader_params()


func _sync_highlight_shader_params() -> void:
	if highlight_material == null:
		return
	highlight_material.set_shader_parameter("rim_color", rim_color)
	highlight_material.set_shader_parameter("rim_power", rim_power)
	highlight_material.set_shader_parameter("use_rim", 1.0 if use_rim_highlight else 0.0)
	highlight_material.set_shader_parameter("fill_strength", highlight_fill_strength)
	highlight_material.set_shader_parameter("rim_min", highlight_rim_min)


func _ensure_mesh_highlight(mesh: Mesh) -> void:
	if mesh == null:
		return
	_ensure_highlight_material()
	for surface_idx in range(mesh.get_surface_count()):
		var mat: Material = mesh.surface_get_material(surface_idx)
		if mat == null:
			mat = StandardMaterial3D.new()
			mesh.surface_set_material(surface_idx, mat)
		if mat is BaseMaterial3D:
			var base := mat as BaseMaterial3D
			if base.next_pass != highlight_material:
				base.next_pass = highlight_material


func _apply_emission(mat: Material, color: Color, energy: float, use_rim: bool) -> void:
	if not (mat is StandardMaterial3D):
		return
	var m: StandardMaterial3D = mat
	m.emission_enabled = energy > 0.0
	m.emission = color
	m.set("emission_energy_multiplier", energy)
	if use_rim:
		m.rim_enabled = true
		m.rim = 1.0
		m.set("rim_tint", rim_color)
		m.rim_power = rim_power
	else:
		m.rim_enabled = false


func _get_height(q: int, r: int) -> float:
	var idx := r * map_width + q
	if idx >= 0 and idx < height_cache.size():
		return height_cache[idx]
	if world_gen != null and idx >= 0 and idx < world_gen.heights.size():
		return world_gen.heights[idx]
	if world_gen == null or world_gen.height_gen == null:
		return 0.0
	return world_gen.height_gen.get_height(q, r, map_width, map_height)


func _tile_biome(q: int, r: int) -> int:
	var idx := r * map_width + q
	if idx < 0 or idx >= tile_data.size():
		return WorldGeneratorScript.Biome.PLAINS
	var tile = tile_data[idx]
	if tile == null:
		return WorldGeneratorScript.Biome.PLAINS
	return tile.biome


func _tile_color(q: int, r: int) -> Color:
	if use_height_color and world_gen:
		return _color_from_biome(_tile_biome(q, r))
	return color_even if ((q + r) % 2 == 0) else color_odd


func _color_from_biome(biome: int) -> Color:
	match biome:
		WorldGeneratorScript.Biome.WATER:
			return color_water
		WorldGeneratorScript.Biome.SAND:
			return color_sand
		WorldGeneratorScript.Biome.MOUNTAIN:
			return color_rock
		_:
			return color_grass


func _init_world_generator() -> void:
	world_gen = WorldGeneratorScript.new()
	var seed_to_use := height_seed
	if debug_lock_height_seed:
		seed_to_use = debug_seed_value
	elif randomize_height_seed:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		seed_to_use = int(rng.randi())
	var height_gen = world_gen.height_gen
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

	world_gen.water_pct = water_pct
	world_gen.sand_pct = sand_pct
	world_gen.mountain_pct = mountain_pct


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


func _add_multimesh_bucket(bucket_name: String, mesh: Mesh, transforms: Array, tint: Color, bucket_scale: Vector3) -> MultiMeshInstance3D:
	if transforms.is_empty():
		return null
	_ensure_highlight_material()
	var use_mesh := mesh if mesh != null else _hex_mesh_singleton()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = use_mesh
	mm.instance_count = transforms.size()
	mm.set_use_colors(true)
	mm.set_use_custom_data(true)
	var mesh_scale := _mesh_scale_factor(use_mesh)
	for i in mm.instance_count:
		var t: Transform3D = transforms[i]
		var final_scale := Vector3(
			bucket_scale.x * tile_mesh_scale_uniform.x,
			bucket_scale.y * tile_mesh_scale_uniform.y,
			bucket_scale.z * tile_mesh_scale_uniform.z
		)
		final_scale *= mesh_scale
		mm.set_instance_transform(i, t.scaled(final_scale))
		mm.set_instance_color(i, tint)
		mm.set_instance_custom_data(i, Color(0.0, 0.0, 0.0, 0.0))

	# Если это наш внутренний хекс-меш, зададим материал с vertex color.
	if use_mesh == _hex_mesh_singleton():
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		use_mesh.surface_set_material(0, mat)
	_ensure_mesh_highlight(use_mesh)

	var inst := MultiMeshInstance3D.new()
	inst.name = bucket_name
	inst.multimesh = mm
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	inst.material_overlay = highlight_material
	add_child(inst)
	return inst

# Храним один общий хекс-меш для fallback, чтобы не плодить копии.
var __hex_mesh_cache: Mesh
func _hex_mesh_singleton() -> Mesh:
	if __hex_mesh_cache == null:
		__hex_mesh_cache = _build_hex_mesh()
	return __hex_mesh_cache


func _mesh_scale_factor(mesh: Mesh) -> float:
	var radius := _mesh_circumradius(mesh)
	if radius <= 0.0:
		return 1.0
	return hex_radius / radius


func _mesh_top_offset(mesh: Mesh) -> float:
	if mesh == null:
		return hex_height * 0.5
	if mesh_top_cache.has(mesh):
		return float(mesh_top_cache[mesh])
	var aabb := mesh.get_aabb()
	var top := aabb.position.y + aabb.size.y
	if top <= 0.0:
		top = hex_height * 0.5
	mesh_top_cache[mesh] = top
	return top


func _mesh_height(mesh: Mesh) -> float:
	if mesh == null:
		return hex_height
	if mesh_height_cache.has(mesh):
		return float(mesh_height_cache[mesh])
	var aabb := mesh.get_aabb()
	var h := aabb.size.y
	if h <= 0.0:
		h = hex_height
	mesh_height_cache[mesh] = h
	return h


func _mesh_center_y(mesh: Mesh) -> float:
	if mesh == null:
		return 0.0
	if mesh_center_cache.has(mesh):
		return float(mesh_center_cache[mesh])
	var aabb := mesh.get_aabb()
	var center := aabb.position.y + aabb.size.y * 0.5
	mesh_center_cache[mesh] = center
	return center


func _mesh_circumradius(mesh: Mesh) -> float:
	if mesh == null:
		return 1.0
	if mesh_radius_cache.has(mesh):
		return float(mesh_radius_cache[mesh])
	var max_r := 0.0
	for surface_idx in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface_idx)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for v in verts:
			var r := Vector2(v.x, v.z).length()
			if r > max_r:
				max_r = r
	if max_r <= 0.0:
		max_r = 1.0
	mesh_radius_cache[mesh] = max_r
	return max_r


func _precompute_heights() -> void:
	if world_gen == null:
		height_cache = PackedFloat32Array()
		tile_data = []
		return

	world_gen.generate(map_width, map_height)
	height_cache = world_gen.heights
	tile_data = world_gen.tiles
	water_level_runtime = world_gen.water_level
	sand_level_runtime = world_gen.sand_level
	mountain_level_runtime = world_gen.mountain_level
	_maybe_save_map_snapshot()


func _maybe_save_map_snapshot() -> void:
	if not save_map_snapshot:
		return
	if world_gen == null:
		return
	if map_snapshot_path.is_empty():
		push_warning("Map snapshot path is empty, skipping save.")
		return
	var snapshot: Dictionary = world_gen.to_serializable_dict()
	_enrich_snapshot_with_mesh_info(snapshot)
	var json := JSON.stringify(snapshot, "\t")
	var file_path := map_snapshot_path
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		push_warning("Failed to open map snapshot file: %s" % file_path)
		return
	file.store_string(json)
	file.close()
	var global_path := ProjectSettings.globalize_path(file_path)
	print("Saved map snapshot to %s" % global_path)


func _enrich_snapshot_with_mesh_info(snapshot: Dictionary) -> void:
	if snapshot == null:
		return
	if not snapshot.has("tiles"):
		return
	var tiles: Array = snapshot["tiles"]
	for i in range(tiles.size()):
		var t = tiles[i]
		var q := int(t.get("q", -1))
		var r := int(t.get("r", -1))
		if q < 0 or r < 0:
			continue
		var mesh_info := _tile_mesh_key_and_rotation(q, r)
		t["mesh_key"] = mesh_info.get("key", "")
		t["rotation_steps"] = mesh_info.get("rotation_steps", 0)
		t["rotation_deg"] = mesh_info.get("rotation_deg", 0.0)
		tiles[i] = t
	snapshot["tiles"] = tiles


func _tile_height(q: int, r: int) -> float:
	var h := _get_height(q, r)
	var biome := _tile_biome(q, r)
	if biome == WorldGeneratorScript.Biome.WATER:
		return y_offset + water_plane_height
	var scale := height_vertical_scale
	var offset := height_vertical_offset
	match biome:
		WorldGeneratorScript.Biome.SAND:
			offset += sand_height_offset
		WorldGeneratorScript.Biome.PLAINS:
			offset += plains_height_offset
		WorldGeneratorScript.Biome.MOUNTAIN:
			scale *= mountain_height_scale
			offset += mountain_height_offset
	return y_offset + offset + h * scale


func _tile_offset(q: int, r: int) -> Vector3:
	var mag := tile_jitter
	if mag <= 0.0:
		return Vector3.ZERO
	var n := sin(float(q) * 12.9898 + float(r) * 78.233) * 43758.5453
	var frac: float = n - floor(n)
	var ang: float = frac * TAU
	var dist: float = mag * frac
	return Vector3(cos(ang), 0.0, sin(ang)) * dist


func _tile_transform(q: int, r: int, rotation_steps: int = 0) -> Transform3D:
	var pos := HexUtil.axial_to_world(q, r, hex_radius) + _tile_offset(q, r)
	var y := _tile_height(q, r)
	var basis := hex_basis
	if rotation_steps != 0:
		basis = hex_basis.rotated(Vector3.UP, ROT_STEP * float(rotation_steps))
	return Transform3D(basis, Vector3(pos.x, y, pos.z))
