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


## Add resources to inventory
func add_to_inventory(resource_id: StringName, amount: int) -> void:
	if amount <= 0:
		return
	if not inventory.has(resource_id):
		inventory[resource_id] = 0
	inventory[resource_id] = int(inventory[resource_id]) + amount


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
