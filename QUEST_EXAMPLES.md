# Example Quest Definitions

This document provides concrete examples of how quests would be implemented using the Quest System architecture.

## Tutorial Quest Example

### Quest: "Establishing Your Settlement"

```gdscript
# File: scripts/quests/examples/tutorial_01_establishing_settlement.gd
extends Quest

func _init() -> void:
	# Initialize arrays
	objectives = []
	
	# Basic quest info
	id = &"tutorial_establishing_settlement"
	title = "Establishing Your Settlement"
	description = "Build your first fortress and begin your journey in the Fractured Lands. Marcus the Builder will guide you through the basics of construction."
	category = "tutorial"
	
	# Quest giver
	npc_giver = &"marcus_builder"
	faction_id = &"kingdom"
	
	# Dialog integration
	dialog_start = "marcus_tutorial_01_start"
	dialog_complete = "marcus_tutorial_01_complete"
	
	# Objectives
	var obj1 = QuestObjective.new()
	obj1.id = "build_fortress"
	obj1.description = "Build your first fortress"
	obj1.type = "build"
	obj1.target = "fortress"
	obj1.count = 1
	obj1.current = 0
	
	objectives.append(obj1)
	
	# Rewards
	rewards = {
		"food": 50,
		"coal": 50,
		"gold": 25
	}
	
	# Next quest in chain
	next_quest_id = &"tutorial_resource_basics"
```

### Associated Dialog Tree

```gdscript
# In dialog_library.gd - Marcus Tutorial Start Dialog
func create_marcus_tutorial_01_start() -> DialogTree:
	var tree = DialogTree.new()
	tree.id = "marcus_tutorial_01_start"
	tree.title = "Meeting Marcus"
	
	# Opening dialog
	var start = DialogLine.new()
	start.speaker_name = "Marcus the Builder"
	start.text = "Welcome to the Fractured Lands, newcomer! I'm Marcus, and I'll help you establish your first settlement. This world might look strange with its hexagonal patterns, but with the right knowledge, we can build something great here."
	start.next_dialog_id = "explain_fortress"
	
	var explain = DialogLine.new()
	explain.speaker_name = "Marcus"
	explain.text = "First things first - you'll need a fortress. It's the heart of any settlement, providing shelter and a command center for your operations. Let me show you how to build one."
	
	var response1 = DialogResponse.new()
	response1.text = "I'm ready to learn. How do I build?"
	response1.next_dialog_id = "building_instructions"
	
	var response2 = DialogResponse.new()
	response2.text = "What are these hexagonal tiles?"
	response2.next_dialog_id = "explain_hexes"
	
	explain.responses = [response1, response2]
	
	# Building instructions
	var instructions = DialogLine.new()
	instructions.speaker_name = "Marcus"
	instructions.text = "Press 'B' to enter build mode, select 'Fortress' from the menu, then click on a suitable hex tile. You'll need resources: 50 food, 50 coal, and 100 gold. Don't worry - I'll spot you the materials for your first fortress."
	instructions.next_dialog_id = "quest_accept"
	
	# Hex explanation
	var hex_explain = DialogLine.new()
	hex_explain.speaker_name = "Marcus"
	hex_explain.text = "Ah, the hexes! They're remnants of the Sundering - a catastrophic event 347 years ago. The land literally fractured into these patterns. We've learned to build around them. Each hex has different properties, perfect for different structures."
	hex_explain.next_dialog_id = "building_instructions"
	
	# Quest acceptance
	var accept = DialogLine.new()
	accept.speaker_name = "Marcus"
	accept.text = "Build your fortress, and I'll meet you back here to discuss our next steps. Good luck!"
	accept.next_dialog_id = ""  # End dialog, quest starts
	
	# Add all to tree
	tree.add_dialog("start", start)
	tree.add_dialog("explain_fortress", explain)
	tree.add_dialog("building_instructions", instructions)
	tree.add_dialog("explain_hexes", hex_explain)
	tree.add_dialog("quest_accept", accept)
	
	return tree
```

## Main Story Quest Example

### Quest: "The Hexagonal Mystery"

