extends Resource
class_name Quest

## Quest resource class defining quest data and behavior
## Supports multiple quest categories: main, side, faction, repeatable, tutorial

enum QuestState {
	NOT_STARTED,  # Quest available but not accepted
	ACTIVE,       # Quest in progress
	COMPLETED,    # Quest finished successfully
	FAILED,       # Quest failed
	ABANDONED     # Player abandoned quest
}

@export var id: StringName
@export var title: String = ""
@export var description: String = ""
@export var category: String = "side"  # main, side, faction, repeatable, tutorial
@export var objectives: Array[QuestObjective] = []
@export var rewards: Dictionary = {}  # resource_id -> amount
@export var requirements: Dictionary = {}  # quest_id -> true, level -> int, faction -> StringName, etc.
@export var faction_id: StringName = &""
@export var npc_giver: StringName = &""
@export var dialog_start: String = ""
@export var dialog_complete: String = ""
@export var next_quest_id: StringName = &""
@export var repeatable: bool = false
@export var time_limit_hours: float = 0.0  # 0 = no limit

var state: int = QuestState.NOT_STARTED
var start_time: float = 0.0
var completion_time: float = 0.0


func is_completed() -> bool:
	## Check if all objectives are completed
	if objectives.is_empty():
		return false
	for objective in objectives:
		if not objective.optional and not objective.is_completed():
			return false
	return true


func get_progress() -> float:
	## Get overall quest progress as a float between 0.0 and 1.0
	if objectives.is_empty():
		return 0.0
	var total := 0.0
	for objective in objectives:
		if not objective.optional:
			total += objective.get_progress()
	# Count only non-optional objectives
	var non_optional_count := 0
	for objective in objectives:
		if not objective.optional:
			non_optional_count += 1
	return total / float(max(non_optional_count, 1))


func can_start(player_faction_id: StringName = &"") -> bool:
	## Check if quest can be started based on requirements
	# Check faction requirement
	if requirements.has("faction") and player_faction_id != &"":
		if requirements["faction"] != player_faction_id:
			return false
	
	# Check if quest is already active or completed (unless repeatable)
	if not repeatable and (state == QuestState.COMPLETED or state == QuestState.ACTIVE):
		return false
	
	return true


func get_time_remaining() -> float:
	## Get time remaining in hours (returns -1 if no time limit)
	if time_limit_hours <= 0.0:
		return -1.0
	
	if state != QuestState.ACTIVE:
		return time_limit_hours
	
	var elapsed := (Time.get_ticks_msec() / 1000.0) - start_time
	var elapsed_hours := elapsed / 3600.0
	return max(0.0, time_limit_hours - elapsed_hours)


func is_time_expired() -> bool:
	## Check if time limit has expired
	if time_limit_hours <= 0.0:
		return false
	
	return get_time_remaining() <= 0.0
