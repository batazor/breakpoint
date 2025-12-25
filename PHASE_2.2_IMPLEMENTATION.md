# Phase 2.2 Faction & AI Systems - Implementation Guide

## Overview

This document describes the implementation of Phase 2.2 Faction & AI Systems for Breakpoint. The implementation includes faction relationships, territory control, AI decision-making, and inter-faction interactions.

## Architecture

### Core Systems

#### 1. FactionRelationshipSystem (`faction_relationship_system.gd`)

Manages relationships between factions on a -100 to +100 scale.

**States:**
- **HOSTILE** (≤ -30): Factions are enemies
- **NEUTRAL** (-30 to +30): Factions are neither friends nor enemies
- **ALLIED** (≥ +30): Factions are allies

**Key Features:**
- Symmetrical relationships (A→B = B→A)
- Automatic clamping to valid range
- Signal emission on relationship changes
- Query methods for relationship state

**Usage Example:**
```gdscript
var rel_system = get_node("FactionRelationshipSystem")

# Set initial relationship
rel_system.set_relationship(&"faction_a", &"faction_b", 0.0)

# Modify relationship
rel_system.modify_relationship(&"faction_a", &"faction_b", 15.0)

# Check relationship state
if rel_system.is_allied(&"faction_a", &"faction_b"):
    print("Factions are allies!")

# Listen for changes
rel_system.relationship_changed.connect(_on_relationship_changed)
```

#### 2. FactionTerritorySystem (`faction_territory_system.gd`)

Calculates and tracks faction control over hex tiles based on building influence.

**Influence Calculation:**
- Uses distance decay formula: `influence = base_value / (distance + 1)`
- Buildings radiate influence to surrounding hex tiles
- Faction with highest influence on a tile claims it
- Recalculates periodically (default: every 5 seconds)

**Key Features:**
- Hex ring generation for efficient calculation
- Tile ownership tracking
- Per-tile, per-faction influence values
- Territory count queries
- Signal emission on territory changes

**Usage Example:**
```gdscript
var territory_system = get_node("FactionTerritorySystem")

# Get tile owner
var owner = territory_system.get_tile_owner(Vector2i(5, 5))

# Get faction's territory count
var count = territory_system.get_faction_territory_count(&"faction_a")

# Get specific faction's influence on a tile
var influence = territory_system.get_tile_influence(Vector2i(5, 5), &"faction_a")

# Force recalculation
territory_system.recalculate_all_territory()

# Listen for territory changes
territory_system.territory_changed.connect(_on_territory_changed)
```

#### 3. FactionInteractionSystem (`faction_interaction_system.gd`)

Handles interactions between factions including trade, diplomacy, and conflict.

**Interaction Types:**
- **TRADE**: Resource exchange between factions
- **ALLIANCE_PROPOSAL**: Propose forming an alliance
- **TERRITORY_DISPUTE**: Raise conflict over territory
- **PEACE_OFFERING**: Offer resources to improve relations

**Key Features:**
- Utility-based AI acceptance for trades
- Common enemy detection for alliances
- Resource transfer mechanics
- Relationship integration

**Usage Example:**
```gdscript
var interaction_system = get_node("FactionInteractionSystem")

# Propose a trade
var offer = {"food": 20}
var request = {"coal": 20}
var accepted = interaction_system.propose_trade(
    &"faction_a", 
    &"faction_b", 
    offer, 
    request
)

# Propose an alliance
var allied = interaction_system.propose_alliance(&"faction_a", &"faction_b")

# Raise a territory dispute
interaction_system.raise_territory_dispute(
    &"faction_a", 
    &"faction_b", 
    Vector2i(10, 10)
)

# Offer peace with resources
var peace_offering = {"gold": 50}
var peace_accepted = interaction_system.offer_peace(
    &"faction_a", 
    &"faction_b", 
    peace_offering
)

# Listen for interactions
interaction_system.interaction_accepted.connect(_on_interaction_accepted)
```

### AI Actions

#### FactionActionResourceGathering (`faction_action_resource_gathering.gd`)

Evaluates and prioritizes resource gathering based on faction needs.

**Utility Calculation:**
- Critical threshold (< 20): 2.0x base utility
- Low threshold (< 50): 1.5x base utility
- Moderate (< 100): 1.0x base utility
- Adequate (≥ 100): 0.3x base utility

**Configuration:**
```gdscript
var action = FactionActionResourceGathering.new()
action.id = &"gather_food"
action.resource_type = &"food"
action.critical_threshold = 20
action.low_threshold = 50
action.base_utility = 0.5
action.cooldown = 15.0
```

#### FactionActionExpansion (`faction_action_expansion.gd`)

Evaluates expansion opportunities based on building count and resource availability.

**Utility Calculation:**
- Few buildings + good resources: High priority
- Adequate buildings: Moderate priority
- Many buildings or low resources: Low priority

**Configuration:**
```gdscript
var action = FactionActionExpansion.new()
action.id = &"expand_territory"
action.min_buildings_threshold = 3
action.resource_reserve_threshold = 100
action.base_utility = 0.6
action.cooldown = 20.0
```

#### FactionActionDefense (`faction_action_defense.gd`)

Prioritizes defense based on hostile relationships.

**Utility Calculation:**
- Hostile neighbors present: High priority (multiplied by hostile count)
- No hostiles: Low maintenance priority

**Configuration:**
```gdscript
var action = FactionActionDefense.new()
action.id = &"strengthen_defense"
action.base_utility = 0.4
action.hostile_multiplier = 2.0
action.cooldown = 25.0
```

### FactionAI Integration

