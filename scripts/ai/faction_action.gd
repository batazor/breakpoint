extends Resource
class_name FactionAction

@export var id: StringName = &""
@export var cooldown: float = 15.0
@export var inertia_bias: float = 0.15

var last_executed: float = -INF


func evaluate(world_state: Dictionary) -> float:
	# Override in concrete actions. Return utility in [0, +inf)
	return 0.0


func execute(world_state: Dictionary) -> void:
	# Override to perform side effects (issue jobs, mark intents, etc).
	last_executed = world_state.get("now", 0.0)


func cooldown_factor(now_ts: float) -> float:
	if cooldown <= 0.0:
		return 1.0
	if last_executed < -1e10:
		return 1.0
	var delta := max(0.0, now_ts - last_executed)
	return clamp(delta / cooldown, 0.0, 1.0)


func inertia_factor(last_action_id: StringName) -> float:
	if last_action_id == StringName("") or id == last_action_id:
		return 1.0
	return max(0.0, 1.0 - inertia_bias)

