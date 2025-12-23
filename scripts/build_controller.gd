extends Node3D
class_name BuildController

const HexUtil = preload("res://scripts/hex.gd")

signal resource_selected(resource: GameResource)

@export var build_menu_path: NodePath
@export var grid_path: NodePath
@export var placement_root_path: NodePath
@export var selection_badge_path: NodePath
@export var enable_ghost_preview: bool = true
@export var ghost_alpha: float = 0.4
@export var ghost_height_offset: float = 0.02
@export var snap_to_hex: bool = true
@export var placement_height_offset: float = 0.0
@export var place_on_tile_select: bool = false
@export var clear_selection_after_build: bool = true
@export var auto_spawn_fortresses: bool = true
@export var auto_spawn_fortress_count: int = 3
@export var auto_spawn_fortress_id: StringName = &"fortress"
@export var auto_spawn_fortress_min_distance: int = 4
@export var auto_spawn_knights: bool = true
@export var auto_spawn_knight_id: StringName = &"knight"
@export var knight_spawn_radius: int = 1
@export var auto_spawn_rangers: bool = true
@export var auto_spawn_ranger_id: StringName = &"ranger"
@export var ranger_spawn_radius: int = 0
@export var auto_spawn_rogues: bool = true
@export var auto_spawn_rogue_id: StringName = &"rogue"
@export var rogue_spawn_count: int = 2
@export var rogue_min_distance: int = 2
@export var building_seed: int = 0
@export var randomize_building_seed: bool = false
@export var generation_layers: Array[String] = ["fortresses", "fortress_resources", "fortress_characters", "river_characters", "rogues", "forest"]
@export var resource_spawn_radius: int = 1

var build_menu: BuildMenu
var selected_resource: GameResource
var ghost_instance: Node3D
var hex_radius: float = 1.0
var placement_root: Node3D
var grid: Node
var selection_badge
var selected_tile_axial: Vector2i = Vector2i(-1, -1)
var selected_tile_biome: String = ""
var selected_tile_surface: Vector3 = Vector3.ZERO
var occupied_tiles: Dictionary = {}
var building_rng: RandomNumberGenerator = RandomNumberGenerator.new()
var occupied_axials: Array[Vector2i] = []
var spawned_fortress_axials: Array[Vector2i] = []
const HEX_DIRS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(1, -1),
	Vector2i(0, -1),
	Vector2i(-1, 0),
	Vector2i(-1, 1),
	Vector2i(0, 1),
]


func _ready() -> void:
	build_menu = get_node_or_null(build_menu_path)
	if build_menu:
		build_menu.resource_selected.connect(_on_resource_selected)
		build_menu.build_requested.connect(_on_build_requested)

	grid = get_node_or_null(grid_path)
	if grid != null and grid.has_method("get"):
		var value: Variant = grid.get("hex_radius")
		if typeof(value) == TYPE_FLOAT:
			hex_radius = value
	if grid != null and grid.has_signal("tile_selected"):
		grid.connect("tile_selected", _on_tile_selected)

	selection_badge = get_node_or_null(selection_badge_path)

	placement_root = get_node_or_null(placement_root_path)
	if placement_root == null:
		placement_root = self
	_init_building_rng()
	call_deferred("_run_generation_layers")


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
	_try_place_selected_resource()


func _spawn_ghost() -> void:
	_clear_ghost()
	if selected_resource == null or selected_resource.scene == null:
		return
	var inst: Node = selected_resource.scene.instantiate()
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
	if grid != null and grid.has_method("get_tile_surface_position"):
		var surface: Variant = grid.call("get_tile_surface_position", rounded)
		if surface is Vector3:
			return surface
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
	var inst: Node = selected_resource.scene.instantiate()
	if inst is Node3D:
		var node := inst as Node3D
		node.global_position = pos
		placement_root.add_child(node)


func _on_tile_selected(axial: Vector2i, biome_name: String, surface_pos: Vector3) -> void:
	selected_tile_axial = axial
	selected_tile_biome = biome_name
	selected_tile_surface = surface_pos
	if build_menu != null and build_menu.has_method("set_tile_context"):
		build_menu.set_tile_context(biome_name, true)
	if build_menu != null and build_menu.has_method("clear_hint"):
		build_menu.clear_hint()
	if selection_badge != null and selection_badge.has_method("update_tile"):
		selection_badge.update_tile(axial, biome_name, surface_pos)
	if place_on_tile_select:
		_try_place_selected_resource()