```gdscript
# File: scripts/quests/examples/main_02_hexagonal_mystery.gd
extends Quest

func _init() -> void:
	id = &"main_hexagonal_mystery"
	title = "The Hexagonal Mystery"
	description = "Strange glyphs have been discovered on ancient hex tiles. Sage Miriam believes they hold clues to the Sundering. Explore the map to find these mysterious markings."
	category = "main"
	
	npc_giver = &"sage_miriam"
	faction_id = &"nomads"
	
	dialog_start = "miriam_hex_mystery_start"
	dialog_complete = "miriam_hex_mystery_complete"
	
	# Multiple exploration objectives
	var obj1 = QuestObjective.new()
	obj1.id = "discover_ancient_sites"
	obj1.description = "Discover ancient hex sites (0/5)"
	obj1.type = "explore"
	obj1.target = "ancient_site"  # Special hex marker type
	obj1.count = 5
	obj1.current = 0
	
	var obj2 = QuestObjective.new()
	obj2.id = "return_to_miriam"
	obj2.description = "Return to Sage Miriam"
	obj2.type = "talk"
	obj2.target = "sage_miriam"
	obj2.count = 1
	obj2.current = 0
	
	objectives.append(obj1)
	objectives.append(obj2)
	
	# Substantial rewards for main quest
	rewards = {
		"gold": 300,
		"reputation_nomads": 20  # Special reward type
	}
	
	# Unlock next act
	next_quest_id = &"main_establishing_power"
	
	# Requirements
	requirements = {
		"completed_quest": "tutorial_choose_path",
		"min_buildings": 3
	}
```

## Branching Quest Example

### Quest: "Sharing or Hoarding?"

```gdscript
# File: scripts/quests/examples/main_04_sharing_or_hoarding.gd
extends Quest

func _init() -> void:
	id = &"main_sharing_hoarding"
	title = "Knowledge is Power"
	description = "You've discovered functioning ancient technology. This knowledge could change everything - but should you share it with other factions or keep it for yourself?"
	category = "main"
	
	npc_giver = &"the_prophet"
	dialog_start = "prophet_choice_sharing"
	
	# Initial objective: make a choice
	var obj1 = QuestObjective.new()
	obj1.id = "make_decision"
	obj1.description = "Decide the fate of the ancient knowledge"
	obj1.type = "talk"
	obj1.target = "the_prophet"
	obj1.count = 1
	
	objectives.append(obj1)
	
	# No immediate rewards - consequences come later
	rewards = {}
	
	# This quest branches into different follow-ups
	# next_quest_id is set dynamically based on player choice
```

### Dialog-Quest Integration

The dialog system uses effect strings to trigger quest-related actions. The DialogManager should parse these effects:

```gdscript
# In dialog_manager.gd - extend _apply_response_effects()
func _apply_response_effects(response: DialogResponse) -> void:
	# ... existing resource effect handling ...
	
	# Handle quest effect strings
	var effect_str := response.effect.strip_edges()
	if effect_str.begins_with("start_quest:"):
		var quest_id = effect_str.substr(12)  # Remove "start_quest:" prefix
		var quest_manager = get_node_or_null("/root/Main/QuestManager")
		if quest_manager:
			quest_manager.start_quest(StringName(quest_id))
```

### Branching Dialog

