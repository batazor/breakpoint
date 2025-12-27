# Quest System

## Overview

The Quest System provides structured objectives, narrative progression, and rewards for players in Breakpoint. It integrates with the existing dialog system, faction relationships, and resource management to create engaging gameplay experiences.

## Architecture

### Core Components

1. **Quest** - Resource class defining quest data
2. **QuestObjective** - Individual objectives within a quest
3. **QuestManager** - Singleton managing quest state
4. **QuestUI** - User interface for quest tracking
5. **QuestLibrary** - Pre-defined quest templates

### Quest Structure

```
Quest
├── id: StringName - Unique identifier
├── title: String - Display name
├── description: String - Quest overview
├── category: QuestCategory - Main, Side, Faction, Repeatable
├── objectives: Array[QuestObjective] - List of objectives
├── rewards: Dictionary - Resources and unlocks
├── requirements: Dictionary - Prerequisites to start quest
├── state: QuestState - NotStarted, Active, Completed, Failed
├── faction_id: StringName - Associated faction
├── npc_giver: StringName - NPC who gives the quest
├── dialog_start: String - Dialog tree ID for quest start
├── dialog_complete: String - Dialog tree ID for completion
└── next_quest_id: StringName - Follow-up quest
```

### Quest Objective Types

1. **Build** - Construct specific buildings
   - `type: "build"`
   - `target: "fortress"` - Building ID
   - `count: 2` - Number required
   - `current: 0` - Current progress

2. **Gather** - Collect resources
   - `type: "gather"`
   - `target: "gold"` - Resource ID
   - `count: 100` - Amount needed
   - `current: 0` - Current amount

3. **Talk** - Speak with NPCs
   - `type: "talk"`
   - `target: "elder_npc"` - NPC ID
   - `dialog_id: "quest_dialog"` - Specific dialog tree

4. **Explore** - Discover map locations
   - `type: "explore"`
   - `target: "ruins"` - Location type or hex coordinates
   - `count: 3` - Number of locations

5. **Relationship** - Achieve faction standing
   - `type: "relationship"`
   - `target: "kingdom"` - Faction ID
   - `value: 50` - Relationship threshold

6. **Survive** - Last for duration
   - `type: "survive"`
   - `duration_hours: 24` - In-game hours
   - `elapsed: 0` - Time passed

7. **Defeat** - Combat objectives (future)
   - `type: "defeat"`
   - `target: "bandits"` - Enemy type
   - `count: 5` - Number to defeat

### Quest Categories

- **Main Quest** - Core storyline progression
- **Side Quest** - Optional narrative content
- **Faction Quest** - Faction-specific objectives
- **Repeatable Quest** - Can be completed multiple times
- **Tutorial Quest** - Onboarding and learning

### Quest States

```gdscript
enum QuestState {
	NOT_STARTED,  # Quest available but not accepted
	ACTIVE,       # Quest in progress
	COMPLETED,    # Quest finished successfully
	FAILED,       # Quest failed (optional)
	ABANDONED     # Player abandoned quest
}
```

## Implementation

### Quest Resource (scripts/quests/quest.gd)

```gdscript
extends Resource
class_name Quest

@export var id: StringName
@export var title: String = ""
@export var description: String = ""
@export var category: String = "side"  # main, side, faction, repeatable
@export var objectives: Array[QuestObjective] = []
@export var rewards: Dictionary = {}  # resource_id -> amount
@export var requirements: Dictionary = {}  # quest_id -> true, level -> int, etc.
@export var faction_id: StringName = &""
@export var npc_giver: StringName = &""
@export var dialog_start: String = ""
@export var dialog_complete: String = ""
@export var next_quest_id: StringName = &""
@export var repeatable: bool = false
@export var time_limit_hours: float = 0.0  # 0 = no limit

var state: int = 0  # QuestState enum
var start_time: float = 0.0
var completion_time: float = 0.0


func is_completed() -> bool:
	if objectives.is_empty():
		return false
	for objective in objectives:
		if not objective.is_completed():
			return false
	return true


func get_progress() -> float:
	if objectives.is_empty():
		return 0.0
	var total := 0.0
	for objective in objectives:
		total += objective.get_progress()
	return total / float(objectives.size())


func can_start(player_faction_id: StringName) -> bool:
	# Check requirements
	if requirements.has("faction") and requirements["faction"] != player_faction_id:
		return false
	
	# Check if quest is already active or completed (unless repeatable)
	if not repeatable and (state == 2 or state == 1):  # COMPLETED or ACTIVE
		return false
	
	return true
```

### Quest Objective (scripts/quests/quest_objective.gd)

```gdscript
extends Resource
class_name QuestObjective

@export var id: String = ""
@export var description: String = ""
@export var type: String = ""  # build, gather, talk, explore, relationship, survive
@export var target: String = ""  # Building ID, Resource ID, NPC ID, etc.
@export var count: int = 1
@export var current: int = 0
@export var value: float = 0.0  # For relationship or other float values
@export var optional: bool = false
@export var hidden: bool = false  # Don't show to player initially


func is_completed() -> bool:
	match type:
		"build", "gather", "talk", "explore", "defeat":
			return current >= count
		"relationship":
			return current >= value
		"survive":
			return current >= value  # value is duration
		_:
			return false


func get_progress() -> float:
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
	current += amount
```

### Quest Manager (scripts/quests/quest_manager.gd)

