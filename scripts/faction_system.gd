extends Node
class_name FactionSystem

const Faction = preload("res://scripts/faction.gd")
const RoleSlot = preload("res://scripts/role_slot.gd")
const NPC = preload("res://scripts/npc.gd")

var factions: Dictionary = {} # id -> Faction
var building_owner: Dictionary = {} # building_id -> faction_id
var building_roles: Dictionary = {} # building_id -> Array[RoleSlot]
var building_types: Dictionary = {} # building_id -> StringName
var building_axial: Dictionary = {} # building_id -> Vector2i
var building_position: Dictionary = {} # building_id -> Vector3
var npc_data: Dictionary = {} # npc_id -> NPC
var game_store: Node
var unit_owner: Dictionary = {} # unit_id -> faction_id
var unit_types: Dictionary = {} # unit_id -> StringName (resource id)

signal resources_changed(faction_id: StringName, resource_id: StringName, amount: int)

signal building_transferred(building_id: StringName, new_owner: StringName)
signal role_assigned(building_id: StringName, role_id: StringName, npc_id: StringName)
signal role_vacated(building_id: StringName, role_id: StringName, npc_id: StringName)
signal factions_changed


func _enter_tree() -> void:
	# Group early so other nodes can find the system during their _ready.
	add_to_group("faction_system")


func _ready() -> void:
	_resolve_game_store()


func register_faction(faction: Faction) -> void:
	if faction == null or faction.id == StringName(""):
		return
	if faction.resources == null:
		faction.resources = {}
	if not faction.resources.has("food"):
		faction.resources["food"] = 0
	if not faction.resources.has("coal"):
		faction.resources["coal"] = 0
	if not faction.resources.has("gold"):
		faction.resources["gold"] = 0
	factions[faction.id] = faction
	if game_store == null:
		_resolve_game_store()
	if game_store != null:
		game_store.register_faction(faction)
	emit_signal("factions_changed")


func register_unit(unit_id: StringName, owner_faction: StringName, unit_type: StringName) -> void:
	if unit_id == StringName("") or owner_faction == StringName("") or unit_type == StringName(""):
		return
	unit_owner[unit_id] = owner_faction
	unit_types[unit_id] = unit_type


func deregister_unit(unit_id: StringName) -> void:
	if unit_id == StringName(""):
		return
	unit_owner.erase(unit_id)
	unit_types.erase(unit_id)


func register_npc(npc: NPC) -> void:
	if npc == null or npc.id == StringName(""):
		return
	npc_data[npc.id] = npc


func get_npc(npc_id: StringName) -> NPC:
	## Get NPC data by ID
	if npc_data.has(npc_id):
		return npc_data[npc_id]
	return null


func register_building(building_id: StringName, owner_faction: StringName, building_type: StringName, roles: Array[RoleSlot] = [], axial: Vector2i = Vector2i(-1, -1), position: Vector3 = Vector3.ZERO) -> void:
	if building_id == StringName(""):
		return
	building_owner[building_id] = owner_faction
	building_types[building_id] = building_type
	building_roles[building_id] = roles
	if axial != Vector2i(-1, -1):
		building_axial[building_id] = axial
	if position != Vector3.ZERO:
		building_position[building_id] = position
	_add_asset_building(owner_faction, building_id)


func deregister_building(building_id: StringName) -> void:
	if not building_owner.has(building_id):
		return
	var owner: StringName = building_owner[building_id]
	building_owner.erase(building_id)
	building_types.erase(building_id)
	building_roles.erase(building_id)
	building_axial.erase(building_id)
	building_position.erase(building_id)
	_remove_asset_building(owner, building_id)


func transfer_building(building_id: StringName, new_owner: StringName) -> void:
	if building_id == StringName("") or new_owner == StringName(""):
		return
	var old_owner: StringName = building_owner.get(building_id, StringName(""))
	building_owner[building_id] = new_owner
	_remove_asset_building(old_owner, building_id)
	_add_asset_building(new_owner, building_id)
	emit_signal("building_transferred", building_id, new_owner)


func assign_role(building_id: StringName, role_id: StringName, npc_id: StringName) -> bool:
	var slots := building_roles.get(building_id, []) as Array
	for s in slots:
		if s is RoleSlot and s.role_id == role_id:
			if s.assign(npc_id):
				emit_signal("role_assigned", building_id, role_id, npc_id)
				return true
	return false


func vacate_role(building_id: StringName, role_id: StringName, npc_id: StringName) -> void:
	var slots := building_roles.get(building_id, []) as Array
	for s in slots:
		if s is RoleSlot and s.role_id == role_id:
			s.vacate(npc_id)
			emit_signal("role_vacated", building_id, role_id, npc_id)


func roles_for_building(building_id: StringName) -> Array[RoleSlot]:
	return building_roles.get(building_id, []) as Array[RoleSlot]


func owner_of(building_id: StringName) -> StringName:
	return building_owner.get(building_id, StringName(""))


func axial_of(building_id: StringName) -> Vector2i:
	return building_axial.get(building_id, Vector2i(-1, -1))


func position_of(building_id: StringName) -> Vector3:
	return building_position.get(building_id, Vector3.ZERO)


func resource_amount(faction_id: StringName, resource_id: StringName) -> int:
	var f: Faction = factions.get(faction_id, null)
	if f == null or resource_id == StringName(""):
		return 0
	return int(f.resources.get(resource_id, 0))


func add_resource(faction_id: StringName, resource_id: StringName, amount: int) -> void:
	if amount == 0 or faction_id == StringName("") or resource_id == StringName(""):
		return
	var f: Faction = factions.get(faction_id, null)
	if f == null:
		return
	var current: int = int(f.resources.get(resource_id, 0))
	var next: int = current + amount
	if next < 0:
		next = 0
	f.resources[resource_id] = next
	emit_signal("resources_changed", faction_id, resource_id, next)


func set_resource_amount(faction_id: StringName, resource_id: StringName, amount: int) -> void:
	if faction_id == StringName("") or resource_id == StringName(""):
		return
	var f: Faction = factions.get(faction_id, null)
	if f == null:
		return
	var next: int = max(amount, 0)
	f.resources[resource_id] = next
	emit_signal("resources_changed", faction_id, resource_id, next)


func _add_asset_building(faction_id: StringName, building_id: StringName) -> void:
	if faction_id == StringName(""):
		return
	var f: Faction = factions.get(faction_id, null)
	if f == null:
		return
	if not f.assets_buildings.has(building_id):
		f.assets_buildings.append(building_id)


func _remove_asset_building(faction_id: StringName, building_id: StringName) -> void:
	if faction_id == StringName(""):
		return
	var f: Faction = factions.get(faction_id, null)
	if f == null:
		return
	f.assets_buildings.erase(building_id)


func _resolve_game_store() -> void:
	if game_store != null:
		return
	game_store = get_tree().get_first_node_in_group("game_store") as GameStore
	if game_store == null:
		game_store = get_node_or_null("/root/GameStore") as GameStore

