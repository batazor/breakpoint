extends Node
class_name FactionAI

const FactionAction = preload("res://scripts/ai/faction_action.gd")
const FactionSystem = preload("res://scripts/faction_system.gd")

@export var faction_id: StringName = &""
@export var actions: Array[FactionAction] = []
@export var decision_interval: float = 10.0
@export var utility_threshold: float = 0.3
@export var faction_system_path: NodePath

var _faction_system: FactionSystem
var _accum: float = 0.0
var _dirty: bool = true
var _last_action: StringName = &""


func _ready() -> void:
	_resolve_faction_system()
	_connect_events()


func _process(delta: float) -> void:
	_accum += delta
	if _accum >= decision_interval and _dirty:
		_accum = 0.0
		_decide()


func mark_dirty(critical: bool = false) -> void:
	_dirty = true
	if critical:
		_decide()


func _decide() -> void:
	if actions.is_empty():
		_dirty = false
		return
	var now_ts: float = Time.get_ticks_msec() / 1000.0
	var best: FactionAction = null
	var best_score: float = -INF
	var world_state := {
		"faction_id": faction_id,
		"faction_system": _faction_system,
		"now": now_ts,
	}
	for action in actions:
		if action == null:
			continue
		var base_score := action.evaluate(world_state)
		var score := base_score
		score *= action.cooldown_factor(now_ts)
		score *= action.inertia_factor(_last_action)
		if score > best_score:
			best_score = score
			best = action
	if best != null and best_score > utility_threshold:
		best.execute(world_state)
		best.last_executed = now_ts
		_last_action = best.id
		_log_decision(best, best_score)
		_dirty = false


func _resolve_faction_system() -> void:
	if not faction_system_path.is_empty():
		_faction_system = get_node_or_null(faction_system_path) as FactionSystem
	else:
		_faction_system = get_tree().get_first_node_in_group("faction_system") as FactionSystem


func _connect_events() -> void:
	if _faction_system == null:
		return
	if _faction_system.is_connected("building_transferred", Callable(self, "_on_building_transferred")) == false:
		_faction_system.building_transferred.connect(_on_building_transferred)
	if _faction_system.is_connected("role_assigned", Callable(self, "_on_role_event")) == false:
		_faction_system.role_assigned.connect(_on_role_event)
	if _faction_system.is_connected("role_vacated", Callable(self, "_on_role_event")) == false:
		_faction_system.role_vacated.connect(_on_role_event)


func _on_building_transferred(_building_id: StringName, _new_owner: StringName) -> void:
	mark_dirty(true)


func _on_role_event(_building_id: StringName, _role_id: StringName, _npc_id: StringName) -> void:
	mark_dirty(false)


func _log_decision(action: FactionAction, score: float) -> void:
	var msg := "[FactionAI] %s picked %s (utility=%.3f)" % [str(faction_id), str(action.id), score]
	print(msg)

