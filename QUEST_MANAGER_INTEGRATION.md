# Quest Manager Integration

## Overview

This document describes the integration of the Quest Manager system into the main game scene.

## Changes Made

### 1. Scene Structure Update

**File:** `scenes/main.tscn`

- Renamed root node from "World" to "Main" to match quest system expectations
- Added 6 new system nodes to the scene:
  - `DialogManager` - Manages dialog state and flow
  - `QuestManager` - Core quest state management
  - `QuestGenerator` - Dynamic quest generation from events
  - `NPCQuestController` - NPC quest assignment and tracking
  - `QuestLibrary` - Pre-defined tutorial and faction quests
  - `FactionRelationshipSystem` - Faction relationship tracking

### 2. SaveLoadSystem Update

**File:** `scripts/save_load_system.gd`

- Updated node references from "World" to "Main" to match new scene structure
- Affected methods:
  - `_collect_save_data()` - line 130
  - `_restore_save_data()` - line 185

### 3. Node Hierarchy

All quest system nodes are children of the Main node:

```
Main (Node3D)
├── FactionSystem
├── FactionRelationshipSystem
├── ...
├── DialogManager
├── QuestManager
├── QuestGenerator
├── NPCQuestController
└── QuestLibrary
```

## Quest System Components

### QuestManager
- Path: `/root/Main/QuestManager`
- Manages quest state and progression
- Integrates with BuildController, FactionSystem, and DialogManager
- Provides automatic objective tracking via signals

### QuestGenerator
- Path: `/root/Main/QuestGenerator`
- Generates quests dynamically based on game events
- Responds to resource changes, building events, and faction relationships
- Implements cooldown system to prevent quest spam

### NPCQuestController
- Path: `/root/Main/NPCQuestController`
- Manages NPC quest assignments and autonomous missions
- Allows NPCs to pursue their own quests
- Tracks NPC quest progress and completion

### QuestLibrary
- Path: `/root/Main/QuestLibrary`
- Contains pre-defined tutorial quests
- Provides faction-specific quest templates
- Loads tutorial quests on ready

### DialogManager
- Path: `/root/Main/DialogManager`
- Manages dialog state and flow
- Integrates with quest system for talk objectives
- Emits signals that quest system can track

### FactionRelationshipSystem
- Path: `/root/Main/FactionRelationshipSystem`
- Manages relationships between factions (-100 to +100 scale)
- Emits signals for relationship changes
- Quest generator uses these signals to create diplomacy quests

## Integration Points

### Automatic Objective Tracking

The QuestManager automatically tracks objectives by connecting to system signals:

1. **Build Objectives**: `BuildController.building_placed`
2. **Gather Objectives**: `FactionSystem.resources_changed`
3. **Talk Objectives**: `DialogManager.dialog_ended`

### Dynamic Quest Generation

The QuestGenerator creates quests in response to:

1. **Resource Scarcity**: When resources drop below threshold
2. **Building Destruction**: When important buildings are destroyed
3. **Relationship Changes**: When faction relationships improve or degrade significantly

## Testing

Tests are located in `scripts/tests/test_quest_manager.gd` and include:

1. QuestManager initialization
2. Quest registration
3. Quest lifecycle (start, complete, fail)
4. QuestTemplate instantiation
5. QuestGenerator template loading
6. QuestLibrary quest creation
7. NPC quest assignment
8. NPC quest tracking

Run tests with:
```bash
godot --headless --script scripts/tests/test_quest_manager.gd
```

Tests are automatically run in CI via GitHub Actions workflow: `.github/workflows/test-faction-ai.yml`

## Configuration

### Player Faction
The player's faction can be configured via:
```gdscript
var quest_manager = get_node("/root/Main/QuestManager")
quest_manager.set_player_faction(&"kingdom")

var quest_generator = get_node("/root/Main/QuestGenerator")
quest_generator.set_player_faction(&"kingdom")
```

### Quest Generation Cooldown
Default cooldown is 5 minutes between auto-generated quests. This can be adjusted in QuestGenerator:
```gdscript
quest_generator.min_quest_interval = 300.0  # seconds
```

## Usage Examples

### Starting a Quest
```gdscript
var quest_manager = get_node("/root/Main/QuestManager")
quest_manager.start_quest(StringName("tutorial_first_steps"), &"kingdom")
```

### Getting Active Quests
```gdscript
var quest_manager = get_node("/root/Main/QuestManager")
var active = quest_manager.get_active_quests()
for quest in active:
    print("Active: %s - %0.1f%% complete" % [quest.title, quest.get_progress() * 100])
```

### Assigning Quest to NPC
```gdscript
var npc_quest_controller = get_node("/root/Main/NPCQuestController")
npc_quest_controller.assign_quest_to_npc(
    StringName("merchant_npc"),
    StringName("gather_trade_goods")
)
```

### Auto-Assigning Quest to NPC
```gdscript
var npc_quest_controller = get_node("/root/Main/NPCQuestController")
npc_quest_controller.auto_assign_quest_to_npc(StringName("guard_npc"))
```

## Related Documentation

- [QUEST_SYSTEM.md](QUEST_SYSTEM.md) - Complete quest system design
- [NPC_QUEST_SYSTEM.md](NPC_QUEST_SYSTEM.md) - NPC quest usage guide
- [QUEST_MANAGER_SUMMARY.md](QUEST_MANAGER_SUMMARY.md) - Implementation summary

## Status

✅ Quest Manager system fully integrated into main game scene
✅ All required nodes added to scene tree
✅ Node paths verified for quest system references
✅ SaveLoadSystem updated to match new scene structure
✅ Ready for testing in CI/CD pipeline
