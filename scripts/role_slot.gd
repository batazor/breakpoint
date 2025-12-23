extends Resource
class_name RoleSlot

@export var role_id: StringName = &""
@export var max_slots: int = 1
@export var assigned: Array[StringName] = []


func has_space() -> bool:
	return assigned.size() < max_slots


func assign(npc_id: StringName) -> bool:
	if assigned.has(npc_id):
		return true
	if not has_space():
		return false
	assigned.append(npc_id)
	return true


func vacate(npc_id: StringName) -> void:
	assigned.erase(npc_id)

