extends Resource
class_name GameResource

@export var id: StringName
@export var title: String
@export var icon: Texture2D
@export var scene: PackedScene
@export var buildable_tiles: Array = []
@export var category: String = "resource"
@export var description: String = ""
@export var roles: Array = [] # Array[Dictionary] {role_id, max_slots}
@export var resource_delta_per_hour: Dictionary = {} # resource_id -> int (positive = produce, negative = consume)
@export var build_cost: Dictionary = {} # resource_id -> int
@export var build_time_hours: int = 0
@export var max_level: int = 1 # Maximum upgrade level (1 means no upgrades available)
@export var upgrade_levels: Array[Dictionary] = [] # Array of upgrade data: [{level: int, upgrade_cost: {}, upgrade_time_hours: int, resource_delta_bonus: {}}]


func can_build_on(biome_name: String) -> bool:
	if buildable_tiles.is_empty():
		return true
	for tile in buildable_tiles:
		if String(tile) == biome_name:
			return true
	return false


func can_upgrade(current_level: int) -> bool:
	## Check if building can be upgraded from current level
	return current_level < max_level


func get_upgrade_cost(current_level: int) -> Dictionary:
	## Get the upgrade cost for upgrading from current_level to next level
	if not can_upgrade(current_level):
		return {}
	
	for upgrade_data in upgrade_levels:
		if upgrade_data.get("level", 0) == current_level + 1:
			return upgrade_data.get("upgrade_cost", {})
	
	return {}


func get_upgrade_time(current_level: int) -> int:
	## Get the upgrade time in hours for upgrading from current_level to next level
	if not can_upgrade(current_level):
		return 0
	
	for upgrade_data in upgrade_levels:
		if upgrade_data.get("level", 0) == current_level + 1:
			return int(upgrade_data.get("upgrade_time_hours", 0))
	
	return 0


func get_resource_delta_at_level(level: int) -> Dictionary:
	## Get the total resource delta per hour at a specific level (base + bonuses)
	var total_delta: Dictionary = resource_delta_per_hour.duplicate()
	
	# Add bonuses from all upgrade levels up to current level
	for upgrade_data in upgrade_levels:
		var upgrade_level: int = upgrade_data.get("level", 0)
		if upgrade_level <= level and upgrade_level > 1:
			var bonus: Dictionary = upgrade_data.get("resource_delta_bonus", {})
			for res_key in bonus.keys():
				var current: int = total_delta.get(res_key, 0)
				total_delta[res_key] = current + int(bonus[res_key])
	
	return total_delta
