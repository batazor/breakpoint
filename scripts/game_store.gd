extends Node

signal factions_changed
signal world_ready

var factions: Dictionary = {}


func _enter_tree() -> void:
	# Register group early so other nodes can find the store during their _ready.
	add_to_group("game_store")


func register_faction(faction) -> void:
	if faction == null or not ("id" in faction) or String(faction.id).is_empty():
		return
	factions[faction.id] = faction
	emit_signal("factions_changed")
	if is_ready():
		emit_signal("world_ready")


func is_ready() -> bool:
	return factions.size() > 0
