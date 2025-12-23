extends Node3D

const HexUtil = preload("res://scripts/hex.gd")
const WorldGeneratorScript = preload("res://scripts/world_generator.gd")
const HexGridTileSides = preload("res://scripts/hex_grid/hex_grid_tile_sides.gd")
const HexGridRivers = preload("res://scripts/hex_grid/hex_grid_rivers.gd")
const HexGridForest = preload("res://scripts/hex_grid/hex_grid_forest.gd")
const HexGridHighlight = preload("res://scripts/hex_grid/hex_grid_highlight.gd")
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
@export_file("*.glb", "*.gltf") var river_mesh_a_path: String = "res://assets/tiles/rivers/hex_river_A.gltf"
@export_file("*.glb", "*.gltf") var river_mesh_a_curvy_path: String = "res://assets/tiles/rivers/hex_river_A_curvy.gltf"
@export_file("*.glb", "*.gltf") var river_mesh_b_path: String = "res://assets/tiles/rivers/hex_river_B.gltf"
@export_file("*.glb", "*.gltf") var river_mesh_c_path: String = "res://assets/tiles/rivers/hex_river_C.gltf"
@export_file("*.glb", "*.gltf") var river_mesh_d_path: String = "res://assets/tiles/rivers/hex_river_D.gltf"
@export_file("*.glb", "*.gltf") var river_mesh_e_path: String = "res://assets/tiles/rivers/hex_river_E.gltf"
@export_file("*.glb", "*.gltf") var river_mesh_f_path: String = "res://assets/tiles/rivers/hex_river_F.gltf"
@export_file("*.glb", "*.gltf") var river_mesh_g_path: String = "res://assets/tiles/rivers/hex_river_G.gltf"
@export_file("*.glb", "*.gltf") var river_mesh_h_path: String = "res://assets/tiles/rivers/hex_river_H.gltf"
@export_file("*.glb", "*.gltf") var river_mesh_i_path: String = "res://assets/tiles/rivers/hex_river_I.gltf"
@export_file("*.glb", "*.gltf") var river_mesh_j_path: String = "res://assets/tiles/rivers/hex_river_J.gltf"
@export_file("*.glb", "*.gltf") var river_mesh_k_path: String = "res://assets/tiles/rivers/hex_river_K.gltf"
@export_file("*.glb", "*.gltf") var river_mesh_l_path: String = "res://assets/tiles/rivers/hex_river_L.gltf"
@export_file("*.glb", "*.gltf") var river_mesh_crossing_a_path: String = "res://assets/tiles/rivers/hex_river_crossing_A.gltf"
@export_file("*.glb", "*.gltf") var river_mesh_crossing_b_path: String = "res://assets/tiles/rivers/hex_river_crossing_B.gltf"
@export var use_model_height_artifact: bool = true
@export var model_height_artifact_path: String = "res://artifacts/model_heights.json"
@export var model_height_reference_path: String = "res://assets/tiles/hex_forest.gltf.glb"
@export_enum("top", "base", "center") var model_height_align_mode: String = "top"
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

@export var river_enabled: bool = true
@export var river_count: int = 4
@export var river_min_length: int = 6
@export var river_max_length: int = 28
@export_range(0.0, 1.0, 0.01) var river_source_min_height: float = 0.7
@export_range(0.0, 1.0, 0.01) var river_uphill_tolerance: float = 0.03
@export var river_allow_merge: bool = true
@export var river_seed: int = 0
@export var randomize_river_seed: bool = false
@export var river_height_offset: float = 0.01
@export var river_mesh_scale: Vector3 = Vector3.ONE
@export var river_mesh_tint: Color = Color(1.0, 1.0, 1.0)
@export var river_generation_attempts: int = 16

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
var mesh_height_offset_cache: Dictionary = {}
var model_height_data: Dictionary = {}
var model_height_loaded: bool = false
var tile_instance_map: Array = []
var multimesh_bucket_instances: Dictionary = {}
var river_bucket_instances: Dictionary = {}
var mesh_instances: Array = []
var hover_axial: Vector2i = Vector2i(-1, -1)
var selection_axial: Vector2i = Vector2i(-1, -1)
var _left_was_down: bool = false
var _last_mouse_pos: Vector2 = Vector2(-1, -1)
var tile_sides: HexGridTileSides
var rivers: HexGridRivers
var forest: HexGridForest
var highlight: HexGridHighlight
var river_mask: PackedInt32Array = PackedInt32Array()


