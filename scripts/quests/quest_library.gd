extends Node
class_name QuestLibrary

## Library of pre-defined quest templates and tutorial quests
## Provides both scripted tutorial quests and templates for procedural generation

signal quests_loaded()

var tutorial_quests: Array[Quest] = []
var faction_quests: Dictionary = {}  # faction_id -> Array[Quest]
var repeatable_quests: Array[Quest] = []


func _ready() -> void:
	_create_tutorial_quests()
	_create_faction_quests()
	_create_repeatable_quests()
	quests_loaded.emit()


func get_tutorial_quests() -> Array[Quest]:
	## Get all tutorial quests
	return tutorial_quests


func get_faction_quests(faction_id: StringName) -> Array[Quest]:
	## Get quests for a specific faction
	if faction_quests.has(faction_id):
		return faction_quests[faction_id]
	return []


func get_repeatable_quests() -> Array[Quest]:
	## Get all repeatable quests
	return repeatable_quests


func _create_tutorial_quests() -> void:
	## Create tutorial quest chain
	
	# Quest 1: First Steps
	var quest1 = Quest.new()
	quest1.id = StringName("tutorial_first_steps")
	quest1.title = "Establishing Your Settlement"
	quest1.description = "Build your first fortress to establish your presence in these lands."
	quest1.category = "tutorial"
	quest1.faction_id = &"kingdom"
	
	var obj1 = QuestObjective.new()
	obj1.id = "build_fortress"
	obj1.description = "Build 1 fortress"
	obj1.type = "build"
	obj1.target = "fortress"
	obj1.count = 1
	quest1.objectives.append(obj1)
	
	quest1.rewards = {"food": 50, "coal": 50, "gold": 25}
	quest1.next_quest_id = StringName("tutorial_resource_basics")
	
	tutorial_quests.append(quest1)
	
	# Quest 2: Resource Basics
	var quest2 = Quest.new()
	quest2.id = StringName("tutorial_resource_basics")
	quest2.title = "Resource Basics"
	quest2.description = "Learn about resource management by building a well and a mine."
	quest2.category = "tutorial"
	quest2.faction_id = &"kingdom"
	
	var obj2_1 = QuestObjective.new()
	obj2_1.id = "build_well"
	obj2_1.description = "Build 1 well"
	obj2_1.type = "build"
	obj2_1.target = "well"
	obj2_1.count = 1
	quest2.objectives.append(obj2_1)
	
	var obj2_2 = QuestObjective.new()
	obj2_2.id = "build_mine"
	obj2_2.description = "Build 1 mine"
	obj2_2.type = "build"
	obj2_2.target = "mine"
	obj2_2.count = 1
	quest2.objectives.append(obj2_2)
	
	quest2.rewards = {"gold": 100}
	quest2.requirements = {"quest": StringName("tutorial_first_steps")}
	
	tutorial_quests.append(quest2)
	
	# Quest 3: Growing Settlement
	var quest3 = Quest.new()
	quest3.id = StringName("tutorial_growing_settlement")
	quest3.title = "Growing Settlement"
	quest3.description = "Expand your settlement by constructing multiple buildings."
	quest3.category = "tutorial"
	quest3.faction_id = &"kingdom"
	
	var obj3 = QuestObjective.new()
	obj3.id = "gather_food"
	obj3.description = "Gather 50 food"
	obj3.type = "gather"
	obj3.target = "food"
	obj3.count = 50
	quest3.objectives.append(obj3)
	
	quest3.rewards = {"gold": 75, "coal": 25}
	
	tutorial_quests.append(quest3)


func _create_faction_quests() -> void:
	## Create faction-specific quests
	
	# Kingdom quest
	var kingdom_quest = Quest.new()
	kingdom_quest.id = StringName("kingdom_prosperity")
	kingdom_quest.title = "Path to Prosperity"
	kingdom_quest.description = "The kingdom values economic strength. Gather resources to prove your worth."
	kingdom_quest.category = "faction"
	kingdom_quest.faction_id = &"kingdom"
	
	var obj_k = QuestObjective.new()
	obj_k.id = "gather_gold"
	obj_k.description = "Gather 200 gold"
	obj_k.type = "gather"
	obj_k.target = "gold"
	obj_k.count = 200
	kingdom_quest.objectives.append(obj_k)
	
	kingdom_quest.rewards = {"gold": 100, "food": 50}
	
	if not faction_quests.has(&"kingdom"):
		faction_quests[&"kingdom"] = []
	faction_quests[&"kingdom"].append(kingdom_quest)
	
	# Barbarian quest (if applicable)
	var barbarian_quest = Quest.new()
	barbarian_quest.id = StringName("horde_expansion")
	barbarian_quest.title = "Expand Territory"
	barbarian_quest.description = "The Horde respects strength. Build fortresses to claim territory."
	barbarian_quest.category = "faction"
	barbarian_quest.faction_id = &"horde"
	
	var obj_b = QuestObjective.new()
	obj_b.id = "build_fortresses"
	obj_b.description = "Build 3 fortresses"
	obj_b.type = "build"
	obj_b.target = "fortress"
	obj_b.count = 3
	barbarian_quest.objectives.append(obj_b)
	
	barbarian_quest.rewards = {"coal": 100, "gold": 50}
	
	if not faction_quests.has(&"horde"):
		faction_quests[&"horde"] = []
	faction_quests[&"horde"].append(barbarian_quest)


func _create_repeatable_quests() -> void:
	## Create repeatable quests for ongoing gameplay
	
	# Daily tribute quest
	var daily_quest = Quest.new()
	daily_quest.id = StringName("daily_tribute")
	daily_quest.title = "Daily Tribute"
	daily_quest.description = "Gather resources to maintain your settlement's economy."
	daily_quest.category = "repeatable"
	daily_quest.repeatable = true
	daily_quest.time_limit_hours = 24.0
	
	var obj_d = QuestObjective.new()
	obj_d.id = "gather_mixed"
	obj_d.description = "Gather 50 of any resource"
	obj_d.type = "gather"
	obj_d.target = "food"  # Could be expanded to support any resource
	obj_d.count = 50
	daily_quest.objectives.append(obj_d)
	
	daily_quest.rewards = {"gold": 30}
	
	repeatable_quests.append(daily_quest)
	
	# Scout report quest
	var scout_quest = Quest.new()
	scout_quest.id = StringName("scout_report")
	scout_quest.title = "Scout Report"
	scout_quest.description = "Explore new territories to gather intelligence."
	scout_quest.category = "repeatable"
	scout_quest.repeatable = true
	
	var obj_s = QuestObjective.new()
	obj_s.id = "explore_tiles"
	obj_s.description = "Explore 5 new hexes"
	obj_s.type = "explore"
	obj_s.target = "any"
	obj_s.count = 5
	scout_quest.objectives.append(obj_s)
	
	scout_quest.rewards = {"gold": 40, "food": 20}
	
	repeatable_quests.append(scout_quest)