func _try_place_selected_resource() -> bool:
	if selected_resource == null or selected_resource.scene == null:
		return false
	if selected_tile_axial.x < 0 or selected_tile_axial.y < 0:
		if build_menu != null and build_menu.has_method("show_hint"):
			build_menu.show_hint("Выберите клетку для размещения.")
		return false
	var placed: bool = _place_resource_on_tile(selected_resource, selected_tile_axial)
	if placed and clear_selection_after_build:
		selected_resource = null
		_clear_ghost()
	return placed


func _is_tile_allowed(resource: GameResource, biome_name: String) -> bool:
	if resource == null:
		return false
	if resource.buildable_tiles.is_empty():
		return true
	for tile in resource.buildable_tiles:
		if String(tile) == biome_name:
			return true
	return false


func _place_resource_on_tile(resource: GameResource, axial: Vector2i) -> bool:
	if resource == null or resource.scene == null:
		return false
	if _is_tile_occupied(axial):
		return false
	var biome_name: String = _get_tile_biome_name(axial)
	if biome_name.is_empty():
		return false
	if not _is_tile_allowed(resource, biome_name):
		return false
	var surface_pos: Vector3 = _get_tile_surface(axial)
	var pos: Vector3 = surface_pos + Vector3(0.0, placement_height_offset, 0.0)
	_place_resource_instance(resource, pos)
	_mark_tile_occupied(axial)
	return true


func _get_tile_biome_name(axial: Vector2i) -> String:
	if grid != null and grid.has_method("get_tile_biome_name"):
		var value: Variant = grid.call("get_tile_biome_name", axial)
		if value is String:
			return value
	return ""


func _get_tile_surface(axial: Vector2i) -> Vector3:
	if grid != null and grid.has_method("get_tile_surface_position"):
		var value: Variant = grid.call("get_tile_surface_position", axial)
		if value is Vector3:
			return value
	return HexUtil.axial_to_world(axial.x, axial.y, hex_radius)


func _place_resource_instance(resource: GameResource, pos: Vector3) -> void:
	var inst: Node = resource.scene.instantiate()
	if inst is Node3D:
		var node := inst as Node3D
		node.global_position = pos
		placement_root.add_child(node)
		return
	var wrapper := Node3D.new()
	wrapper.global_position = pos
	wrapper.add_child(inst)
	placement_root.add_child(wrapper)


func _axial_key(axial: Vector2i) -> String:
	return "%d,%d" % [axial.x, axial.y]


func _is_tile_occupied(axial: Vector2i) -> bool:
	return occupied_tiles.has(_axial_key(axial))


func _mark_tile_occupied(axial: Vector2i) -> void:
	var key := _axial_key(axial)
	if occupied_tiles.has(key):
		return
	occupied_tiles[key] = true
	occupied_axials.append(axial)


func _init_building_rng() -> void:
	building_rng = RandomNumberGenerator.new()
	if randomize_building_seed:
		building_rng.randomize()
		return
	if building_seed != 0:
		building_rng.seed = building_seed
		return
	if grid != null and grid.has_method("get"):
		var value: Variant = grid.get("height_seed")
		if typeof(value) == TYPE_INT:
			building_rng.seed = int(value)
			return
	building_rng.seed = 1


func _spawn_forest_after_buildings() -> void:
	if grid == null:
		return
	if grid.has_method("scatter_forest"):
		grid.call("scatter_forest", occupied_axials)


func _run_generation_layers() -> void:
	spawned_fortress_axials.clear()
	for layer_name: String in generation_layers:
		var layer: String = layer_name.strip_edges().to_lower()
		if layer == "fortresses":
			spawned_fortress_axials = _spawn_fortresses()
		elif layer == "fortress_resources":
			_spawn_resources_near_fortresses(spawned_fortress_axials)
		elif layer == "fortress_characters":
			_spawn_characters_near_fortresses(spawned_fortress_axials)
		elif layer == "river_characters":
			_spawn_rangers_near_rivers()
		elif layer == "rogues":
			_spawn_rogues_on_forest()
		elif layer == "forest":
			_spawn_forest_after_buildings()


