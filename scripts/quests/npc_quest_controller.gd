extends Node
class_name NPCQuestController

## Controller for managing NPC quests and quest-driven behavior
## Allows NPCs to pursue their own missions autonomously

signal npc_quest_assigned(npc_id: StringName, quest_id: StringName)
signal npc_quest_completed(npc_id: StringName, quest_id: StringName)
signal npc_quest_progress(npc_id: StringName, quest_id: StringName, progress: float)

var npc_quests: Dictionary = {}  # npc_id -> quest_id
var quest_manager: QuestManager = null
var faction_system: Node = null


func _ready() -> void:
	_connect_to_systems()


func _connect_to_systems() -> void:
	## Connect to quest manager and faction system
	quest_manager = get_node_or_null("/root/Main/QuestManager")
	faction_system = get_node_or_null("/root/Main/FactionSystem")
	
	if quest_manager:
		if quest_manager.has_signal("quest_completed"):
			quest_manager.quest_completed.connect(_on_quest_completed)


func assign_quest_to_npc(npc_id: StringName, quest_id: StringName) -> bool:
	## Assign a quest to an NPC
	if not faction_system:
		push_error("FactionSystem not found")
		return false
	
	var npc = faction_system.get_npc(npc_id) if faction_system.has_method("get_npc") else null
	if not npc:
		push_error("NPC not found: %s" % npc_id)
		return false
	
	# Check if NPC already has a quest
	if npc.has_method("has_active_quest") and npc.has_active_quest():
		push_warning("NPC %s already has an active quest" % npc_id)
		return false
	
	# Assign quest to NPC
	if npc.has_method("assign_quest"):
		npc.assign_quest(quest_id)
	npc_quests[npc_id] = quest_id
	
	npc_quest_assigned.emit(npc_id, quest_id)
	print("Quest %s assigned to NPC %s" % [quest_id, npc_id])
	return true


func get_npc_quest(npc_id: StringName) -> StringName:
	## Get the quest assigned to an NPC
	if npc_quests.has(npc_id):
		return npc_quests[npc_id]
	return StringName("")


func update_npc_quest_progress(npc_id: StringName, objective_id: String, progress: int) -> void:
	## Update progress for an NPC's quest objective
	if not npc_quests.has(npc_id):
		return
	
	var quest_id = npc_quests[npc_id]
	if quest_manager and quest_manager.has_method("update_objective"):
		quest_manager.update_objective(quest_id, objective_id, progress)
	
	# Get quest progress for signal
	if quest_manager and quest_manager.has_method("get_active_quest"):
		var quest = quest_manager.get_active_quest(quest_id)
		if quest:
			var progress_value = quest.get_progress()
			npc_quest_progress.emit(npc_id, quest_id, progress_value)


func complete_npc_quest(npc_id: StringName) -> void:
	## Mark an NPC's quest as completed
	if not npc_quests.has(npc_id):
		return
	
	var quest_id = npc_quests[npc_id]
	
	# Clear NPC's quest
	if faction_system:
		var npc = faction_system.get_npc(npc_id) if faction_system.has_method("get_npc") else null
		if npc and npc.has_method("clear_quest"):
			npc.clear_quest()
	
	npc_quests.erase(npc_id)
	npc_quest_completed.emit(npc_id, quest_id)
	print("NPC %s completed quest %s" % [npc_id, quest_id])


func _on_quest_completed(quest: Quest) -> void:
	## Handle quest completion events
	# Check if any NPC was pursuing this quest
	for npc_id in npc_quests:
		if npc_quests[npc_id] == quest.id:
			complete_npc_quest(npc_id)
			break


func get_available_quests_for_npc(npc_id: StringName) -> Array[Quest]:
	## Get quests available for an NPC based on their faction
	if not faction_system:
		return []
	
	var npc = faction_system.get_npc(npc_id) if faction_system.has_method("get_npc") else null
	if not npc:
		return []
	
	var available: Array[Quest] = []
	
	if quest_manager and quest_manager.has_method("get_available_quests"):
		var all_quests = quest_manager.get_available_quests()
		for quest in all_quests:
			# Check if quest is suitable for NPC's faction
			if quest.faction_id == npc.faction_id or quest.faction_id == StringName(""):
				available.append(quest)
	
	return available


func auto_assign_quest_to_npc(npc_id: StringName) -> bool:
	## Automatically assign a suitable quest to an NPC
	var available_quests = get_available_quests_for_npc(npc_id)
	
	if available_quests.is_empty():
		return false
	
	# Pick a random available quest
	var quest = available_quests[randi() % available_quests.size()]
	return assign_quest_to_npc(npc_id, quest.id)
