extends Node
class_name InterestNavigation

signal next_cell_chosen(target: Vector2i, interest: float)

const HEX_DIRS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(1, -1),
	Vector2i(0, -1),
	Vector2i(-1, 0),
	Vector2i(-1, 1),
	Vector2i(0, 1),
]

class MovementMemory:
	var recent_capacity: int = 10
	var visited_capacity: int = 200
	var recent_cells: Array[Vector2i] = []
	var visited_cells: Array[Vector2i] = []
	var visited_lookup: Dictionary = {}

	func clear() -> void:
		recent_cells.clear()
		visited_cells.clear()
		visited_lookup.clear()

	func clear_recent() -> void:
		recent_cells.clear()

	func record(axial: Vector2i) -> void:
		if recent_capacity > 0:
			if recent_cells.size() >= recent_capacity:
				recent_cells.pop_front()
			recent_cells.append(axial)
		if visited_lookup.has(axial):
			visited_cells.erase(axial)
		visited_cells.append(axial)
		visited_lookup[axial] = true
		while visited_cells.size() > visited_capacity:
			var removed: Vector2i = visited_cells.pop_front()
			visited_lookup.erase(removed)

	func is_recent(axial: Vector2i) -> bool:
		return visited_lookup.has(axial) and recent_cells.has(axial)

	func was_visited(axial: Vector2i) -> bool:
		return visited_lookup.has(axial)


@export var grid_path: NodePath
@export_range(0.0, 1.0, 0.01) var curiosity: float = 0.5
@export var novelty_weight: float = 1.0
@export var utility_weight: float = 0.6
@export var fatigue_weight: float = 0.5
@export var danger_weight: float = 0.6
@export var bias_weight: float = 0.2
@export var fatigue_factor: float = 0.1
@export var temperature: float = 1.0
@export var noise_amplitude: float = 0.1
@export var stuck_clear_after: int = 3
@export var recent_capacity: int = 10
@export var visited_capacity: int = 200

var memory := MovementMemory.new()
var rng := RandomNumberGenerator.new()
var current_cell: Vector2i = Vector2i(-1, -1)
var last_goal: Vector2i = Vector2i(-1, -1)
var last_choice: Vector2i = Vector2i(-1, -1)
var stuck_steps: int = 0


func _ready() -> void:
	rng.randomize()
	memory.recent_capacity = recent_capacity
	memory.visited_capacity = visited_capacity
	memory.clear()


func set_current_cell(axial: Vector2i) -> void:
	current_cell = axial
	memory.record(axial)


func set_goal(axial: Vector2i) -> void:
	last_goal = axial


func neighbor_context_from_grid(center: Vector2i) -> Array[Dictionary]:
	var grid := _grid()
	if grid == null:
		return []
	var out: Array[Dictionary] = []
	for dir in HEX_DIRS:
		var n_axial := center + dir
		if n_axial.x < 0 or n_axial.y < 0:
			continue
		var width_val: Variant = grid.get("map_width")
		var height_val: Variant = grid.get("map_height")
		if typeof(width_val) == TYPE_INT and typeof(height_val) == TYPE_INT:
			if n_axial.x >= int(width_val) or n_axial.y >= int(height_val):
				continue
		var biome: String = ""
		if grid.has_method("get_tile_biome_name"):
			var v: Variant = grid.call("get_tile_biome_name", n_axial)
			if v is String:
				biome = v
		var ctx: Dictionary = {"axial": n_axial, "biome": biome}
		if biome == "water":
			ctx["danger"] = 1.0
		elif biome == "mountain":
			ctx["fatigue"] = 0.5
		elif biome == "plains":
			ctx["utility"] = 0.1
		out.append(ctx)
	return out


func suggest_next(neighbors: Array) -> Dictionary:
	if neighbors.is_empty():
		return {}

	var scores: Dictionary = {}
	var novelty_w: float = novelty_weight * lerp(0.2, 1.5, clamp(curiosity, 0.0, 1.0))
	for ctx in neighbors:
		if not (ctx is Dictionary) or not ctx.has("axial"):
			continue
		var axial: Vector2i = ctx["axial"]
		var novelty_score := _novelty(axial)
		var utility := float(ctx.get("utility", 0.0))
		var fatigue := float(ctx.get("fatigue", 0.0))
		if fatigue == 0.0 and last_goal != Vector2i(-1, -1):
			fatigue = _hex_distance(axial, last_goal) * fatigue_factor
		var danger := float(ctx.get("danger", 0.0))
		var bias := float(ctx.get("personality_bias", 0.0))

		var score: float = novelty_w * novelty_score
		score += utility_weight * utility
		score -= fatigue_weight * fatigue
		score -= danger_weight * danger
		score += bias_weight * bias
		score += rng.randf_range(-noise_amplitude, noise_amplitude)
		scores[axial] = score

	var pick: Variant = _weighted_pick(scores)
	if pick == null:
		return {}

	var picked_interest: float = float(scores[pick])
	_handle_choice(pick, picked_interest)
	return {"axial": pick, "interest": picked_interest}


func _novelty(axial: Vector2i) -> float:
	if memory.is_recent(axial):
		return -1.0
	if memory.was_visited(axial):
		return 0.2
	return 1.0


func _weighted_pick(scores: Dictionary) -> Variant:
	if scores.is_empty():
		return null
	var max_score: float = -INF
	for s in scores.values():
		max_score = max(max_score, float(s))
	var temp: float = max(temperature, 0.001)
	var weighted: Array[Dictionary] = []
	var total: float = 0.0
	for key in scores.keys():
		var w: float = exp((float(scores[key]) - max_score) / temp)
		total += w
		weighted.append({"axial": key, "w": w})
	var roll: float = rng.randf() * total
	for item in weighted:
		roll -= float(item["w"])
		if roll <= 0.0:
			return item["axial"]
	return weighted.back()["axial"]


func _handle_choice(pick: Vector2i, interest: float) -> void:
	if pick == last_choice:
		stuck_steps += 1
		if stuck_steps > stuck_clear_after:
			memory.clear_recent()
			stuck_steps = 0
	else:
		stuck_steps = 0
	last_choice = pick
	current_cell = pick
	memory.record(pick)
	emit_signal("next_cell_chosen", pick, interest)


func _hex_distance(a: Vector2i, b: Vector2i) -> int:
	var dq: int = abs(a.x - b.x)
	var dr: int = abs(a.y - b.y)
	var ds: int = abs((-a.x - a.y) - (-b.x - b.y))
	return max(dq, max(dr, ds))


func _grid() -> Node:
	if grid_path.is_empty():
		return null
	return get_node_or_null(grid_path)

