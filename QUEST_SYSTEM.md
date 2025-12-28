# Quest System

## Overview

The Quest System provides **dynamic, event-driven objectives** that emerge from gameplay in Breakpoint's sandbox environment. Rather than pre-scripted linear quests, the system **generates quests procedurally** based on game events, faction activities, resource states, and player actions. It integrates with the existing dialog system, faction relationships, and resource management to create organic gameplay experiences.

## Design Philosophy: Sandbox-Driven Quests

Breakpoint is a **sandbox strategy game**, not a narrative-driven RPG. Therefore, quests are:
- **Event-triggered**: Generated in response to game state changes
- **Procedural**: Objectives and rewards are assembled from templates and parameterized by current context
- **Emergent**: Arise from faction interactions and world events
- **Optional**: Players drive their own narrative through choices
- **Dynamic**: Quest availability is state-based, changing as overall game state and player actions evolve

**Hybrid Approach**: The system uses **80% procedurally-generated quests** (from templates triggered by events) and **20% pre-scripted quests** (tutorials and major story beats that are still event-triggered). All quests are optional - players can focus purely on sandbox strategy.

## Architecture

### Core Components

1. **Quest** - Resource class defining quest data
2. **QuestObjective** - Individual objectives within a quest
3. **QuestManager** - Singleton managing quest state and generation
4. **QuestGenerator** - Procedural quest creation from events
5. **QuestTemplate** - Flexible templates for different quest types
6. **QuestUI** - User interface for quest tracking

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

## Event-Driven Quest Generation

### Quest Generation Philosophy

Instead of pre-scripted quests, the system **generates quests dynamically** based on game events:

**Example Triggers**:
- **Resource Scarcity**: Food drops below 50 → Generate "Emergency Harvest" quest
- **Faction Conflict**: Horde attacks Kingdom territory → Generate "Border Defense" quest  
- **Building Destroyed**: Mine destroyed by event → Generate "Rebuild Infrastructure" quest
- **NPC Request**: Trader NPC arrives → Generate "Supply Trade" quest
- **Discovery**: Player finds ancient ruins → Generate "Investigate Ruins" quest
- **Time-Based**: 10 in-game days pass → Generate "Expansion Opportunity" quest

### Quest Generator (scripts/quests/quest_generator.gd)