func _spawn_fortresses() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not auto_spawn_fortresses:
		return result
	var fortress: GameResource = _find_resource_by_id(auto_spawn_fortress_id)
	if fortress == null:
		push_warning("Fortress resource not found: %s" % auto_spawn_fortress_id)
		return result
	result = _spawn_random_resource(fortress, auto_spawn_fortress_count, auto_spawn_fortress_min_distance)
	return result


func _spawn_resources_near_fortresses(fortresses: Array[Vector2i]) -> void:
	if fortresses.is_empty():
		return
	for fortress_axial: Vector2i in fortresses:
		_spawn_resource_near_fortress(fortress_axial)


func _spawn_resource_near_fortress(fortress_axial: Vector2i) -> void:
	var candidates: Array[Vector2i] = _neighbor_candidates(fortress_axial, resource_spawn_radius)
	if candidates.is_empty():
		return
	var scored: Array[Vector2i] = []
	for axial: Vector2i in candidates:
		if _is_tile_occupied(axial):
			continue
		var biome_name: String = _get_tile_biome_name(axial)
		if biome_name.is_empty():
			continue
		if _get_resource_candidates_for_biome(biome_name).is_empty():
			continue
		scored.append(axial)
	if scored.is_empty():
		return
	var idx: int = building_rng.randi_range(0, scored.size() - 1)
	var target: Vector2i = scored[idx]
	var biome_name: String = _get_tile_biome_name(target)
	var resources: Array[GameResource] = _get_resource_candidates_for_biome(biome_name)
	if resources.is_empty():
		return
	var res_idx: int = building_rng.randi_range(0, resources.size() - 1)
	var resource: GameResource = resources[res_idx]
	_place_resource_on_tile(resource, target)


func _spawn_characters_near_fortresses(fortresses: Array[Vector2i]) -> void:
	if not auto_spawn_knights:
		return
	if fortresses.is_empty():
		return
	var knight: GameResource = _find_resource_by_id(auto_spawn_knight_id)
	if knight == null:
		push_warning("Knight resource not found: %s" % auto_spawn_knight_id)
		return
	for fortress_axial: Vector2i in fortresses:
		_spawn_character_near_fortress(knight, fortress_axial)


func _spawn_character_near_fortress(knight: GameResource, fortress_axial: Vector2i) -> void:
	if knight == null:
		return
	var candidates: Array[Vector2i] = _neighbor_candidates(fortress_axial, max(knight_spawn_radius, 1))
	if candidates.is_empty():
		return
	var valid: Array[Vector2i] = []
	for axial in candidates:
		if _is_tile_occupied(axial):
			continue
		var biome_name := _get_tile_biome_name(axial)
		if biome_name.is_empty():
			continue
		if not _is_tile_allowed(knight, biome_name):
			continue
		valid.append(axial)
	if valid.is_empty():
		return
	var idx := building_rng.randi_range(0, valid.size() - 1)
	var target: Vector2i = valid[idx]
	_place_resource_on_tile(knight, target)


func _spawn_rangers_near_rivers() -> void:
	if not auto_spawn_rangers:
		return
	var ranger: GameResource = _find_resource_by_id(auto_spawn_ranger_id)
	if ranger == null:
		push_warning("Ranger resource not found: %s" % auto_spawn_ranger_id)
		return
	var river_components := _river_components()
	if river_components.is_empty():
		return
	for axial in river_components:
		_spawn_character_at_or_near(ranger, axial, max(ranger_spawn_radius, 0))


func _spawn_character_at_or_near(character: GameResource, axial: Vector2i, radius: int) -> void:
	if character == null:
		return
	var biome := _get_tile_biome_name(axial)
	if radius == 0 and not _is_tile_occupied(axial) and not biome.is_empty() and _is_tile_allowed(character, biome):
		_place_resource_on_tile(character, axial)
		return
	var candidates := _neighbor_candidates(axial, max(radius, 1))
	var valid: Array[Vector2i] = []
	for pos in candidates:
		if _is_tile_occupied(pos):
			continue
		var b := _get_tile_biome_name(pos)
		if b.is_empty():
			continue
		if not _is_tile_allowed(character, b):
			continue
		valid.append(pos)
	if valid.is_empty():
		return
	var idx := building_rng.randi_range(0, valid.size() - 1)
	var target: Vector2i = valid[idx]
	_place_resource_on_tile(character, target)


