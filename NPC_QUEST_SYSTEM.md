# NPC Quest System

## Overview

The NPC Quest System allows non-player characters to pursue their own missions autonomously. This extends the player-focused Quest System to enable NPCs to have goals, track progress, and complete objectives.

## Architecture

### Components

1. **NPC** - Extended with quest tracking fields
2. **NPCQuestController** - Manages NPC quest assignments and progress
3. **QuestManager** - Shared quest state manager for both players and NPCs

### NPC Quest Fields

The NPC class has been extended with:
- `current_quest_id: StringName` - The quest this NPC is currently pursuing

### NPC Quest Methods

```gdscript
# Assign a quest to the NPC
npc.assign_quest(quest_id)

# Check if NPC has an active quest
if npc.has_active_quest():
    # Do something

# Clear NPC's current quest
npc.clear_quest()
```

## Usage Examples

### Assigning a Quest to an NPC

```gdscript
# Get the NPC quest controller
var npc_quest_controller = get_node("/root/Main/NPCQuestController")

# Assign a specific quest to an NPC
var success = npc_quest_controller.assign_quest_to_npc(
    StringName("merchant_npc"),
    StringName("gather_trade_goods")
)

if success:
    print("Quest assigned to NPC")
```

### Auto-Assigning Quests

```gdscript
# Automatically assign a suitable quest based on NPC's faction
var npc_quest_controller = get_node("/root/Main/NPCQuestController")
var assigned = npc_quest_controller.auto_assign_quest_to_npc(StringName("guard_npc"))

if assigned:
    print("NPC received a new quest")
```

### Tracking NPC Quest Progress

```gdscript
# Update progress for an NPC's quest objective
var npc_quest_controller = get_node("/root/Main/NPCQuestController")
npc_quest_controller.update_npc_quest_progress(
    StringName("worker_npc"),
    "gather_wood",
    25  # Current progress
)
```

### Getting Available Quests for NPCs

```gdscript
# Get quests available for a specific NPC
var npc_quest_controller = get_node("/root/Main/NPCQuestController")
var available_quests = npc_quest_controller.get_available_quests_for_npc(
    StringName("scout_npc")
)

for quest in available_quests:
    print("Available: %s" % quest.title)
```

## Signals

The NPCQuestController emits signals for quest events:

```gdscript
# Emitted when a quest is assigned to an NPC
npc_quest_controller.npc_quest_assigned.connect(_on_npc_quest_assigned)

# Emitted when an NPC completes a quest
npc_quest_controller.npc_quest_completed.connect(_on_npc_quest_completed)

# Emitted when an NPC makes progress on a quest
npc_quest_controller.npc_quest_progress.connect(_on_npc_quest_progress)
```

## Integration with AI Systems

NPCs can use the quest system to drive their behavior:

### Example: NPC AI Integration

```gdscript
# In character_brain.gd or similar AI controller
func _process(delta: float) -> void:
    if not has_active_quest():
        # Try to get a new quest
        _request_new_quest()
    else:
        # Work on current quest
        _pursue_current_quest()


func _request_new_quest() -> void:
    var npc_quest_controller = get_node_or_null("/root/Main/NPCQuestController")
    if npc_quest_controller:
        npc_quest_controller.auto_assign_quest_to_npc(npc_id)


func _pursue_current_quest() -> void:
    var npc = get_npc_data()
    if not npc or not npc.has_active_quest():
        return
    
    var quest_manager = get_node_or_null("/root/Main/QuestManager")
    if not quest_manager:
        return
    
    var quest = quest_manager.get_active_quest(npc.current_quest_id)
    if not quest:
        return
    
    # Get the first incomplete objective
    for objective in quest.objectives:
        if not objective.is_completed():
            _work_on_objective(objective)
            break


func _work_on_objective(objective: QuestObjective) -> void:
    match objective.type:
        "gather":
            _gather_resource(objective.target, objective.count)
        "build":
            _build_structure(objective.target)
        "explore":
            _explore_location(objective.target)
        "talk":
            _talk_to_npc(objective.target)
```

## Quest Types for NPCs

NPCs can pursue the same quest types as players:

1. **Gather** - Collect resources
2. **Build** - Construct buildings
3. **Talk** - Interact with other NPCs
4. **Explore** - Visit locations
5. **Relationship** - Improve faction standing
6. **Survive** - Last for a duration

## Best Practices

### Quest Design for NPCs

1. **Keep objectives simple** - NPCs should be able to complete quests autonomously
2. **Faction-specific quests** - Assign quests that match NPC's faction goals
3. **Reasonable difficulty** - Don't assign quests that are impossible for the NPC to complete
4. **Clear completion criteria** - Objectives should be trackable automatically

### Performance Considerations

1. **Limit active NPC quests** - Not every NPC needs a quest at all times
2. **Use quest priorities** - Important NPCs get quests first
3. **Quest cooldowns** - Don't assign new quests immediately after completion
4. **Batch updates** - Update multiple NPC quest progress in batches

## Future Enhancements

- [ ] NPC quest priorities based on role
- [ ] Cooperative quests between multiple NPCs
- [ ] Quest chains for NPC story arcs
- [ ] Failed quest handling for NPCs
- [ ] Quest generation based on NPC needs
- [ ] Visual indicators for NPCs with quests

## Files

- `scripts/npc.gd` - NPC resource with quest tracking
- `scripts/quests/npc_quest_controller.gd` - NPC quest management
- `scripts/quests/quest_manager.gd` - Shared quest state manager
- `scripts/tests/test_quest_manager.gd` - Tests including NPC quest tests