```gdscript
extends Node
class_name QuestManager

signal quest_started(quest: Quest)
signal quest_updated(quest: Quest)
signal quest_completed(quest: Quest)
signal quest_failed(quest: Quest)
signal objective_completed(quest: Quest, objective: QuestObjective)

var active_quests: Array[Quest] = []
var completed_quests: Array[StringName] = []
var available_quests: Dictionary = {}  # quest_id -> Quest


func _ready() -> void:
	# Connect to game systems
	_connect_to_systems()


func _connect_to_systems() -> void:
	# Connect to build controller for build objectives
	var build_controller = get_node_or_null("/root/Main/BuildController")
	if build_controller and build_controller.has_signal("building_placed"):
		build_controller.building_placed.connect(_on_building_placed)
	
	# Connect to faction system for resource objectives
	var faction_system = get_node_or_null("/root/Main/FactionSystem")
	if faction_system and faction_system.has_signal("resources_changed"):
		faction_system.resources_changed.connect(_on_resources_changed)
	
	# Connect to dialog manager for talk objectives
	var dialog_manager = get_node_or_null("/root/Main/DialogManager")
	if dialog_manager and dialog_manager.has_signal("dialog_ended"):
		dialog_manager.dialog_ended.connect(_on_dialog_ended)


func register_quest(quest: Quest) -> void:
	## Register a quest to make it available
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
	
	quest.state = 1  # ACTIVE
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
	
	quest.state = 2  # COMPLETED
	quest.completion_time = Time.get_ticks_msec() / 1000.0
	active_quests.erase(quest)
	completed_quests.append(quest_id)
	
	# Give rewards
	_give_rewards(quest)
	
	quest_completed.emit(quest)
	
	# Start next quest if specified
	if not quest.next_quest_id.is_empty():
		call_deferred("start_quest", quest.next_quest_id)


func _give_rewards(quest: Quest) -> void:
	## Apply quest rewards to player
	var faction_system = get_node_or_null("/root/Main/FactionSystem")
	if not faction_system:
		return
	
	# TODO: Get player faction ID from game configuration
	var player_faction_id := &"kingdom"
	
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
	# TODO: Get player faction ID
	if faction_id != &"kingdom":
		return
	
	for quest in active_quests:
		for objective in quest.objectives:
			if objective.type == "gather" and StringName(objective.target) == resource_id:
				# Check total resource amount
				var faction_system = get_node_or_null("/root/Main/FactionSystem")
				if faction_system and faction_system.has_method("resource_amount"):
					var current_amount = faction_system.resource_amount(faction_id, resource_id)
					if current_amount >= objective.count:
						objective.current = objective.count
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
```

## UI Integration

### Quest Log Panel

Display active and completed quests:

- **Active Quests Tab**
  - Quest title and description
  - Objective list with progress bars
  - Rewards preview
  - Time remaining (if applicable)

- **Completed Quests Tab**
  - Quest archive
  - Completion time
  - Rewards received

### Quest Tracker HUD

Minimized quest tracker on main game screen:
- Current primary quest
- 1-3 active objectives
- Progress indicators
- Click to expand to full quest log

### Quest Notification

Toast notifications for:
- New quest available
- Quest started
- Objective completed
- Quest completed
- Quest failed

## Integration with Existing Systems

### Dialog System

Quests integrate with the dialog system:

1. **Quest Givers** - NPCs can offer quests through dialog
2. **Dialog Trees** - Special dialog IDs for quest start/completion
3. **Quest Conditions** - Dialog responses can check quest state
4. **Quest Rewards** - Completing dialog can advance objectives

Example dialog integration:
```gdscript
# In dialog_library.gd
var quest_dialog = DialogLine.new()
quest_dialog.text = "I need your help! Will you accept this quest?"

var accept_response = DialogResponse.new()
accept_response.text = "Yes, I'll help you."
accept_response.effect = "start_quest:gather_resources"

quest_dialog.responses = [accept_response]
```

### Faction System

Quest progression affects faction relationships:
- Completing faction quests improves standing
- Quest rewards include faction reputation
- Some quests require minimum faction level

### Economy System

Quests interact with the economy:
- Resource gathering objectives
- Building construction objectives
- Resource rewards on completion
- Optional resource costs to start quests

## Quest Library

Pre-defined quest templates in `scripts/quests/quest_library.gd`:

### Tutorial Quests
- **First Steps** - Build your first well
- **Growing Settlement** - Construct 3 buildings
- **Resource Management** - Gather 50 food

### Main Story Quests
- **The Founding** - Establish your faction's presence
- **Ancient Ruins** - Discover mysterious locations
- **The Great Alliance** - Form alliances with other factions
- **Final Confrontation** - Achieve victory conditions

### Faction Quests
- **Kingdom** - Diplomatic and economic missions
- **Barbarians** - Combat and expansion challenges
- **Nomads** - Exploration and survival tasks

### Repeatable Quests
- **Daily Tribute** - Gather resources daily
- **Scout Report** - Explore new hexes
- **Trade Mission** - Exchange resources

## Future Enhancements

- [ ] Quest chains with branching paths
- [ ] Timed quests with failure conditions
- [ ] Dynamic quest generation
- [ ] Multiplayer quest cooperation
- [ ] Quest rewards: buildings, units, abilities
- [ ] Quest journal with lore entries
- [ ] Achievement system integration
- [ ] Quest difficulty scaling
- [ ] Secret/hidden quests

## Files

Quest system files to be created:
- `scripts/quests/quest.gd` - Quest resource
- `scripts/quests/quest_objective.gd` - Objective resource
- `scripts/quests/quest_manager.gd` - Quest state manager
- `scripts/quests/quest_library.gd` - Pre-defined quests
- `scripts/ui/quest_log_panel.gd` - Quest UI controller
- `scenes/ui/quest_log_panel.tscn` - Quest UI scene
- `scenes/ui/quest_tracker.tscn` - HUD quest tracker