```gdscript
extends Node
class_name QuestGenerator

## Generates quests dynamically based on game events

signal quest_generated(quest: Quest)

var quest_templates: Dictionary = {}  # template_id -> QuestTemplate
var generation_rules: Array[QuestGenerationRule] = []


func _ready() -> void:
	_load_templates()
	_setup_generation_rules()
	_connect_to_game_events()


func _connect_to_game_events() -> void:
	## Connect to game systems to listen for quest-triggering events
	
	# Resource events
	var faction_system = get_node_or_null("/root/Main/FactionSystem")
	if faction_system:
		faction_system.resources_changed.connect(_on_resources_changed)
	
	# Building events
	var build_controller = get_node_or_null("/root/Main/BuildController")
	if build_controller:
		build_controller.building_placed.connect(_on_building_placed)
		build_controller.building_destroyed.connect(_on_building_destroyed)
	
	# Faction events
	if faction_system:
		faction_system.relationship_changed.connect(_on_relationship_changed)
	
	# Time events
	var day_night_cycle = get_node_or_null("/root/Main/DayNightCycle")
	if day_night_cycle:
		day_night_cycle.hour_changed.connect(_on_hour_changed)


func _on_resources_changed(faction_id: StringName, resource_id: StringName, amount: int) -> void:
	## Generate quests based on resource state
	var faction_system = get_node_or_null("/root/Main/FactionSystem")
	if not faction_system:
		return
	
	var current_amount = faction_system.resource_amount(faction_id, resource_id)
	
	# Resource scarcity quest
	if current_amount < 50:
		var quest = _generate_from_template("resource_scarcity", {
			"resource_id": resource_id,
			"target_amount": 100,
			"faction_id": faction_id
		})
		if quest:
			quest_generated.emit(quest)


func _on_building_destroyed(building_id: String, position: Vector2i, faction_id: StringName) -> void:
	## Generate rebuild quest when important buildings are destroyed
	if building_id in ["fortress", "mine", "well"]:
		var quest = _generate_from_template("rebuild_structure", {
			"building_id": building_id,
			"position": position,
			"faction_id": faction_id
		})
		if quest:
			quest_generated.emit(quest)


func _on_relationship_changed(faction1: StringName, faction2: StringName, old_value: int, new_value: int) -> void:
	## Generate diplomacy quests based on relationship changes
	
	# Relationship improved significantly
	if new_value > old_value + 20 and new_value > 50:
		var quest = _generate_from_template("alliance_opportunity", {
			"faction1": faction1,
			"faction2": faction2,
			"relationship": new_value
		})
		if quest:
			quest_generated.emit(quest)
	
	# Relationship deteriorated significantly (using same threshold for consistency)
	elif new_value < old_value - 20 and new_value < -50:
		var quest = _generate_from_template("conflict_resolution", {
			"faction1": faction1,
			"faction2": faction2,
			"relationship": new_value
		})
		if quest:
			quest_generated.emit(quest)


func _generate_from_template(template_id: String, context: Dictionary) -> Quest:
	## Generate a quest instance from a template with given context
	if not quest_templates.has(template_id):
		push_error("Quest template not found: %s" % template_id)
		return null
	
	var template: QuestTemplate = quest_templates[template_id]
	return template.instantiate(context)


func _load_templates() -> void:
	## Load quest templates
	# Templates define quest structure with placeholders for context
	quest_templates["resource_scarcity"] = QuestTemplate.new({
		"title_pattern": "Gather {resource_name}",
		"description_pattern": "Your {resource_name} reserves are critically low. Gather {target_amount} {resource_name} to stabilize your economy.",
		"objective_type": "gather",
		"reward_scale": 1.5  # Rewards scale with difficulty
	})
	
	quest_templates["rebuild_structure"] = QuestTemplate.new({
		"title_pattern": "Rebuild {building_name}",
		"description_pattern": "Your {building_name} has been destroyed. Rebuild it to restore production.",
		"objective_type": "build",
		"reward_scale": 1.0
	})
	
	quest_templates["alliance_opportunity"] = QuestTemplate.new({
		"title_pattern": "Strengthen Alliance with {faction_name}",
		"description_pattern": "Your improving relationship with {faction_name} opens opportunities for cooperation.",
		"objective_type": "relationship",
		"reward_scale": 2.0
	})
	
	quest_templates["conflict_resolution"] = QuestTemplate.new({
		"title_pattern": "Resolve Conflict with {faction_name}",
		"description_pattern": "Tensions with {faction_name} are escalating. Take action to prevent war.",
		"objective_type": "relationship",
		"reward_scale": 1.5
	})
```

### Quest Template (scripts/quests/quest_template.gd)

