extends Resource
class_name NPC

@export var id: StringName
@export var faction_id: StringName = ""
@export_range(0.0, 1.0) var loyalty: float = 1.0
@export var title: String = ""
@export var description: String = ""
@export var health: int = 100
@export var move_speed: float = 4.0
@export var icon: Texture2D
@export var scene: PackedScene
@export var role: StringName = &""
@export var home_building: StringName = &""
@export var workplace: StringName = &""
@export var inventory: Dictionary = {} # resource_id -> amount
@export var current_quest_id: StringName = &""  # Quest this NPC is currently pursuing


## Add resources to inventory
## Returns true if successful, false if amount is invalid
func add_to_inventory(resource_id: StringName, amount: int) -> bool:
	if amount <= 0:
		return false
	if not inventory.has(resource_id):
		inventory[resource_id] = 0
	inventory[resource_id] = int(inventory[resource_id]) + amount
	return true


## Remove resources from inventory
## Returns true if successful, false if not enough resources
func remove_from_inventory(resource_id: StringName, amount: int) -> bool:
	if amount <= 0:
		return false
	if not inventory.has(resource_id):
		return false
	var current: int = int(inventory[resource_id])
	if current < amount:
		return false
	inventory[resource_id] = current - amount
	if inventory[resource_id] <= 0:
		inventory.erase(resource_id)
	return true


## Get amount of a resource in inventory
func get_inventory_amount(resource_id: StringName) -> int:
	if not inventory.has(resource_id):
		return 0
	return int(inventory[resource_id])


## Get total count of all items in inventory
func get_inventory_total() -> int:
	var total: int = 0
	for resource_id in inventory.keys():
		total += int(inventory[resource_id])
	return total


## Check if inventory is empty
func is_inventory_empty() -> bool:
	return inventory.is_empty()


## Assign a quest to this NPC
func assign_quest(quest_id: StringName) -> void:
	current_quest_id = quest_id


## Check if NPC has an active quest
func has_active_quest() -> bool:
	return current_quest_id != StringName("")


## Clear NPC's current quest
func clear_quest() -> void:
	current_quest_id = StringName("")
