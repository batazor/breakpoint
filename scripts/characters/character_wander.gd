extends "res://scripts/characters/character_animator.gd"
class_name CharacterWander

const HexUtil = preload("res://scripts/hex.gd")
const InterestNavigation = preload("res://scripts/ai/interest_navigation.gd")

@export var grid_path: NodePath
@export var move_speed: float = 2.5
@export var step_interval: float = 3.0
@export var arrive_tolerance: float = 0.05
@export var height_offset: float = 0.0
@export var hex_radius: float = 1.0
@export var prefer_resources: bool = false
@export var prefer_castles: bool = false
@export var prefer_forest: bool = false
@export var resource_bonus: float = 0.6
@export var castle_bonus: float = 0.5
@export var forest_bonus: float = 0.4
@export var attractor_radius: int = 3
@export var attractor_decay: float = 0.2
@export var faction_id: StringName = &""

var _grid: Node
var _nav: InterestNavigation
var _current_axial: Vector2i = Vector2i(-1, -1)
var _target_axial: Vector2i = Vector2i(-1, -1)
var _target_pos: Vector3 = Vector3.ZERO
var _time_accum: float = 0.0
var _resource_targets: Array[Vector2i] = []
var _castle_targets: Array[Vector2i] = []
var _occupant_id: int = 0


func _ready() -> void:
	super._ready()
	_grid = get_node_or_null(grid_path)
	_occupant_id = get_instance_id()
	_init_hex_radius_from_grid()
	_setup_navigation()
	_set_initial_cell()


func _physics_process(delta: float) -> void:
	if _target_axial == Vector2i(-1, -1):
		_target_pos = global_position
		_target_axial = _current_axial

	_move_toward_target(delta)
	_time_accum += delta
	if _time_accum >= step_interval:
		_time_accum = 0.0
		_pick_next()


func set_grid_path(path: NodePath) -> void:
	grid_path = path
	_grid = get_node_or_null(grid_path)
	if _nav != null:
		_nav.grid_path = grid_path


func set_hex_radius(value: float) -> void:
	hex_radius = max(0.01, value)


func set_goal(axial: Vector2i) -> void:
	if _nav != null:
		_nav.set_goal(axial)


func set_faction_id(id: StringName) -> void:
	faction_id = id
	set_meta("faction_id", id)


func set_resource_targets(targets: Array[Vector2i]) -> void:
	_resource_targets = targets.duplicate()


func set_castle_targets(targets: Array[Vector2i]) -> void:
	_castle_targets = targets.duplicate()


func _setup_navigation() -> void:
	_nav = InterestNavigation.new()
	_nav.grid_path = grid_path
	add_child(_nav)


func _set_initial_cell() -> void:
	_current_axial = _round_world_to_axial(global_position)
	_target_axial = _current_axial
	if _nav != null:
		_nav.set_current_cell(_current_axial)
	_target_pos = _axial_to_world(_current_axial)
	global_position = _target_pos
	_occupy(_current_axial)


func _pick_next() -> void:
	if _nav == null:
		return
	var neighbors: Array[Dictionary] = _nav.neighbor_context_from_grid(_current_axial)
	neighbors = neighbors.filter(func(ctx: Dictionary) -> bool:
		var ax: Vector2i = ctx.get("axial", _current_axial)
		if ctx.get("biome", "") == "water":
			return false
		if _is_occupied(ax) and ax != _current_axial:
			return false
		return true)
	for ctx in neighbors:
		var axial: Vector2i = ctx.get("axial", _current_axial)
		var biome: String = ctx.get("biome", "")
		ctx["utility"] = float(ctx.get("utility", 0.0)) + _preference_utility(axial, biome)
	if neighbors.is_empty():
		return
	var choice: Dictionary = _nav.suggest_next(neighbors)
	if choice.is_empty():
		return
	var next_axial: Vector2i = choice.get("axial", _current_axial)
	_target_axial = next_axial
	_target_pos = _axial_to_world(_target_axial)