```gdscript
func create_prophet_choice_sharing() -> DialogTree:
	var tree = DialogTree.new()
	tree.id = "prophet_choice_sharing"
	
	var start = DialogLine.new()
	start.speaker_name = "The Prophet"
	start.text = "You hold in your hands knowledge that could reshape the Fractured Lands. But with such power comes a choice. Will you share this discovery with all factions, fostering cooperation? Or will you guard it jealously, ensuring your faction's dominance?"
	
	var response_share = DialogResponse.new()
	response_share.text = "This knowledge belongs to everyone. I'll share it."
	response_share.next_dialog_id = "choice_share"
	# Effect format: "start_quest:{quest_id}" - DialogManager should parse and call QuestManager.start_quest()
	response_share.effect = "start_quest:main_path_cooperation"
	response_share.relationship_change = 20  # All factions improve
	
	var response_keep = DialogResponse.new()
	response_keep.text = "My faction discovered this. We keep it."
	response_keep.next_dialog_id = "choice_keep"
	response_keep.effect = "start_quest:main_path_dominance"
	response_keep.relationship_change = -10  # Others become suspicious
	
	var response_neutral = DialogResponse.new()
	response_neutral.text = "I need time to think about this."
	response_neutral.next_dialog_id = "choice_neutral"
	response_neutral.effect = "start_quest:main_path_balance"
	
	start.responses = [response_share, response_keep, response_neutral]
	
	# Different outcomes based on choice
	var share_result = DialogLine.new()
	share_result.speaker_name = "The Prophet"
	share_result.text = "A noble choice. By sharing this knowledge, you've taken the first step toward unity. The other factions will remember your generosity, though some may question your wisdom in not seizing this advantage."
	share_result.next_dialog_id = ""
	
	var keep_result = DialogLine.new()
	keep_result.speaker_name = "The Prophet"
	keep_result.text = "The path of power. By keeping this secret, you ensure your faction's strength, but you may have sown seeds of distrust. The others will wonder what else you're hiding."
	keep_result.next_dialog_id = ""
	
	var neutral_result = DialogLine.new()
	neutral_result.speaker_name = "The Prophet"
	neutral_result.text = "Balance in all things. Perhaps neither sharing nor hoarding is the answer, but finding a middle path. The world doesn't need extremes - it needs wisdom."
	neutral_result.next_dialog_id = ""
	
	tree.add_dialog("start", start)
	tree.add_dialog("choice_share", share_result)
	tree.add_dialog("choice_keep", keep_result)
	tree.add_dialog("choice_neutral", neutral_result)
	
	return tree
```

## Side Quest Example

### Quest: "The Lost Caravan"

```gdscript
# File: scripts/quests/examples/side_lost_caravan.gd
extends Quest

func _init() -> void:
	id = &"side_lost_caravan"
	title = "The Lost Caravan"
	description = "A merchant's supply caravan has gone missing on the trade route. The merchant is offering a reward for anyone who can find it and recover the goods."
	category = "side"
	
	npc_giver = &"merchant_elena"
	dialog_start = "elena_lost_caravan_start"
	
	# Investigation objectives
	var obj1 = QuestObjective.new()
	obj1.id = "find_caravan"
	obj1.description = "Investigate the trade route hexes"
	obj1.type = "explore"
	obj1.target = "trade_route_hex"
	obj1.count = 3
	
	var obj2 = QuestObjective.new()
	obj2.id = "resolve_situation"
	obj2.description = "Deal with the caravan situation"
	obj2.type = "talk"
	obj2.target = "merchant_elena"
	obj2.count = 1
	obj2.hidden = true  # Revealed after obj1 completes
	
	objectives.append(obj1)
	objectives.append(obj2)
	
	# Rewards vary based on resolution
	rewards = {
		"gold": 150,  # Base reward
		# Additional rewards determined by player choices
	}
	
	requirements = {
		"min_level": 5,  # Mid-game quest
		"completed_quest": "tutorial_choose_path"
	}
	
	repeatable = true  # Can be done again with different scenarios
```

## Faction Quest Example

### Quest: "Trial of Strength" (Horde)

```gdscript
# File: scripts/quests/examples/faction_horde_trial.gd
extends Quest

func _init() -> void:
	id = &"faction_horde_trial"
	title = "Trial of Strength"
	description = "Warlord Kargoth doesn't trust words - only actions. Prove your worth to the Crimson Horde through deeds of strength and courage."
	category = "faction"
	
	npc_giver = &"warlord_kargoth"
	faction_id = &"horde"
	
	dialog_start = "kargoth_trial_start"
	dialog_complete = "kargoth_trial_complete"
	
	# Challenge objectives
	var obj1 = QuestObjective.new()
	obj1.id = "build_barracks"
	obj1.description = "Build a barracks to train warriors"
	obj1.type = "build"
	obj1.target = "barracks"
	obj1.count = 1
	
	var obj2 = QuestObjective.new()
	obj2.id = "train_units"
	obj2.description = "Train 3 military units"
	obj2.type = "build"  # Units created through build system
	obj2.target = "knight"  # Or barbarian, or other military
	obj2.count = 3
	
	var obj3 = QuestObjective.new()
	obj3.id = "control_territory"
	obj3.description = "Control 5 strategic hex tiles"
	obj3.type = "explore"
	obj3.target = "strategic_hex"  # Special marked hexes
	obj3.count = 5
	
	objectives.append(obj1)
	objectives.append(obj2)
	objectives.append(obj3)
	
	# Faction-specific rewards
	rewards = {
		"gold": 150,
		"reputation_horde": 30,
		"unit_knight": 1  # Free unit as reward
	}
	
	requirements = {
		"min_relationship_horde": 10,
		"completed_quest": "tutorial_choose_path"
	}
```