func _ready() -> void:
	set_process(true)
	_init_systems()
	bounds_rect = HexUtil.bounds_for_rect(map_width, map_height, hex_radius)
	collision_root = Node3D.new()
	collision_root.name = "CollisionRoot"
	add_child(collision_root)
	_init_world_generator()
	_precompute_heights()
	_ensure_highlight_material()
	_ensure_overlay_indicators()
	regenerate_grid()


func regenerate_grid() -> void:
	_clear_children()
	_init_systems()
	_init_world_generator()
	_precompute_heights()
	_generate_rivers()
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
	if rivers != null:
		rivers.clear()
	else:
		river_bucket_instances.clear()
		river_mask.resize(0)
	hover_axial = Vector2i(-1, -1)
	selection_axial = Vector2i(-1, -1)
	if highlight != null:
		highlight.update_selection_indicator(Vector2i(-1, -1), selection_color, selection_emission_energy)
		highlight.update_hover_indicator(Vector2i(-1, -1), hover_color, hover_emission_energy)
	if forest != null:
		forest.clear()
	mesh_height_offset_cache.clear()
	model_height_data.clear()
	model_height_loaded = false


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
	var overlay := _ensure_highlight_material()
	if overlay != null:
		multimesh_instance.material_overlay = overlay
	add_child(multimesh_instance)
	_build_river_multimesh()


func _build_multimesh_per_biome() -> void:
	var mesh_water := _load_tile_mesh(tile_mesh_water_path)
	var mesh_sand := _load_tile_mesh(tile_mesh_sand_path)
	var mesh_grass := _load_tile_mesh(tile_mesh_grass_path)
	var mesh_rock := _load_tile_mesh(tile_mesh_rock_path)
	var river_meshes := {
		"A": _load_tile_mesh(river_mesh_a_path),
		"A_curvy": _load_tile_mesh(river_mesh_a_curvy_path),
		"B": _load_tile_mesh(river_mesh_b_path),
		"C": _load_tile_mesh(river_mesh_c_path),
		"D": _load_tile_mesh(river_mesh_d_path),
		"E": _load_tile_mesh(river_mesh_e_path),
		"F": _load_tile_mesh(river_mesh_f_path),
		"G": _load_tile_mesh(river_mesh_g_path),
		"H": _load_tile_mesh(river_mesh_h_path),
		"I": _load_tile_mesh(river_mesh_i_path),
		"J": _load_tile_mesh(river_mesh_j_path),
		"K": _load_tile_mesh(river_mesh_k_path),
		"L": _load_tile_mesh(river_mesh_l_path),
		"crossing_A": _load_tile_mesh(river_mesh_crossing_a_path),
		"crossing_B": _load_tile_mesh(river_mesh_crossing_b_path),
	}
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

			if biome == WorldGeneratorScript.Biome.PLAINS and rivers != null and river_enabled:
				var river_info: Dictionary = rivers.get_mesh_info(q, r)
				if not river_info.is_empty():
					var river_variant: String = river_info["variant"]
					var river_mesh: Mesh = river_meshes.get(river_variant, null)
					if river_mesh != null:
						mesh = river_mesh
						tint = river_mesh_tint
						scale = river_mesh_scale
						key = "river_" + river_variant
						rotation_steps = int(river_info["rotation"])

			if not key.begins_with("river_"):
				rotation_steps = tile_sides.rotation_from_side_map(key, _neighbor_water_mask(q, r), rotation_steps)
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

	# Rivers are treated as tile variants, not overlays.


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
	tile_sides.load_patterns(TILE_SIDES_PATH)
	if tile_sides.patterns.is_empty():
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
		if not tile_sides.patterns.has(key):
			continue
		var pattern: Array = tile_sides.patterns[key]
		var rot := tile_sides.match_pattern(pattern, neighbor_types)
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


func _init_tile_sides() -> void:
	if tile_sides == null:
		tile_sides = HexGridTileSides.new()
	tile_sides.load_side_map(tile_sides_yaml_path)


func _init_systems() -> void:
	_init_tile_sides()
	if rivers == null:
		rivers = HexGridRivers.new(self)
	if forest == null:
		forest = HexGridForest.new(self)
	if highlight == null:
		highlight = HexGridHighlight.new(self)


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