func _move_toward_target(delta: float) -> void:
	var diff: Vector3 = _target_pos - global_position
	diff.y = _target_pos.y - global_position.y
	var dist: float = diff.length()
	if dist <= arrive_tolerance:
		_on_reached_target()
		return
	var dir: Vector3 = diff.normalized()
	global_position += dir * move_speed * delta


func _on_reached_target() -> void:
	global_position = _target_pos
	if _current_axial != _target_axial:
		_vacate(_current_axial)
		_current_axial = _target_axial
		_occupy(_current_axial)
		if _nav != null:
			_nav.set_current_cell(_current_axial)


func _axial_to_world(axial: Vector2i) -> Vector3:
	if _grid != null and _grid.has_method("get_tile_surface_position"):
		var value: Variant = _grid.call("get_tile_surface_position", axial)
		if value is Vector3:
			return (value as Vector3) + Vector3(0.0, height_offset, 0.0)
	var pos := HexUtil.axial_to_world(axial.x, axial.y, hex_radius)
	return pos + Vector3(0.0, height_offset, 0.0)


func _round_world_to_axial(pos: Vector3) -> Vector2i:
	var frac := _world_to_axial(pos)
	return _axial_round(frac)


func _world_to_axial(pos: Vector3) -> Vector2:
	var q: float = (2.0 / 3.0) * pos.x / hex_radius
	var r: float = (-1.0 / 3.0) * pos.x / hex_radius + (HexUtil.SQRT3 / 3.0) * pos.z / hex_radius
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


func _init_hex_radius_from_grid() -> void:
	if _grid == null:
		return
	if _grid.has_method("get"):
		var value: Variant = _grid.get("hex_radius")
		if typeof(value) == TYPE_FLOAT:
			hex_radius = float(value)


func _preference_utility(axial: Vector2i, biome: String) -> float:
	var score: float = 0.0
	if prefer_forest and _is_forest(axial, biome):
		score += forest_bonus
	if prefer_resources and not _resource_targets.is_empty():
		var d_res := _closest_distance(axial, _resource_targets)
		score += _attractor_score(d_res, resource_bonus)
	if prefer_castles and not _castle_targets.is_empty():
		var d_castle := _closest_distance(axial, _castle_targets)
		score += _attractor_score(d_castle, castle_bonus)
	return score


func _closest_distance(axial: Vector2i, targets: Array[Vector2i]) -> int:
	var best := INF
	for t in targets:
		var d := _hex_distance(axial, t)
		if d < best:
			best = d
	return best


func _attractor_score(dist: int, base_bonus: float) -> float:
	if dist < 0 or dist > attractor_radius:
		return 0.0
	return max(0.0, base_bonus - attractor_decay * float(dist))


func _is_forest(axial: Vector2i, biome: String) -> bool:
	if _grid != null and _grid.has_method("is_forest_tile"):
		return _grid.call("is_forest_tile", axial)
	# Fallback: plains as weak forest proxy
	return biome == "plains"


func _hex_distance(a: Vector2i, b: Vector2i) -> int:
	var dq: int = abs(a.x - b.x)
	var dr: int = abs(a.y - b.y)
	var ds: int = abs((-a.x - a.y) - (-b.x - b.y))
	return max(dq, max(dr, ds))


func _is_occupied(axial: Vector2i) -> bool:
	if _grid != null and _grid.has_method("is_character_tile_occupied"):
		return _grid.call("is_character_tile_occupied", axial)
	return false


func _occupy(axial: Vector2i) -> void:
	if _grid != null and _grid.has_method("request_character_occupy"):
		_grid.call("request_character_occupy", axial, _occupant_id)


func _vacate(axial: Vector2i) -> void:
	if _grid != null and _grid.has_method("vacate_character_tile"):
		_grid.call("vacate_character_tile", axial, _occupant_id)


func _exit_tree() -> void:
	_vacate(_current_axial)

