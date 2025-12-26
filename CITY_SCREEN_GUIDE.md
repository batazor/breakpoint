# City Screen UI - Feature Documentation

## Overview
The City Screen provides a dedicated interface for managing city buildings within settlements. This feature was implemented to support complex building management without cluttering the hex map.

## Features

### Available Buildings (8 types)

1. **Archery Range**
   - Training facility for archers and ranged units
   - Cost: 30 food, 20 coal, 40 gold
   - Production: +5 gold/hour
   - Build time: 6 hours

2. **Barracks**
   - Military training grounds for recruiting soldiers
   - Cost: 40 food, 30 coal, 50 gold
   - Production: -5 food/hour
   - Build time: 8 hours

3. **Blacksmith**
   - Forge for crafting weapons and tools
   - Cost: 25 food, 40 coal, 35 gold
   - Production: -3 coal/hour, +8 gold/hour
   - Build time: 5 hours

4. **Church**
   - Religious building that provides morale boost
   - Cost: 20 food, 25 coal, 60 gold
   - Production: +3 gold/hour
   - Build time: 10 hours

5. **Small House**
   - Basic dwelling for citizens. Increases population capacity
   - Cost: 15 food, 10 coal, 10 gold
   - Production: -2 food/hour
   - Build time: 3 hours

6. **Large House**
   - Spacious dwelling for wealthy citizens. Increases population capacity
   - Cost: 25 food, 20 coal, 30 gold
   - Production: -3 food/hour, +2 gold/hour
   - Build time: 5 hours

7. **Market**
   - Trading post that generates gold from commerce
   - Cost: 30 food, 25 coal, 45 gold
   - Production: +15 gold/hour
   - Build time: 7 hours

8. **Tavern**
   - Popular gathering place that attracts travelers and generates income
   - Cost: 20 food, 15 coal, 35 gold
   - Production: -4 food/hour, +12 gold/hour
   - Build time: 4 hours

## How to Use

### Opening the City Screen
- Press **C** key to toggle the city screen
- The screen can be opened from anywhere in the game
- Currently shows a general building management interface

### Building Process
1. Browse available buildings in the left panel
2. Click on a building card to select it
3. Click "Build" button to add it to the construction queue
4. Resources are deducted immediately upon queuing
5. Monitor construction progress in the right panel (Construction Queue)

### Construction Queue
- Shows all buildings currently being built or waiting to be built
- First item in queue shows "Building" status with remaining time
- Other items show "Queued" status
- Buildings complete automatically after their build time elapses

### Resource Display
- Top section shows current resources: Food, Coal, Gold
- Building cards show resource costs and hourly production/consumption
- Green indicators (+X/hr) show resource generation
- Red indicators (-X/hr) show resource consumption

## Technical Implementation

### Files Created
- `scripts/ui/city_screen.gd` - Main city screen logic
- `scenes/ui/city_screen.tscn` - UI scene definition
- Updated `building.yaml` - Added 8 new city building definitions

### Integration
- Added to `scenes/main.tscn` as a UI overlay
- Connected to existing systems:
  - FactionSystem - for resource management
  - BuildController - for building placement
  - EconomySystem - for production tracking
- Input action `toggle_city_screen` mapped to C key

### Building Data Structure
All city buildings have:
- `category: city_building` - Identifies them as city-specific
- `buildable_tiles: [city]` - Can only be placed in city context
- `build_cost` - Resources required
- `build_time_hours` - Construction duration
- `resource_delta_per_hour` - Hourly production/consumption

## Future Enhancements

### Planned Features (Post-MVP)
- Associate city screen with specific settlement locations
- Visual representation of built buildings in the city
- Building upgrade system
- Population management tied to houses
- Building prerequisites and tech tree
- Special building bonuses and synergies
- City specialization options

### Known Limitations
- Construction queue doesn't persist across save/load (to be implemented)
- Buildings don't have physical placement in cities yet
- No limit on number of buildings (will add later)
- City screen opens globally, not tied to specific cities

## Design Decisions

### Why City Screen?
Following the Phase 2.4 revision, complex buildings are managed through a dedicated screen rather than direct hex placement to:
- Avoid cluttering the hex map
- Provide better UI for building management
- Enable construction queues
- Support future features (upgrades, specializations)
- Follow successful patterns from games like Civilization

### Building Balance
Building costs and production rates were balanced to:
- Encourage economic diversity (not all buildings are always optimal)
- Create meaningful choices (different resource trade-offs)
- Provide various gameplay strategies
- Scale appropriately with game progression

## Usage Examples

### Example 1: Economic Focus
Build Market + Tavern for strong gold generation:
- Market: +15 gold/hr (cost: 30/25/45)
- Tavern: +12 gold/hr, -4 food/hr (cost: 20/15/35)
- Total: +27 gold/hr, -4 food/hr

### Example 2: Military Development
Build Barracks + Archery Range for training units:
- Barracks: -5 food/hr (cost: 40/30/50)
- Archery Range: +5 gold/hr (cost: 30/20/40)
- Supports unit recruitment and training

### Example 3: Population Growth
Build houses to increase settlement capacity:
- Small House: -2 food/hr (cheap, 3hr build)
- Large House: -3 food/hr, +2 gold/hr (moderate cost, 5hr build)
- Balance food production with housing needs

## Testing Checklist

- [x] City screen opens with C key
- [x] All 8 building types load correctly
- [x] Building cards display properly with icons and stats
- [x] Resource costs are validated before queuing
- [x] Construction queue updates when buildings are added
- [x] Resource display shows current amounts
- [ ] Buildings complete after specified time (requires game loop integration)
- [ ] Resource production/consumption applies when building completes
- [ ] UI is responsive and scales properly
- [ ] City screen integrates with save/load system

---

**Implementation Date**: December 26, 2024  
**Status**: Phase 1 Complete (Basic UI and building definitions)  
**Next Steps**: Game loop integration, persistence, visual representation
