extends Resource
class_name QuestObjective

## Quest objective resource defining individual objectives within a quest
## Supports multiple objective types: build, gather, talk, explore, relationship, survive, defeat

@export var id: String = ""
@export var description: String = ""
@export var type: String = ""  # build, gather, talk, explore, relationship, survive, defeat
@export var target: String = ""  # Building ID, Resource ID, NPC ID, Faction ID, etc.
@export var count: int = 1
@export var current: int = 0
@export var value: float = 0.0  # For relationship or other float values (e.g., duration for survive)
@export var optional: bool = false
@export var hidden: bool = false  # Don't show to player initially


func is_completed() -> bool:
	## Check if objective is completed based on type
	match type:
		"build", "gather", "talk", "explore", "defeat":
			return current >= count
		"relationship":
			return current >= value
		"survive":
			return current >= value  # value is duration in hours
		_:
			return false


func get_progress() -> float:
	## Get objective progress as a float between 0.0 and 1.0
	if is_completed():
		return 1.0
	
	match type:
		"build", "gather", "talk", "explore", "defeat":
			return float(current) / float(max(count, 1))
		"relationship", "survive":
			return float(current) / float(max(value, 1.0))
		_:
			return 0.0


func increment(amount: int = 1) -> void:
	## Increment objective progress
	current += amount