The existing `FactionAI` class evaluates all configured actions and selects the best one based on utility scores.

**Decision Process:**
1. Calculate base utility for each action
2. Apply cooldown factor (reduces utility if recently executed)
3. Apply inertia factor (slight bonus for repeating same action)
4. Select action with highest adjusted utility
5. Execute action if above utility threshold

**Configuration Example:**
```gdscript
# In your faction AI node
var faction_ai = FactionAI.new()
faction_ai.faction_id = &"ai_faction_1"
faction_ai.decision_interval = 10.0  # Decide every 10 seconds
faction_ai.utility_threshold = 0.3   # Minimum utility to act

# Add actions
var gather_food = FactionActionResourceGathering.new()
gather_food.id = &"gather_food"
gather_food.resource_type = &"food"
faction_ai.actions.append(gather_food)

var expand = FactionActionExpansion.new()
expand.id = &"expand"
faction_ai.actions.append(expand)

var defend = FactionActionDefense.new()
defend.id = &"defend"
faction_ai.actions.append(defend)
```

## Integration with Main Scene

To integrate these systems into your game, add them to your main scene:

```gdscript
# In main.tscn scene tree:
# - FactionSystem (existing)
# - FactionRelationshipSystem (new)
# - FactionTerritorySystem (new)
# - FactionInteractionSystem (new)
# - FactionAI nodes for each AI faction (existing + enhanced)
```

**Node Paths:**
Each system can reference others via `NodePath` exports or automatic group discovery:

```gdscript
# Option 1: Export paths
@export var faction_system_path: NodePath = NodePath("../FactionSystem")

# Option 2: Use groups (automatic)
var faction_system = get_tree().get_first_node_in_group("faction_system")
```

## Testing

A comprehensive test suite is provided in `scripts/tests/test_faction_ai_systems.gd`.

**Run Tests:**
```bash
godot --headless --script scripts/tests/test_faction_ai_systems.gd
```

**Test Coverage:**
- Faction relationships (set, modify, query states)
- Territory calculation (influence, ownership, hex rings)
- AI action evaluation (resource gathering, expansion, defense)
- Faction interactions (trade, alliances, disputes, peace)
- Cooldown and inertia mechanics
- Resource transfers and utility calculations

## Continuous Integration

A GitHub Actions workflow automatically runs tests on push and pull requests.

**Workflow File:** `.github/workflows/test-faction-ai.yml`

**Runs:**
- Faction & AI system tests
- Existing river generation tests
- Uploads test logs as artifacts

## Future Enhancements

Phase 2.2 provides the foundation for advanced features in future phases:

1. **Visual Territory Display**: Render faction borders and influence overlays on the map
2. **Advanced Trade Negotiations**: Multi-step trade proposals with counter-offers
3. **Combat System**: Use relationships and territory for conflict resolution
4. **Diplomatic Events**: Random events that affect relationships
5. **NPC Task Assignment**: Connect AI decisions to actual NPC behaviors
6. **Building Construction AI**: AI builds structures based on decisions
7. **Alliance Benefits**: Shared vision, combined defense, trade bonuses
8. **Victory Conditions**: Territory control, diplomatic dominance

## API Reference

### FactionRelationshipSystem

#### Methods
- `get_relationship_value(faction_a, faction_b) -> float`
- `get_relationship_state(faction_a, faction_b) -> RelationshipState`
- `set_relationship(faction_a, faction_b, value)`
- `modify_relationship(faction_a, faction_b, delta)`
- `is_hostile(faction_a, faction_b) -> bool`
- `is_neutral(faction_a, faction_b) -> bool`
- `is_allied(faction_a, faction_b) -> bool`
- `get_all_relationships_for_faction(faction_id) -> Dictionary`
- `initialize_relationship(faction_a, faction_b, initial_value)`

#### Signals
- `relationship_changed(faction_a, faction_b, new_value, state)`

### FactionTerritorySystem

#### Methods
- `get_tile_owner(tile_position) -> StringName`
- `get_tile_influence(tile_position, faction_id) -> float`
- `get_faction_territory_count(faction_id) -> int`
- `recalculate_all_territory()`

#### Signals
- `territory_changed(tile_position, new_owner, influence)`

#### Configuration
- `base_influence: float` (default: 100.0)
- `recalculation_interval: float` (default: 5.0)

### FactionInteractionSystem

#### Methods
- `propose_trade(proposer, target, offer, request) -> bool`
- `propose_alliance(proposer, target) -> bool`
- `raise_territory_dispute(faction_a, faction_b, disputed_tile)`
- `offer_peace(proposer, target, resource_offering) -> bool`

#### Signals
- `interaction_proposed(proposer, target, type, data)`
- `interaction_accepted(proposer, target, type)`
- `interaction_rejected(proposer, target, type)`

### FactionAction (Base Class)

#### Properties
- `id: StringName` - Unique identifier
- `cooldown: float` - Seconds before action can repeat at full utility
- `inertia_bias: float` - Penalty for switching actions (0.0-1.0)

#### Methods
- `evaluate(world_state) -> float` - Calculate utility score
- `execute(world_state)` - Perform the action
- `cooldown_factor(now_ts) -> float` - Get cooldown multiplier
- `inertia_factor(last_action_id) -> float` - Get inertia multiplier

## Support

For questions or issues with the Faction & AI systems:
1. Check the test file for usage examples
2. Review inline code documentation
3. Refer to ROADMAP.md for design decisions
4. Check GitHub Issues for known problems

---

**Implementation Date**: December 24, 2024  
**Status**: Complete and Tested  
**Next Phase**: 2.3 Economy & Resources (See ROADMAP.md)