func _tile_mesh_key_and_rotation(q: int, r: int) -> Dictionary:
	var biome := _tile_biome(q, r)
	var rotation_steps := 0
	var key := "water"

	if biome == WorldGeneratorScript.Biome.PLAINS and rivers != null and river_enabled:
		var river_info: Dictionary = rivers.get_mesh_info(q, r)
		if not river_info.is_empty():
			var river_variant: String = river_info["variant"]
			key = "river_" + river_variant
			rotation_steps = int(river_info["rotation"])
			return {
				"key": key,
				"rotation_steps": rotation_steps,
				"rotation_deg": float(rotation_steps) * rad_to_deg(ROT_STEP),
			}

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

	rotation_steps = tile_sides.rotation_from_side_map(key, _neighbor_water_mask(q, r), rotation_steps)
	return {
		"key": key,
		"rotation_steps": rotation_steps,
		"rotation_deg": float(rotation_steps) * rad_to_deg(ROT_STEP),
	}


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
			if info.has("transform"):
				var body_t: Transform3D = info["transform"]
				body.position = body_t.origin
			else:
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


func scatter_forest(blocked_tiles: Array[Vector2i] = []) -> void:
	_init_systems()
	if forest != null:
		forest.scatter(blocked_tiles)


func _generate_rivers() -> void:
	_init_systems()
	if rivers != null:
		rivers.generate()


func _build_river_multimesh() -> void:
	if use_tile_meshes:
		return
	_init_systems()
	if rivers != null:
		rivers.build_multimesh()


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
	if highlight != null:
		highlight.update_selection_indicator(selection_axial, selection_color, selection_emission_energy)
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
	if highlight != null:
		highlight.update_hover_indicator(hover_axial, hover_color, hover_emission_energy)


func _hide_hover() -> void:
	if hover_axial == Vector2i(-1, -1):
		return
	var prev := hover_axial
	hover_axial = Vector2i(-1, -1)
	_refresh_highlight(prev)
	if highlight != null:
		highlight.update_hover_indicator(hover_axial, hover_color, hover_emission_energy)


func _refresh_highlight(axial: Vector2i) -> void:
	if highlight != null:
		highlight.refresh(axial, selection_axial, hover_axial)


func _ensure_overlay_indicators() -> void:
	_init_systems()
	if highlight != null:
		highlight.ensure_overlay_indicators()


func _tile_render_info(q: int, r: int) -> Dictionary:
	if highlight == null:
		return {}
	return highlight.tile_render_info(q, r)


func _ensure_highlight_material() -> ShaderMaterial:
	_init_systems()
	if highlight == null:
		return null
	return highlight.get_material()


func _sync_highlight_shader_params() -> void:
	if highlight != null:
		highlight.sync_shader_params()


func _ensure_mesh_highlight(mesh: Mesh) -> void:
	_init_systems()
	if highlight != null:
		highlight.ensure_mesh_highlight(mesh)


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
		var m: Mesh = res
		_cache_mesh_height_offset(m, path)
		return m
	if res is PackedScene:
		var inst: Node = res.instantiate()
		if inst is MeshInstance3D and inst.mesh:
			var m: Mesh = inst.mesh
			inst.queue_free()
			_cache_mesh_height_offset(m, path)
			return m
		# поиск первого MeshInstance3D в сцене
		var queue: Array[Node] = [inst]
		while not queue.is_empty():
			var node: Node = queue.pop_front()
			if node is MeshInstance3D and node.mesh:
				var m: Mesh = node.mesh
				inst.queue_free()
				_cache_mesh_height_offset(m, path)
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
	var mesh_offset := _mesh_height_offset(use_mesh)
	for i in mm.instance_count:
		var t: Transform3D = transforms[i]
		if not is_zero_approx(mesh_offset):
			t.origin.y += mesh_offset
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
	var overlay := _ensure_highlight_material()
	if overlay != null:
		inst.material_overlay = overlay
	add_child(inst)
	return inst

# Храним один общий хекс-меш для fallback, чтобы не плодить копии.
var __hex_mesh_cache: Mesh
func _hex_mesh_singleton() -> Mesh:
	if __hex_mesh_cache == null:
		__hex_mesh_cache = _build_hex_mesh()
	return __hex_mesh_cache


func _ensure_model_height_data() -> void:
	if model_height_loaded:
		return
	model_height_loaded = true
	model_height_data.clear()
	if not use_model_height_artifact:
		return
	if model_height_artifact_path.is_empty():
		return
	var file := FileAccess.open(model_height_artifact_path, FileAccess.READ)
	if file == null:
		push_warning("Model height artifact not found: %s" % model_height_artifact_path)
		return
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Model height artifact invalid: %s" % model_height_artifact_path)
		return
	var root: Dictionary = parsed
	var models: Variant = root.get("models", [])
	if typeof(models) != TYPE_ARRAY:
		return
	var list: Array = models
	for entry_var in list:
		if typeof(entry_var) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_var
		var path: String = String(entry.get("path", ""))
		if path.is_empty():
			continue
		model_height_data[path] = entry