## Repeatable Quest Example

### Quest: "Daily Harvest"

```gdscript
# File: scripts/quests/examples/repeatable_daily_harvest.gd
extends Quest

func _init() -> void:
	id = &"repeatable_daily_harvest"
	title = "Daily Harvest"
	description = "Contribute to your faction's food supplies by gathering resources. This task resets daily."
	category = "repeatable"
	
	repeatable = true
	time_limit_hours = 24.0  # Resets every day
	
	# Simple gathering objective
	var obj1 = QuestObjective.new()
	obj1.id = "gather_food"
	obj1.description = "Gather 20 food"
	obj1.type = "gather"
	obj1.target = "food"
	obj1.count = 20
	
	objectives.append(obj1)
	
	# Small but consistent rewards
	rewards = {
		"gold": 10,
		"reputation_kingdom": 2
	}
	
	# Always available once unlocked
	requirements = {
		"completed_quest": "tutorial_resource_basics"
	}
```

## Victory Condition Quest Example

### Quest: "Master of Commerce" (Economic Victory)

```gdscript
# File: scripts/quests/examples/victory_economic.gd
extends Quest

func _init() -> void:
	id = &"victory_master_commerce"
	title = "Master of Commerce"
	description = "Establish economic dominance over the Fractured Lands. Build a commercial empire that makes all factions dependent on your trade."
	category = "main"
	
	dialog_complete = "victory_economic_complete"
	
	# Multi-stage victory objectives
	var obj1 = QuestObjective.new()
	obj1.id = "build_markets"
	obj1.description = "Control 3 market buildings"
	obj1.type = "build"
	obj1.target = "market"
	obj1.count = 3
	
	var obj2 = QuestObjective.new()
	obj2.id = "accumulate_wealth"
	obj2.description = "Achieve 1000 gold reserves"
	obj2.type = "gather"
	obj2.target = "gold"
	obj2.count = 1000
	
	var obj3 = QuestObjective.new()
	obj3.id = "establish_trade"
	obj3.description = "Establish trade with all factions"
	obj3.type = "relationship"
	obj3.target = "all_factions"
	obj3.count = 3  # Number of factions
	obj3.value = 30  # Minimum relationship needed
	
	var obj4 = QuestObjective.new()
	obj4.id = "build_grand_bazaar"
	obj4.description = "Build the Grand Bazaar wonder"
	obj4.type = "build"
	obj4.target = "grand_bazaar"
	obj4.count = 1
	
	objectives.append(obj1)
	objectives.append(obj2)
	objectives.append(obj3)
	objectives.append(obj4)
	
	# Victory! No material rewards needed
	rewards = {
		"victory": "economic"
	}
	
	requirements = {
		"completed_quest": "main_breakpoint_signs",
		"act": 3
	}
```

## Quest Loading Example

### QuestLibrary Integration

