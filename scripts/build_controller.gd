extends Node3D
class_name BuildController

const HexUtil = preload("res://scripts/hex.gd")

signal resource_selected(resource: GameResource)

@export var build_menu_path: NodePath
@export var grid_path: NodePath
@export var placement_root_path: NodePath
@export var enable_ghost_preview: bool = true
@export var ghost_alpha: float = 0.4
@export var ghost_height_offset: float = 0.02
@export var snap_to_hex: bool = true

var build_menu: BuildMenu
var selected_resource: GameResource
var ghost_instance: Node3D
var hex_radius: float = 1.0
var placement_root: Node3D


func _ready() -> void:
	build_menu = get_node_or_null(build_menu_path)
	if build_menu:
		build_menu.resource_selected.connect(_on_resource_selected)
		build_menu.build_requested.connect(_on_build_requested)

	var grid := get_node_or_null(grid_path)
	if grid != null and grid.has_method("get"):
		var value: Variant = grid.get("hex_radius")
		if typeof(value) == TYPE_FLOAT:
			hex_radius = value

	placement_root = get_node_or_null(placement_root_path)
	if placement_root == null:
		placement_root = self


func _process(_delta: float) -> void:
	if not enable_ghost_preview:
		return
	if selected_resource == null or selected_resource.scene == null:
		_clear_ghost()
		return
	if ghost_instance == null:
		_spawn_ghost()
	_update_ghost_position()


func _on_resource_selected(resource: GameResource) -> void:
	selected_resource = resource
	emit_signal("resource_selected", resource)
	if enable_ghost_preview:
		_spawn_ghost()


func _on_build_requested(resource: GameResource) -> void:
	selected_resource = resource
	emit_signal("resource_selected", resource)
	if enable_ghost_preview:
		_spawn_ghost()


func _spawn_ghost() -> void:
	_clear_ghost()
	if selected_resource == null or selected_resource.scene == null:
		return
	var inst := selected_resource.scene.instantiate()
	if inst is Node3D:
		ghost_instance = inst
	else:
		ghost_instance = Node3D.new()
		ghost_instance.add_child(inst)
	ghost_instance.name = "GhostPreview"
	ghost_instance.visible = true
	add_child(ghost_instance)
	_apply_ghost_materials(ghost_instance)


func _clear_ghost() -> void:
	if ghost_instance != null:
		ghost_instance.queue_free()
		ghost_instance = null


func _update_ghost_position() -> void:
	if ghost_instance == null:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var mouse_pos := get_viewport().get_mouse_position()
	var origin := camera.project_ray_origin(mouse_pos)
	var dir := camera.project_ray_normal(mouse_pos)
	if absf(dir.y) < 0.0001:
		return
	var t := -origin.y / dir.y
	if t <= 0.0:
		return
	var pos := origin + dir * t
	if snap_to_hex:
		pos = _snap_to_hex(pos)
	ghost_instance.global_position = pos + Vector3(0.0, ghost_height_offset, 0.0)


func _snap_to_hex(pos: Vector3) -> Vector3:
	var axial := _world_to_axial(pos)
	var rounded := _axial_round(axial)
	return HexUtil.axial_to_world(rounded.x, rounded.y, hex_radius)


func _world_to_axial(pos: Vector3) -> Vector2:
	var q := (2.0 / 3.0) * pos.x / hex_radius
	var r := (-1.0 / 3.0) * pos.x / hex_radius + (HexUtil.SQRT3 / 3.0) * pos.z / hex_radius
	return Vector2(q, r)


func _axial_round(frac: Vector2) -> Vector2i:
	var x: float = frac.x
	var z: float = frac.y
	var y: float = -x - z
	var rx: float = round(x)
	var ry: float = round(y)
	var rz: float = round(z)
	var x_diff: float = absf(rx - x)
	var y_diff: float = absf(ry - y)
	var z_diff: float = absf(rz - z)
	if x_diff > y_diff and x_diff > z_diff:
		rx = -ry - rz
	elif y_diff > z_diff:
		ry = -rx - rz
	else:
		rz = -rx - ry
	return Vector2i(int(rx), int(rz))


func _apply_ghost_materials(node: Node) -> void:
	if node is MeshInstance3D:
		_apply_mesh_ghost(node)
	for child in node.get_children():
		_apply_ghost_materials(child)


func _apply_mesh_ghost(mesh_instance: MeshInstance3D) -> void:
	if mesh_instance.mesh == null:
		return
	var surface_count := mesh_instance.mesh.get_surface_count()
	for i in range(surface_count):
		var src: Material = mesh_instance.mesh.surface_get_material(i)
		var mat := src.duplicate() if src != null else StandardMaterial3D.new()
		if mat is BaseMaterial3D:
			var base := mat as BaseMaterial3D
			base.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			base.albedo_color.a = ghost_alpha
		mesh_instance.set_surface_override_material(i, mat)


func place_selected_at_world(pos: Vector3) -> void:
	if selected_resource == null or selected_resource.scene == null:
		return
	var inst := selected_resource.scene.instantiate()
	if inst is Node3D:
		var node := inst as Node3D
		node.global_position = pos
		placement_root.add_child(node)
