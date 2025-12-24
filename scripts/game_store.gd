extends Node

signal factions_changed
signal world_ready

var factions: Dictionary[StringName, Variant] = {}

var _world_ready_emitted: bool = false


func _enter_tree() -> void:
	# Allow discovery before _ready
	add_to_group("game_store")


func register_faction(faction: Variant) -> void:
	if faction == null:
		return

	if not ("id" in faction):
		push_warning("Faction missing 'id'")
		return

	var id: StringName = StringName(faction.id)
	if id == StringName():
		push_warning("Faction has empty id")
		return

	if factions.has(id):
		return  # already registered, ignore

	factions[id] = faction
	emit_signal("factions_changed")

	_try_emit_world_ready()


func is_ready() -> bool:
	return factions.size() > 0


func _try_emit_world_ready() -> void:
	if _world_ready_emitted:
		return

	if not is_ready():
		return

	_world_ready_emitted = true
	emit_signal("world_ready")