```gdscript
# File: scripts/quests/quest_library.gd
extends Node
class_name QuestLibrary

## Pre-defined quest templates

# Tutorial quests
static func get_tutorial_establishing_settlement() -> Quest:
	var quest = Quest.new()
	# ... (as defined above)
	return quest

# Main story quests
static func get_main_hexagonal_mystery() -> Quest:
	var quest = Quest.new()
	# ... (as defined above)
	return quest

# Helper function to register all quests
static func register_all_quests(quest_manager: QuestManager) -> void:
	# Tutorial quests
	quest_manager.register_quest(get_tutorial_establishing_settlement())
	quest_manager.register_quest(get_tutorial_resource_basics())
	quest_manager.register_quest(get_tutorial_meeting_neighbors())
	
	# Main story quests - Act I
	quest_manager.register_quest(get_main_hexagonal_mystery())
	quest_manager.register_quest(get_main_establishing_power())
	
	# Main story quests - Act II
	quest_manager.register_quest(get_main_awakening())
	quest_manager.register_quest(get_main_sharing_hoarding())
	
	# Faction quests
	quest_manager.register_quest(get_faction_horde_trial())
	quest_manager.register_quest(get_faction_kingdom_trade_route())
	quest_manager.register_quest(get_faction_nomad_sacred_sites())
	
	# Side quests
	quest_manager.register_quest(get_side_lost_caravan())
	quest_manager.register_quest(get_side_singing_stones())
	
	# Repeatable quests
	quest_manager.register_quest(get_repeatable_daily_harvest())
	quest_manager.register_quest(get_repeatable_weekly_exploration())
	
	# Victory quests
	quest_manager.register_quest(get_victory_master_commerce())
	quest_manager.register_quest(get_victory_peacemaker())
	
	print("Registered %d quests" % quest_manager.available_quests.size())
```

## Usage in Main Scene

```gdscript
# In main.gd or similar initialization script
func _ready() -> void:
	# Get or create quest manager
	var quest_manager = QuestManager.new()
	quest_manager.name = "QuestManager"
	add_child(quest_manager)
	
	# Register all quests from library
	QuestLibrary.register_all_quests(quest_manager)
	
	# Connect to quest signals for UI updates
	quest_manager.quest_started.connect(_on_quest_started)
	quest_manager.quest_updated.connect(_on_quest_updated)
	quest_manager.quest_completed.connect(_on_quest_completed)
	quest_manager.objective_completed.connect(_on_objective_completed)
	
	# Auto-start tutorial quest
	if not has_completed_tutorial():
		quest_manager.start_quest(&"tutorial_establishing_settlement")

func _on_quest_started(quest: Quest) -> void:
	# Show quest notification
	var notification_system = get_node_or_null("NotificationSystem")
	if notification_system:
		notification_system.show_notification(
			"New Quest: %s" % quest.title,
			NotificationSystem.NotificationType.INFO
		)

func _on_quest_completed(quest: Quest) -> void:
	# Show completion notification with rewards
	var reward_text = "Rewards: "
	for resource_id in quest.rewards:
		reward_text += "%d %s, " % [quest.rewards[resource_id], resource_id]
	
	var notification_system = get_node_or_null("NotificationSystem")
	if notification_system:
		notification_system.show_notification(
			"Quest Complete: %s\n%s" % [quest.title, reward_text],
			NotificationSystem.NotificationType.SUCCESS
		)
```

## Quest Data Serialization (Save/Load)

```gdscript
# In quest_manager.gd
func save_state() -> Dictionary:
	var state = {
		"active_quests": [],
		"completed_quests": []
	}
	
	# Save active quests with progress
	for quest in active_quests:
		var quest_data = {
			"id": quest.id,
			"state": quest.state,
			"start_time": quest.start_time,
			"objectives": []
		}
		
		for objective in quest.objectives:
			quest_data["objectives"].append({
				"id": objective.id,
				"current": objective.current,
				"value": objective.value  # Save value field for relationship/survive objectives
			})
		
		state["active_quests"].append(quest_data)
	
	# Save completed quest IDs
	for quest_id in completed_quests:
		state["completed_quests"].append(quest_id)
	
	return state


func load_state(state: Dictionary) -> void:
	# Clear current state
	active_quests.clear()
	completed_quests.clear()
	
	# Restore completed quests
	for quest_id in state.get("completed_quests", []):
		completed_quests.append(StringName(quest_id))
	
	# Restore active quests
	for quest_data in state.get("active_quests", []):
		var quest_id = StringName(quest_data["id"])
		if available_quests.has(quest_id):
			var quest: Quest = available_quests[quest_id]
			quest.state = quest_data["state"]
			quest.start_time = quest_data["start_time"]
			
			# Restore objective progress
			for obj_data in quest_data.get("objectives", []):
				for objective in quest.objectives:
					if objective.id == obj_data["id"]:
						objective.current = obj_data["current"]
						break
			
			active_quests.append(quest)
```

---

**Last Updated**: December 27, 2024  
**Version**: 1.0  
**Purpose**: Reference implementation examples for quest system
