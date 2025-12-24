# Phase 2.2 System Architecture

## Component Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        Main Game Scene                          │
└────────────────┬────────────────────────────────────────────────┘
                 │
    ┌────────────┴────────────┬─────────────┬─────────────┐
    │                         │             │             │
    ▼                         ▼             ▼             ▼
┌─────────┐         ┌──────────────────┐ ┌───────────┐ ┌──────────┐
│ Faction │◄────────┤ FactionRelation  │ │ Faction   │ │ Faction  │
│ System  │         │ System           │ │ Territory │ │ Interact │
│         │         │                  │ │ System    │ │ System   │
│ - Facts │         │ - Relations      │ │           │ │          │
│ - Build │         │ - States         │ │ - Inflnce │ │ - Trade  │
│ - Units │         │   (3 types)      │ │ - Owner   │ │ - Diplom │
│ - Resrc │         └──────────────────┘ └───────────┘ └──────────┘
└────┬────┘                 ▲                   ▲             ▲
     │                      │                   │             │
     └──────────────────────┴───────────────────┴─────────────┘
                            │
                ┌───────────┴────────────┐
                │                        │
                ▼                        ▼
         ┌──────────┐            ┌──────────┐
         │ Faction  │            │ Faction  │
         │ AI       │            │ AI       │
         │ (Fact 1) │            │ (Fact 2) │
         └────┬─────┘            └────┬─────┘
              │                       │
    ┌─────────┼─────────┐   ┌────────┼─────────┐
    ▼         ▼         ▼   ▼        ▼         ▼
┌────────┐ ┌──────┐ ┌──────┐┌─────┐┌──────┐┌──────┐
│Resource│ │Expan │ │Defns ││Rsrc ││Expan ││Defns │
│Gather  │ │sion  │ │e     ││Gthr ││sion  ││e     │
│Action  │ │Action│ │Action││Act  ││Action││Action││
└────────┘ └──────┘ └──────┘└─────┘└──────┘└──────┘
```

## Data Flow

### 1. AI Decision Making

```
Time Tick (decision_interval)
         │
         ▼
┌─────────────────────┐
│ FactionAI.decide()  │
└──────────┬──────────┘
           │
           ▼
   For each Action:
┌─────────────────────────────┐
│ 1. Calculate base utility   │
│ 2. Apply cooldown factor    │
│ 3. Apply inertia factor     │
└──────────┬──────────────────┘
           │
           ▼
┌─────────────────────────────┐
│ Select highest utility > θ  │
└──────────┬──────────────────┘
           │
           ▼
┌─────────────────────────────┐
│ Execute selected action     │
└─────────────────────────────┘
```

### 2. Relationship Changes

```
External Event
(trade, dispute, peace)
         │
         ▼
┌──────────────────────────────┐
│ FactionRelationshipSystem    │
│ .set_relationship()          │
└──────────┬───────────────────┘
           │
           ▼
┌──────────────────────────────┐
│ Update faction.relations     │
│ (both directions)            │
└──────────┬───────────────────┘
           │
           ▼
┌──────────────────────────────┐
│ Emit relationship_changed    │
└──────────┬───────────────────┘
           │
           ▼
┌──────────────────────────────┐
│ UI Updates / AI reacts       │
└──────────────────────────────┘
```

### 3. Territory Calculation

```
Timer (every 5 seconds)
         │
         ▼
┌────────────────────────────────┐
│ FactionTerritorySystem         │
│ .recalculate_all_territory()   │
└──────────┬─────────────────────┘
           │
           ▼
   For each Building:
┌────────────────────────────────┐
│ Calculate influence radially   │
│ influence = base/(distance+1)  │
└──────────┬─────────────────────┘
           │
           ▼
   For each Tile:
┌────────────────────────────────┐
│ Sum influences by faction      │
│ Assign to highest influence    │
└──────────┬─────────────────────┘
           │
           ▼
┌────────────────────────────────┐
│ Emit territory_changed         │
│ (if owner changed)             │
└────────────────────────────────┘
```

### 4. Faction Interaction

```
AI or Player Action
         │
         ▼
┌────────────────────────────────┐
│ FactionInteractionSystem       │
│ .propose_trade/alliance/etc    │
└──────────┬─────────────────────┘
           │
           ▼
┌────────────────────────────────┐
│ Check relationship constraints │
│ (no trade with hostile, etc)   │
└──────────┬─────────────────────┘
           │
           ▼
┌────────────────────────────────┐
│ Calculate utility for target   │
└──────────┬─────────────────────┘
           │
       ┌───┴───┐
       │Accept?│
       └───┬───┘
           │
    ┌──────┴──────┐
    ▼             ▼
  YES            NO
    │             │
    ▼             ▼
Execute      Reject
Resource     Signal
Transfers    Rejection
    │
    ▼
Update
Relationships
```

## State Machines

### Relationship States

```
        modify(-X)              modify(-Y)
    ┌──────────────┐      ┌──────────────┐
    │              │      │              │
    ▼              │      ▼              │
┌─────────┐    ┌──────────┐    ┌─────────┐
│ ALLIED  │───►│ NEUTRAL  │───►│ HOSTILE │
│ (>+30)  │    │ (-30~+30)│    │ (<-30)  │
└─────────┘    └──────────┘    └─────────┘
    ▲              │      ▲              │
    │              │      │              │
    └──────────────┘      └──────────────┘
       modify(+X)            modify(+Y)