```gdscript
extends Resource
class_name QuestTemplate

## Template for generating quests with context

var title_pattern: String = ""
var description_pattern: String = ""
var objective_type: String = ""
var reward_scale: float = 1.0
var category: String = "dynamic"


func instantiate(context: Dictionary) -> Quest:
	## Create a quest instance from this template with given context
	var quest = Quest.new()
	quest.id = StringName("dynamic_%d" % Time.get_ticks_msec())
	quest.category = category
	
	# Fill in template placeholders with context
	quest.title = _fill_pattern(title_pattern, context)
	quest.description = _fill_pattern(description_pattern, context)
	
	# Generate objectives based on type and context
	var objective = QuestObjective.new()
	objective.type = objective_type
	
	match objective_type:
		"gather":
			objective.target = context.get("resource_id", "gold")
			objective.count = context.get("target_amount", 100)
			objective.description = "Gather %d %s" % [objective.count, objective.target]
		
		"build":
			objective.target = context.get("building_id", "fortress")
			objective.count = 1
			objective.description = "Build 1 %s" % objective.target
		
		"relationship":
			objective.target = context.get("faction2", "")
			objective.value = context.get("target_relationship", 50)
			objective.description = "Achieve relationship %d with %s" % [objective.value, objective.target]
	
	quest.objectives.append(objective)
	
	# Calculate rewards based on difficulty and context
	quest.rewards = _calculate_rewards(context, reward_scale)
	quest.faction_id = context.get("faction_id", &"kingdom")
	
	return quest


func _fill_pattern(pattern: String, context: Dictionary) -> String:
	## Replace {placeholder} with values from context
	var result = pattern
	for key in context:
		var placeholder = "{%s}" % key
		if result.contains(placeholder):
			result = result.replace(placeholder, str(context[key]))
	return result


func _calculate_rewards(context: Dictionary, scale: float) -> Dictionary:
	## Calculate appropriate rewards based on quest difficulty
	var base_gold = 50
	var rewards = {}
	
	# Scale rewards based on context
	if context.has("target_amount"):
		rewards["gold"] = int(base_gold * scale * (context["target_amount"] / 100.0))
	else:
		rewards["gold"] = int(base_gold * scale)
	
	return rewards
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
	
	# Connect to quest generator for dynamic quests
	var quest_generator = get_node_or_null("/root/Main/QuestGenerator")
	if quest_generator:
		quest_generator.quest_generated.connect(_on_quest_generated)


func _on_quest_generated(quest: Quest) -> void:
	## Handle dynamically generated quest
	# Auto-register and optionally auto-start based on urgency
	register_quest(quest)
	
	# Notify player of new quest opportunity
	print("New quest available: %s" % quest.title)
	# Emit signal for UI notification
	quest_started.emit(quest) if quest.category == "urgent" else quest_updated.emit(quest)


func _connect_to_systems() -> void:
	# Connect to build controller for build objectives
	var build_controller = get_node_or_null("/root/Main/BuildController")
	if build_controller:
		build_controller.building_placed.connect(_on_building_placed)
	
	# Connect to faction system for resource objectives
	var faction_system = get_node_or_null("/root/Main/FactionSystem")
	if faction_system:
		faction_system.resources_changed.connect(_on_resources_changed)
	
	# Connect to dialog manager for talk objectives
	var dialog_manager = get_node_or_null("/root/Main/DialogManager")
	if dialog_manager:
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
	# TODO: Get player faction ID from game configuration instead of hardcoded value
	if faction_id != &"kingdom":
		return
	
	for quest in active_quests:
		for objective in quest.objectives:
			if objective.type == "gather" and StringName(objective.target) == resource_id:
				# Check total resource amount
				var faction_system = get_node_or_null("/root/Main/FactionSystem")
				if faction_system:
					if faction_system.has_method("resource_amount"):
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

## Hybrid Approach: Dynamic + Scripted Quests

While the core quest system is **event-driven and dynamic** to support sandbox gameplay, the system also supports **optional scripted quests** for:

### Scripted Quest Use Cases

1. **Tutorial Quests** - Onboarding sequence teaching core mechanics
   - "Establishing Your Settlement" - Build first fortress
   - "Resource Basics" - Understand economy system
   - These are pre-defined but can still be triggered by events (e.g., game start)

2. **Major Story Moments** - Optional narrative content
   - "The Awakening" - Discover ancient technology (triggered by exploring specific hex)
   - "The Choice" - Major decision point (triggered when player controls 30% of map)
   - These provide narrative flavor but don't restrict sandbox freedom

3. **Faction-Specific Content** - Identity quests for each faction
   - Kingdom: "Diplomatic Summit" (triggered when allied with 2+ factions)
   - Horde: "Trial of Strength" (triggered after building barracks)
   - Nomads: "Sacred Sites" (triggered when discovering natural wonders)

### Balance Between Dynamic and Scripted

- **80% Dynamic**: Most quests generated from gameplay events
- **20% Scripted**: Tutorial, major story beats, faction identity quests
- **Player Choice**: All quests optional; players can ignore them entirely
- **Organic Triggers**: Even scripted quests triggered by game state, not forced

### Quest Library Role

The QuestLibrary provides:
- **Templates** for quest generation (not pre-scripted quests)
- **Tutorial sequences** that can be disabled after first playthrough
- **Faction quest patterns** that QuestGenerator can reference
- **Story moment triggers** for players who want narrative context

## Future Enhancements

- [x] **Dynamic quest generation** - Core feature (implemented above)
- [ ] Quest chains with branching paths
- [ ] Timed quests with failure conditions
- [ ] Multiplayer quest cooperation
- [ ] Quest rewards: buildings, units, abilities
- [ ] Quest journal with lore entries
- [ ] Achievement system integration
- [ ] Quest difficulty scaling based on player power
- [ ] Secret/hidden quests revealed by exploration
- [ ] Community-driven quest templates (modding)

## Files

Quest system files to be created:
- `scripts/quests/quest.gd` - Quest resource
- `scripts/quests/quest_objective.gd` - Objective resource
- `scripts/quests/quest_manager.gd` - Quest state manager
- `scripts/quests/quest_generator.gd` - **Dynamic quest generation** ⭐
- `scripts/quests/quest_template.gd` - **Template for procedural quests** ⭐
- `scripts/quests/quest_library.gd` - Templates and tutorial quests
- `scripts/ui/quest_log_panel.gd` - Quest UI controller
- `scenes/ui/quest_log_panel.tscn` - Quest UI scene
- `scenes/ui/quest_tracker.tscn` - HUD quest tracker
