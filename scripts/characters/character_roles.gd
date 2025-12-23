extends Node
class_name CharacterRoles

const FactionSystem = preload("res://scripts/faction_system.gd")

@export var faction_system_path: NodePath
@export var npc_id: StringName = &""

var faction_system: FactionSystem
var npc_ref


func _ready() -> void:
	_resolve_system()
	_resolve_npc()


func set_faction_system_path(path: NodePath) -> void:
	faction_system_path = path
	_resolve_system()


func set_npc_id(id: StringName) -> void:
	npc_id = id
	_resolve_npc()


func assign_to(building_id: StringName, role_id: StringName) -> bool:
	if faction_system == null or npc_id == StringName(""):
		return false
	return faction_system.assign_role(building_id, role_id, npc_id)


func vacate(building_id: StringName, role_id: StringName) -> void:
	if faction_system == null or npc_id == StringName(""):
		return
	faction_system.vacate_role(building_id, role_id, npc_id)


func _resolve_system() -> void:
	if faction_system_path.is_empty():
		faction_system = get_tree().get_first_node_in_group("faction_system")
	else:
		faction_system = get_node_or_null(faction_system_path) as FactionSystem


func _resolve_npc() -> void:
	if faction_system == null or npc_id == StringName(""):
		return
	if faction_system.npc_data.has(npc_id):
		npc_ref = faction_system.npc_data[npc_id]