func _model_height_reference_entry() -> Dictionary:
	if not use_model_height_artifact:
		return {}
	_ensure_model_height_data()
	var ref_path := model_height_reference_path
	if ref_path.is_empty():
		ref_path = tile_mesh_grass_path
	if model_height_data.has(ref_path):
		return model_height_data[ref_path]
	return {}


func _mesh_height_offset_for_path(path: String) -> float:
	if not use_model_height_artifact:
		return 0.0
	if path.is_empty():
		return 0.0
	_ensure_model_height_data()
	if model_height_data.is_empty():
		return 0.0
	if not model_height_data.has(path):
		return 0.0
	var entry: Dictionary = model_height_data[path]
	var ref_entry: Dictionary = _model_height_reference_entry()
	var ref_min: float = float(ref_entry.get("min_y", -hex_height * 0.5))
	var ref_max: float = float(ref_entry.get("max_y", hex_height * 0.5))
	var min_y: float = float(entry.get("min_y", 0.0))
	var max_y: float = float(entry.get("max_y", 0.0))
	match model_height_align_mode:
		"base":
			return ref_min - min_y
		"center":
			return ((ref_min + ref_max) * 0.5) - ((min_y + max_y) * 0.5)
		_:
			return ref_max - max_y


func _cache_mesh_height_offset(mesh: Mesh, path: String) -> void:
	if mesh == null:
		return
	if mesh_height_offset_cache.has(mesh):
		return
	var offset := _mesh_height_offset_for_path(path)
	if is_zero_approx(offset):
		return
	mesh_height_offset_cache[mesh] = offset


func _mesh_height_offset(mesh: Mesh) -> float:
	if mesh == null:
		return 0.0
	if mesh_height_offset_cache.has(mesh):
		return float(mesh_height_offset_cache[mesh])
	return 0.0


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
		t["mesh_path"] = _mesh_path_for_key(t["mesh_key"])
		tiles[i] = t
	snapshot["tiles"] = tiles


func _mesh_path_for_key(key: String) -> String:
	var base_paths := {
		"water": tile_mesh_water_path,
		"sand": tile_mesh_sand_path,
		"plains": tile_mesh_grass_path,
		"mountain": tile_mesh_rock_path,
	}

	if key.begins_with("river_"):
		var variant := key.substr("river_".length(), key.length())
		var river_paths := {
			"A": river_mesh_a_path,
			"A_curvy": river_mesh_a_curvy_path,
			"B": river_mesh_b_path,
			"C": river_mesh_c_path,
			"D": river_mesh_d_path,
			"E": river_mesh_e_path,
			"F": river_mesh_f_path,
			"G": river_mesh_g_path,
			"H": river_mesh_h_path,
			"I": river_mesh_i_path,
			"J": river_mesh_j_path,
			"K": river_mesh_k_path,
			"L": river_mesh_l_path,
			"crossing_A": river_mesh_crossing_a_path,
			"crossing_B": river_mesh_crossing_b_path,
		}
		return String(river_paths.get(variant, ""))

	if key.begins_with("sand_water"):
		var variant := key.substr("sand_water".length(), key.length())
		var sand_paths := {
			"A": tile_mesh_sand_water_a_path,
			"B": tile_mesh_sand_water_b_path,
			"C": tile_mesh_sand_water_c_path,
			"D": tile_mesh_sand_water_d_path,
		}
		return String(sand_paths.get(variant, tile_mesh_sand_path))

	if key.begins_with("plains_water"):
		var variant := key.substr("plains_water".length(), key.length())
		var plains_paths := {
			"A": tile_mesh_grass_water_a_path,
			"B": tile_mesh_grass_water_b_path,
			"C": tile_mesh_grass_water_c_path,
			"D": tile_mesh_grass_water_d_path,
		}
		return String(plains_paths.get(variant, tile_mesh_grass_path))

	if key.begins_with("mountain_water"):
		var variant := key.substr("mountain_water".length(), key.length())
		var rock_paths := {
			"A": tile_mesh_rock_water_a_path,
			"B": tile_mesh_rock_water_b_path,
			"C": tile_mesh_rock_water_c_path,
			"D": tile_mesh_rock_water_d_path,
		}
		return String(rock_paths.get(variant, tile_mesh_rock_path))

	return String(base_paths.get(key, ""))


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
	var river_offset := 0.0
	if biome == WorldGeneratorScript.Biome.PLAINS and rivers != null and river_enabled and not river_mask.is_empty():
		var river_info: Dictionary = rivers.get_mesh_info(q, r)
		if not river_info.is_empty():
			river_offset = river_height_offset
	return y_offset + offset + h * scale + river_offset


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
