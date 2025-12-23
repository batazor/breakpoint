extends Node3D
class_name CharacterBrain

@export var wander_path: NodePath
@export var faction_system_path: NodePath
@export var npc_id: StringName = &""

var wander
var roles: CharacterRoles


func _ready() -> void:
	wander = get_node_or_null(wander_path)
	if wander == null:
		wander = get_node_or_null("CharacterWander")
	_resolve_roles()


func _resolve_roles() -> void:
	roles = CharacterRoles.new()
	add_child(roles)
	roles.set_faction_system_path(faction_system_path)
	roles.set_npc_id(npc_id)


func go_home(home_building: StringName) -> void:
	if wander == null:
		return
	if wander.has_method("set_goal"):
		# For now just set goal; integration with actual building position can be added.
		wander.call("set_goal", Vector2i(-1, -1)) # placeholder for future mapping


func go_work(workplace: StringName) -> void:
	if wander == null:
		return
	if wander.has_method("set_goal"):
		wander.call("set_goal", Vector2i(-1, -1)) # placeholder

