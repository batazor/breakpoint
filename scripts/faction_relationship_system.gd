extends Node
class_name FactionRelationshipSystem

## Manages relationships between factions using a -100 to +100 scale.
## Provides utilities for updating relationships and querying relationship states.

enum RelationshipState {
	HOSTILE = -1,   # Relations < -30
	NEUTRAL = 0,    # Relations between -30 and +30
	ALLIED = 1      # Relations > +30
}

const HOSTILE_THRESHOLD: float = -30.0
const ALLIED_THRESHOLD: float = 30.0

signal relationship_changed(faction_a: StringName, faction_b: StringName, new_value: float, state: RelationshipState)

@export var faction_system_path: NodePath

var _faction_system: FactionSystem


func _ready() -> void:
	_resolve_faction_system()


func get_relationship_value(faction_a: StringName, faction_b: StringName) -> float:
	if _faction_system == null or faction_a == StringName("") or faction_b == StringName(""):
		return 0.0
	
	var faction = _faction_system.factions.get(faction_a, null)
	if faction == null:
		return 0.0
	
	return faction.relations.get(faction_b, 0.0)


func get_relationship_state(faction_a: StringName, faction_b: StringName) -> RelationshipState:
	var value := get_relationship_value(faction_a, faction_b)
	
	if value <= HOSTILE_THRESHOLD:
		return RelationshipState.HOSTILE
	elif value >= ALLIED_THRESHOLD:
		return RelationshipState.ALLIED
	else:
		return RelationshipState.NEUTRAL


func set_relationship(faction_a: StringName, faction_b: StringName, value: float) -> void:
	if _faction_system == null:
		return
	
	# Clamp to -100 to +100
	var clamped_value := clampf(value, -100.0, 100.0)
	
	# Set relationship for faction_a -> faction_b
	var faction_a_obj = _faction_system.factions.get(faction_a, null)
	if faction_a_obj != null:
		faction_a_obj.relations[faction_b] = clamped_value
	
	# Mirror the relationship (faction_b -> faction_a)
	var faction_b_obj = _faction_system.factions.get(faction_b, null)
	if faction_b_obj != null:
		faction_b_obj.relations[faction_a] = clamped_value
	
	var state := _value_to_state(clamped_value)
	emit_signal("relationship_changed", faction_a, faction_b, clamped_value, state)


func modify_relationship(faction_a: StringName, faction_b: StringName, delta: float) -> void:
	var current := get_relationship_value(faction_a, faction_b)
	set_relationship(faction_a, faction_b, current + delta)


func is_hostile(faction_a: StringName, faction_b: StringName) -> bool:
	return get_relationship_state(faction_a, faction_b) == RelationshipState.HOSTILE


func is_neutral(faction_a: StringName, faction_b: StringName) -> bool:
	return get_relationship_state(faction_a, faction_b) == RelationshipState.NEUTRAL


func is_allied(faction_a: StringName, faction_b: StringName) -> bool:
	return get_relationship_state(faction_a, faction_b) == RelationshipState.ALLIED


func get_all_relationships_for_faction(faction_id: StringName) -> Dictionary:
	## Returns a dictionary of {other_faction_id: relationship_value}
	if _faction_system == null:
		return {}
	
	var faction = _faction_system.factions.get(faction_id, null)
	if faction == null:
		return {}
	
	return faction.relations.duplicate()


func initialize_relationship(faction_a: StringName, faction_b: StringName, initial_value: float = 0.0) -> void:
	## Initialize a relationship if it doesn't exist yet
	if get_relationship_value(faction_a, faction_b) == 0.0:
		set_relationship(faction_a, faction_b, initial_value)


func _resolve_faction_system() -> void:
	if not faction_system_path.is_empty():
		_faction_system = get_node_or_null(faction_system_path) as FactionSystem
	else:
		_faction_system = get_tree().get_first_node_in_group("faction_system") as FactionSystem


func _value_to_state(value: float) -> RelationshipState:
	if value <= HOSTILE_THRESHOLD:
		return RelationshipState.HOSTILE
	elif value >= ALLIED_THRESHOLD:
		return RelationshipState.ALLIED
	else:
		return RelationshipState.NEUTRAL
