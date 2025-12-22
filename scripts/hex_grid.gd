extends Node3D

const HexUtils = preload("res://scripts/hex.gd")
const HeightGenerator = preload("res://scripts/height_generator.gd")
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
@export_range(-1.0, 1.0, 0.01) var height_water_level: float = -0.05
@export_range(-1.0, 1.0, 0.01) var height_sand_level: float = 0.10
@export_range(-1.0, 1.0, 0.01) var height_grass_level: float = 0.55
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


func _ready() -> void:
	bounds_rect = HexUtils.bounds_for_rect(map_width, map_height, hex_radius)
	collision_root = Node3D.new()
	collision_root.name = "CollisionRoot"
	add_child(collision_root)
	_init_height_generator()
	_create_selection_indicator()
	regenerate_grid()


func regenerate_grid() -> void:
	_clear_children()
	_init_height_generator()
	bounds_rect = HexUtils.bounds_for_rect(map_width, map_height, hex_radius)
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
			var pos := HexUtils.axial_to_world(q, r, hex_radius)
			var t := Transform3D(hex_basis, Vector3(pos.x, y_offset, pos.z))
			multimesh.set_instance_transform(idx, t)
			multimesh.set_instance_color(idx, _tile_color(q, r))
			idx += 1

	multimesh_instance = MultiMeshInstance3D.new()
	multimesh_instance.name = "HexMultiMesh"
	multimesh_instance.multimesh = multimesh
	multimesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(multimesh_instance)


func _build_mesh_instances() -> void:
	# Slower than MultiMesh, but useful for debugging.
	var mesh := _build_hex_mesh()
	for r in range(map_height):
		for q in range(map_width):
			var pos := HexUtils.axial_to_world(q, r, hex_radius)
			var mesh_instance := MeshInstance3D.new()
			mesh_instance.mesh = mesh
			mesh_instance.transform = Transform3D(hex_basis, Vector3(pos.x, y_offset, pos.z))
			mesh_instance.modulate = _tile_color(q, r)
			mesh_instance.name = "Hex_%s_%s" % [q, r]
			add_child(mesh_instance)


func _build_colliders() -> void:
	if shared_shape == null:
		return

	for r in range(map_height):
		for q in range(map_width):
			var pos := HexUtils.axial_to_world(q, r, hex_radius)
			var body := StaticBody3D.new()
			body.collision_layer = 1
			body.collision_mask = 1
			body.position = Vector3(pos.x, y_offset, pos.z)
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
	return HexUtils.center_of_rect(map_width, map_height, hex_radius) + Vector3(0.0, y_offset, 0.0)


func _build_hex_shape() -> ConvexPolygonShape3D:
	var corners := HexUtils.hex_corners(hex_radius)
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
	var pos := HexUtils.axial_to_world(axial.x, axial.y, hex_radius)
	var y := y_offset + hex_height * 0.5 + selection_height * 0.5 + 0.01
	selection_indicator.transform = Transform3D(hex_basis, Vector3(pos.x, y, pos.z))
	selection_indicator.visible = true


func _get_height(q: int, r: int) -> float:
	if height_gen == null:
		return 0.0
	return height_gen.get_height(q, r, map_width, map_height)


func _tile_color(q: int, r: int) -> Color:
	if use_height_color and height_gen:
		var h := _get_height(q, r)
		return _color_from_height(h)
	return color_even if ((q + r) % 2 == 0) else color_odd


func _color_from_height(h: float) -> Color:
	var hw := height_water_level
	var hs := height_sand_level
	var hg := height_grass_level

	if h <= hw:
		return color_water
	if h <= hs:
		return _lerp_color(color_water, color_sand, _lerp01(h, hw, hs))
	if h <= hg:
		return _lerp_color(color_sand, color_grass, _lerp01(h, hs, hg))
	return _lerp_color(color_grass, color_rock, _lerp01(h, hg, 1.0))


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
