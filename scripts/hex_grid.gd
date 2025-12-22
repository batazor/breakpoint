extends Node3D

const HexUtils = preload("res://scripts/hex.gd")
const RAY_LENGTH := 4000.0

@export var map_width: int = 80
@export var map_height: int = 52
@export var hex_radius: float = 1.0
@export var hex_height: float = 0.25
@export var y_offset: float = 0.0
@export var use_multimesh: bool = true
@export var color_even: Color = Color(0.76, 0.81, 0.87)
@export var color_odd: Color = Color(0.70, 0.76, 0.82)

var bounds_rect: Rect2
var multimesh_instance: MultiMeshInstance3D
var collision_root: Node3D
var shared_shape: ConvexPolygonShape3D
var hex_basis: Basis = Basis(Vector3.UP, deg_to_rad(30.0))  # rotate mesh to flat-top


func _ready() -> void:
	bounds_rect = HexUtils.bounds_for_rect(map_width, map_height, hex_radius)
	collision_root = Node3D.new()
	collision_root.name = "CollisionRoot"
	add_child(collision_root)
	regenerate_grid()


func regenerate_grid() -> void:
	_clear_children()
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
			multimesh.set_instance_color(idx, color_even if ((q + r) % 2 == 0) else color_odd)
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
			mesh_instance.modulate = color_even if ((q + r) % 2 == 0) else color_odd
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
