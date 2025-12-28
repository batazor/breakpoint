extends Node
class_name QuestManager

## Manages quest state and progression
## Integrates with BuildController, FactionSystem, and DialogManager for automatic objective tracking

signal quest_started(quest: Quest)
signal quest_updated(quest: Quest)
signal quest_completed(quest: Quest)
signal quest_failed(quest: Quest)
signal objective_completed(quest: Quest, objective: QuestObjective)

var active_quests: Array[Quest] = []
var completed_quests: Array[StringName] = []
var available_quests: Dictionary = {}  # quest_id -> Quest
var player_faction_id: StringName = &"kingdom"  # Default player faction, can be configured


func set_player_faction(faction_id: StringName) -> void:
	## Set the player's faction ID for quest tracking
	player_faction_id = faction_id


func _ready() -> void:
	# Connect to game systems for automatic objective tracking
	_connect_to_systems()
	
	# Connect to quest generator for dynamic quests
	var quest_generator = get_node_or_null("/root/Main/QuestGenerator")
	if quest_generator:
		if quest_generator.has_signal("quest_generated"):
			quest_generator.quest_generated.connect(_on_quest_generated)


func _on_quest_generated(quest: Quest) -> void:
	## Handle dynamically generated quest
	# Auto-register and optionally auto-start based on urgency
	register_quest(quest)
	
	# Notify player of new quest opportunity
	print("New quest available: %s" % quest.title)
	# Emit signal for UI notification
	if quest.category == "urgent":
		quest_started.emit(quest)
	else:
		quest_updated.emit(quest)


func _connect_to_systems() -> void:
	## Connect to game systems for automatic objective tracking
	
	# Connect to build controller for build objectives
	var build_controller = get_node_or_null("/root/Main/BuildController")
	if build_controller:
		if build_controller.has_signal("building_placed"):
			build_controller.building_placed.connect(_on_building_placed)
	
	# Connect to faction system for resource objectives
	var faction_system = get_node_or_null("/root/Main/FactionSystem")
	if faction_system:
		if faction_system.has_signal("resources_changed"):
			faction_system.resources_changed.connect(_on_resources_changed)
	
	# Connect to dialog manager for talk objectives
	var dialog_manager = get_node_or_null("/root/Main/DialogManager")
	if dialog_manager:
		if dialog_manager.has_signal("dialog_ended"):
			dialog_manager.dialog_ended.connect(_on_dialog_ended)


func register_quest(quest: Quest) -> void:
	## Register a quest to make it available
	if quest == null or quest.id == StringName(""):
		push_error("Cannot register invalid quest")
		return
	available_quests[quest.id] = quest


func start_quest(quest_id: StringName, player_faction_id: StringName = &"kingdom") -> bool:
	## Start a quest if requirements are met
	if not available_quests.has(quest_id):
		push_error("Quest not found: %s" % quest_id)
		return false
	
	var quest: Quest = available_quests[quest_id]
	
	if not quest.can_start(player_faction_id):
		push_warning("Quest requirements not met: %s" % quest_id)
		return false
	
	quest.state = Quest.QuestState.ACTIVE
	quest.start_time = Time.get_ticks_msec() / 1000.0
	active_quests.append(quest)
	
	quest_started.emit(quest)
	return true


func update_objective(quest_id: StringName, objective_id: String, progress: int) -> void:
	## Update progress for a specific objective
	var quest := get_active_quest(quest_id)
	if not quest:
		return
	
	for objective in quest.objectives:
		if objective.id == objective_id:
			objective.current = progress
			
			if objective.is_completed():
				objective_completed.emit(quest, objective)
			
			quest_updated.emit(quest)
			
			# Check if all objectives completed
			if quest.is_completed():
				complete_quest(quest_id)
			
			break


func complete_quest(quest_id: StringName) -> void:
	## Mark a quest as completed and give rewards
	var quest := get_active_quest(quest_id)
	if not quest:
		return
	
	quest.state = Quest.QuestState.COMPLETED
	quest.completion_time = Time.get_ticks_msec() / 1000.0
	active_quests.erase(quest)
	completed_quests.append(quest_id)
	
	# Give rewards
	_give_rewards(quest)
	
	quest_completed.emit(quest)
	
	# Start next quest if specified
	if not quest.next_quest_id.is_empty():
		call_deferred("start_quest", quest.next_quest_id)


func fail_quest(quest_id: StringName) -> void:
	## Mark a quest as failed
	var quest := get_active_quest(quest_id)
	if not quest:
		return
	
	quest.state = Quest.QuestState.FAILED
	active_quests.erase(quest)
	
	quest_failed.emit(quest)


func _give_rewards(quest: Quest) -> void:
	## Apply quest rewards to player
	var faction_system = get_node_or_null("/root/Main/FactionSystem")
	if not faction_system:
		return
	
	for resource_id in quest.rewards:
		var amount: int = quest.rewards[resource_id]
		if faction_system.has_method("add_resource"):
			faction_system.add_resource(player_faction_id, StringName(resource_id), amount)
			print("Quest reward: +%d %s" % [amount, resource_id])


func get_active_quest(quest_id: StringName) -> Quest:
	## Get an active quest by ID
	for quest in active_quests:
		if quest.id == quest_id:
			return quest
	return null


func is_quest_completed(quest_id: StringName) -> bool:
	## Check if a quest has been completed
	return completed_quests.has(quest_id)


func get_active_quests() -> Array[Quest]:
	## Get all active quests
	return active_quests


func get_available_quests() -> Array[Quest]:
	## Get all available quests
	var quests: Array[Quest] = []
	for quest_id in available_quests:
		quests.append(available_quests[quest_id])
	return quests


## Signal handlers for automatic objective tracking


func _on_building_placed(building_id: String, position: Vector2i) -> void:
	## Track building objectives
	for quest in active_quests:
		for objective in quest.objectives:
			if objective.type == "build" and objective.target == building_id:
				objective.increment()
				quest_updated.emit(quest)
				
				if objective.is_completed():
					objective_completed.emit(quest, objective)
				
				if quest.is_completed():
					complete_quest(quest.id)


func _on_resources_changed(faction_id: StringName, resource_id: StringName, amount: int) -> void:
	## Track resource gathering objectives
	# Check if this is the player's faction
	if faction_id != player_faction_id:
		return
	
	for quest in active_quests:
		for objective in quest.objectives:
			if objective.type == "gather" and StringName(objective.target) == resource_id:
				# Check total resource amount
				var faction_system = get_node_or_null("/root/Main/FactionSystem")
				if faction_system and faction_system.has_method("resource_amount"):
					var current_amount = faction_system.resource_amount(faction_id, resource_id)
					# Update progress - track actual amount up to the target
					objective.current = min(current_amount, objective.count)
					quest_updated.emit(quest)
					
					if objective.is_completed():
						objective_completed.emit(quest, objective)
					
					if quest.is_completed():
						complete_quest(quest.id)


func _on_dialog_ended() -> void:
	## Track talk objectives
	var dialog_manager = get_node_or_null("/root/Main/DialogManager")
	if not dialog_manager:
		return
	
	var npc_id = dialog_manager.current_npc_id
	
	for quest in active_quests:
		for objective in quest.objectives:
			if objective.type == "talk" and StringName(objective.target) == npc_id:
				objective.increment()
				quest_updated.emit(quest)
				
				if objective.is_completed():
					objective_completed.emit(quest, objective)
				
				if quest.is_completed():
					complete_quest(quest.id)