func _river_components() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if grid == null or not grid.has_method("get"):
		return result
	var mask_var: Variant = grid.get("river_mask")
	if typeof(mask_var) != TYPE_PACKED_INT32_ARRAY:
		return result
	var river_mask: PackedInt32Array = mask_var
	if river_mask.is_empty():
		return result
	var width: int = 0
	var height: int = 0
	var w_val: Variant = grid.get("map_width")
	var h_val: Variant = grid.get("map_height")
	if typeof(w_val) == TYPE_INT:
		width = int(w_val)
	if typeof(h_val) == TYPE_INT:
		height = int(h_val)
	if width <= 0 or height <= 0:
		return result

	var visited: Dictionary = {}
	for r in range(height):
		for q in range(width):
			var idx := r * width + q
			if idx < 0 or idx >= river_mask.size():
				continue
			if river_mask[idx] == 0:
				continue
			var axial := Vector2i(q, r)
			if visited.has(axial):
				continue
			var comp := _flood_fill_river(axial, width, height, river_mask, visited)
			if comp.is_empty():
				continue
			result.append(comp[0])
	return result


func _flood_fill_river(start: Vector2i, width: int, height: int, river_mask: PackedInt32Array, visited: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var stack: Array[Vector2i] = [start]
	while not stack.is_empty():
		var cur: Vector2i = stack.pop_back()
		if visited.has(cur):
			continue
		visited[cur] = true
		out.append(cur)
		var idx := cur.y * width + cur.x
		if idx < 0 or idx >= river_mask.size():
			continue
		var mask := river_mask[idx]
		for dir in range(HEX_DIRS.size()):
			var nq := cur.x + HEX_DIRS[dir].x
			var nr := cur.y + HEX_DIRS[dir].y
			if nq < 0 or nq >= width or nr < 0 or nr >= height:
				continue
			var n_idx := nr * width + nq
			if n_idx < 0 or n_idx >= river_mask.size():
				continue
			if river_mask[n_idx] == 0:
				continue
			var opposite := (dir + 3) % 6
			var connected := ((mask & (1 << dir)) != 0) or ((river_mask[n_idx] & (1 << opposite)) != 0)
			if connected:
				stack.append(Vector2i(nq, nr))
	return out


func _spawn_rogues_on_forest() -> void:
	if not auto_spawn_rogues:
		return
	var rogue: GameResource = _find_resource_by_id(auto_spawn_rogue_id)
	if rogue == null:
		push_warning("Rogue resource not found: %s" % auto_spawn_rogue_id)
		return
	var candidates: Array[Vector2i] = []
	var width: int = 0
	var height: int = 0
	if grid != null and grid.has_method("get"):
		var w_val: Variant = grid.get("map_width")
		var h_val: Variant = grid.get("map_height")
		if typeof(w_val) == TYPE_INT:
			width = int(w_val)
		if typeof(h_val) == TYPE_INT:
			height = int(h_val)
	if width <= 0 or height <= 0:
		return
	for r in range(height):
		for q in range(width):
			var axial := Vector2i(q, r)
			if _is_tile_occupied(axial):
				continue
			var biome := _get_tile_biome_name(axial)
			if biome != "plains":
				continue
			if not _is_tile_allowed(rogue, biome):
				continue
			candidates.append(axial)
	if candidates.is_empty():
		return
	var to_spawn: int = clampi(rogue_spawn_count, 0, candidates.size())
	var placed: Array[Vector2i] = []
	var pool := candidates.duplicate()
	while placed.size() < to_spawn and not pool.is_empty():
		var idx := building_rng.randi_range(0, pool.size() - 1)
		var axial: Vector2i = pool[idx]
		pool.remove_at(idx)
		if rogue_min_distance > 0 and not _is_far_enough(axial, placed, rogue_min_distance):
			continue
		_place_resource_on_tile(rogue, axial)
		placed.append(axial)


func _neighbor_candidates(center: Vector2i, radius: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var r: int = max(radius, 1)
	if r == 1:
		for dir: Vector2i in HEX_DIRS:
			result.append(center + dir)
		return result
	for q in range(-r, r + 1):
		for s in range(-r, r + 1):
			var rr: int = -q - s
			if max(abs(q), max(abs(s), abs(rr))) > r:
				continue
			if q == 0 and s == 0:
				continue
			result.append(Vector2i(center.x + q, center.y + s))
	return result


func _get_resource_candidates_for_biome(biome_name: String) -> Array[GameResource]:
	var resources: Array[GameResource] = []
	if build_menu == null:
		return resources
	for res in build_menu.get_all_resources():
		if res == null:
			continue
		if res.category != "resource":
			continue
		if res.can_build_on(biome_name):
			resources.append(res)
	return resources


func _find_resource_by_id(resource_id: StringName) -> GameResource:
	if build_menu != null and build_menu.has_method("get_all_resources"):
		for res in build_menu.get_all_resources():
			if res != null and res.id == resource_id:
				return res
	if build_menu != null:
		for res in build_menu.resources:
			if res != null and res.id == resource_id:
				return res
		for res in build_menu.buildings:
			if res != null and res.id == resource_id:
				return res
	return null


func _spawn_random_resource(resource: GameResource, count: int, min_distance: int = 0) -> Array[Vector2i]:
	if resource == null or grid == null:
		return []
	var width: int = 0
	var height: int = 0
	if grid.has_method("get"):
		var w_val: Variant = grid.get("map_width")
		var h_val: Variant = grid.get("map_height")
		if typeof(w_val) == TYPE_INT:
			width = int(w_val)
		if typeof(h_val) == TYPE_INT:
			height = int(h_val)
	if width <= 0 or height <= 0:
		return []

	var candidates: Array[Vector2i] = []
	for r in range(height):
		for q in range(width):
			var axial := Vector2i(q, r)
			if _is_tile_occupied(axial):
				continue
			var biome_name: String = _get_tile_biome_name(axial)
			if biome_name.is_empty():
				continue
			if not _is_tile_allowed(resource, biome_name):
				continue
			candidates.append(axial)

	var to_spawn: int = min(count, candidates.size())
	if to_spawn <= 0:
		return []

	var base_candidates: Array[Vector2i] = candidates.duplicate()
	var remaining: Array[Vector2i] = base_candidates.duplicate()
	var placed_axials: Array[Vector2i] = []
	var min_dist: int = max(min_distance, 0)

	while placed_axials.size() < to_spawn and not remaining.is_empty():
		var idx: int = building_rng.randi_range(0, remaining.size() - 1)
		var axial: Vector2i = remaining[idx]
		remaining.remove_at(idx)
		if min_dist > 0 and not _is_far_enough(axial, placed_axials, min_dist):
			continue
		if _place_resource_on_tile(resource, axial):
			placed_axials.append(axial)

	if placed_axials.size() < to_spawn and min_dist > 0:
		var fallback: Array[Vector2i] = []
		for axial: Vector2i in base_candidates:
			if _is_axial_in_list(axial, placed_axials):
				continue
			fallback.append(axial)
		while placed_axials.size() < to_spawn and not fallback.is_empty():
			var idx: int = building_rng.randi_range(0, fallback.size() - 1)
			var axial: Vector2i = fallback[idx]
			fallback.remove_at(idx)
			if _place_resource_on_tile(resource, axial):
				placed_axials.append(axial)
	return placed_axials


func _is_far_enough(axial: Vector2i, placed: Array[Vector2i], min_distance: int) -> bool:
	for other: Vector2i in placed:
		if _axial_distance(axial, other) < min_distance:
			return false
	return true


func _axial_distance(a: Vector2i, b: Vector2i) -> int:
	var dq: int = abs(a.x - b.x)
	var dr: int = abs(a.y - b.y)
	var ds: int = abs((-a.x - a.y) - (-b.x - b.y))
	return max(dq, max(dr, ds))


func _is_axial_in_list(axial: Vector2i, list: Array[Vector2i]) -> bool:
	for other: Vector2i in list:
		if other == axial:
			return true
	return false