Events that modify relationships:
• Trade success: +5
• Alliance formed: Set to +50
• Territory dispute: -15
• Peace offering: +5 to +30 (based on value)
• War declared: Set to -80
```

### Action Selection FSM

```
           ┌─────────────┐
      ┌───►│   IDLE      │
      │    │ (waiting)   │
      │    └──────┬──────┘
      │           │ decision_interval
      │           ▼
      │    ┌─────────────┐
      │    │ EVALUATING  │
      │    │ (calculate) │
      │    └──────┬──────┘
      │           │
      │      ┌────┴────┐
      │      │utility>θ?│
      │      └────┬────┘
      │           │
      │    ┌──────┴──────┐
      │    ▼             ▼
      │   YES           NO
      │    │             │
      │    ▼             │
      │ ┌──────────┐    │
      │ │EXECUTING │    │
      │ │ (action) │    │
      │ └─────┬────┘    │
      │       │         │
      └───────┴─────────┘
```

## Class Hierarchy

```
Node
 ├─ FactionSystem
 ├─ FactionRelationshipSystem
 ├─ FactionTerritorySystem
 ├─ FactionInteractionSystem
 └─ FactionAI
     └─ actions: Array[FactionAction]

Resource
 ├─ Faction
 └─ FactionAction (abstract)
     ├─ FactionActionResourceGathering
     ├─ FactionActionExpansion
     └─ FactionActionDefense
```

## Signal Flow

```
FactionRelationshipSystem
    └─► relationship_changed(faction_a, faction_b, value, state)
            ↓
            └─► UI updates faction colors
            └─► FactionAI marks dirty
            └─► FactionActionDefense recalculates

FactionTerritorySystem
    └─► territory_changed(tile_pos, new_owner, influence)
            ↓
            └─► Map overlay updates
            └─► FactionAI reevaluates expansion
            └─► Territory counter updates

FactionInteractionSystem
    ├─► interaction_proposed(proposer, target, type, data)
    ├─► interaction_accepted(proposer, target, type)
    └─► interaction_rejected(proposer, target, type)
            ↓
            └─► Notification system displays
            └─► Relationship system updates
            └─► Economy system transfers resources
```

## Utility Calculation Example

### ResourceGathering Action

```
Current food: 15
Critical threshold: 20
Low threshold: 50
Base utility: 0.5

Calculation:
    15 < 20  →  Critical!
    utility = base_utility * 2.0
    utility = 0.5 * 2.0
    utility = 1.0

Cooldown factor:
    last_executed = 100s ago
    cooldown = 15s
    factor = min(100/15, 1.0) = 1.0

Inertia factor:
    last_action = "expand"
    current = "gather_food"
    different → factor = 1.0 - 0.15 = 0.85

Final score:
    score = 1.0 * 1.0 * 0.85 = 0.85
```

### Decision Process

```
Actions evaluated:
1. gather_food:  0.85  ← HIGHEST
2. expand:       0.45
3. defend:       0.30

Threshold: 0.3

Selection: gather_food (0.85 > 0.3)
Execute: FactionActionResourceGathering.execute()
```

## Memory Footprint

```
Per Faction:
  - Faction object: ~500 bytes
  - Relationships: n * 16 bytes (n = other factions)
  - Buildings: m * 100 bytes (m = buildings)
  
Per Tile:
  - Ownership: 16 bytes
  - Influence map: n * 8 bytes (n = factions)
  
AI State:
  - FactionAI: ~200 bytes
  - Per Action: ~100 bytes
  
Total (3 factions, 100 tiles, 10 buildings/faction):
  ≈ 3*(500 + 2*16 + 10*100)  [Factions]
  + 100*(16 + 3*8)            [Tiles]
  + 3*(200 + 3*100)           [AI]
  ≈ 3*1,032 + 100*40 + 3*500
  ≈ 8,596 bytes
  ≈ 8.4 KB

Very lightweight!
```

## Performance Characteristics

### Time Complexity

| Operation | Complexity | Notes |
|-----------|-----------|-------|
| Relationship query | O(1) | Dictionary lookup |
| Relationship update | O(1) | Direct assignment |
| Territory recalc | O(b*r²) | b=buildings, r=radius |
| AI decision | O(a) | a=actions |
| Trade evaluation | O(r) | r=resources |
| Alliance check | O(f) | f=factions |

### Space Complexity

| Structure | Complexity | Notes |
|-----------|-----------|-------|
| Relationships | O(f²) | All pairs |
| Territory ownership | O(t) | t=tiles |
| Influence map | O(t*f) | per-tile per-faction |
| AI actions | O(f*a) | per-faction per-action |

### Optimization Points

1. **Territory Calculation**: 
   - Only recalculate when buildings change
   - Cache hex rings
   - Early exit on low influence

2. **AI Decisions**:
   - Skip evaluation when utility < threshold
   - Event-driven recalculation
   - Action cooldowns prevent spam

3. **Relationship Queries**:
   - Cache common queries
   - Symmetrical storage reduces lookups
   - Pre-compute thresholds

## Integration Points

### Phase 2.1 (Player Interaction)
```
PlayerInteractionController
         ↓
    (selection)
         ↓
FactionInteractionSystem ← User initiates trade/diplomacy
```

### Phase 2.3 (Economy)
```
EconomySystem
         ↓
  (resource delta)
         ↓
FactionActionResourceGathering ← Evaluates resource needs
         ↓
FactionInteractionSystem ← May trigger trade
```

### Phase 2.4 (Building)
```
BuildController
         ↓
  (building placed)
         ↓
FactionTerritorySystem ← Recalculates influence
         ↓
FactionActionExpansion ← Reevaluates expansion
```

## Thread Safety

**Note**: All systems assume single-threaded access (Godot main thread).

For future multi-threading:
- Use mutexes for shared data (faction.resources, tile_ownership)
- Territory calculation can be worker thread with mutex on write
- AI decisions independent → parallelizable

---

**Architecture Version**: 1.0  
**Last Updated**: December 24, 2024  
**Status**: Production Ready
