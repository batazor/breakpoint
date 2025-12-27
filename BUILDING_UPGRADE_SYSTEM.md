# Building Upgrade System Documentation

## Overview

The Building Upgrade System allows players to upgrade existing buildings to higher levels, improving their production rates and capabilities. This feature enhances the strategic depth of the game by providing long-term building development paths.

## Features

### Core Functionality

1. **Multi-Level Buildings**: Buildings can now have multiple levels (configurable via `max_level` property)
2. **Progressive Upgrades**: Each level requires resources and time to upgrade
3. **Production Bonuses**: Upgraded buildings produce more resources per hour
4. **Upgrade Queue**: Upgrades are queued similar to construction and process over time

### Supported Buildings with Upgrades

#### Resource Buildings

1. **Well** (Max Level: 3)
   - Level 1: +10 food/hr (base)
   - Level 2: +15 food/hr (+5 bonus) - Cost: 10 coal, 15 gold, 2 hours
   - Level 3: +25 food/hr (+10 more) - Cost: 20 coal, 30 gold, 3 hours

2. **Mine** (Max Level: 3)
   - Level 1: +5 coal/hr (base)
   - Level 2: +8 coal/hr (+3 bonus) - Cost: 20 gold, 10 food, 3 hours
   - Level 3: +13 coal/hr (+5 more) - Cost: 40 gold, 20 food, 4 hours

3. **Fortress** (Max Level: 2)
   - Level 1: +10 gold/hr (base)
   - Level 2: +25 gold/hr (+15 bonus) - Cost: 100 food, 100 coal, 200 gold, 10 hours

#### City Buildings

1. **Market** (Max Level: 3)
   - Level 1: +15 gold/hr (base)
   - Level 2: +25 gold/hr (+10 bonus) - Cost: 40 food, 35 coal, 60 gold, 5 hours
   - Level 3: +40 gold/hr (+15 more) - Cost: 60 food, 50 coal, 90 gold, 7 hours

2. **Blacksmith** (Max Level: 2)
   - Level 1: +8 gold/hr, -3 coal/hr (base)
   - Level 2: +15 gold/hr, -3 coal/hr (+7 gold bonus) - Cost: 35 food, 60 coal, 50 gold, 4 hours

## Technical Implementation

### GameResource Extensions

New properties added to `GameResource` class:
- `max_level: int` - Maximum level a building can reach (default: 1, meaning no upgrades)
- `upgrade_levels: Array[Dictionary]` - Array of upgrade data for each level

Each upgrade level dictionary contains:
```gdscript
{
    "level": int,                           # Target level (e.g., 2, 3)
    "upgrade_cost": Dictionary,             # Resource costs (e.g., {"coal": 10, "gold": 15})
    "upgrade_time_hours": int,              # Time to complete upgrade
    "resource_delta_bonus": Dictionary      # Additional production (e.g., {"food": 5})
}
```

New methods:
- `can_upgrade(current_level: int) -> bool` - Check if building can be upgraded
- `get_upgrade_cost(current_level: int) -> Dictionary` - Get cost for next level
- `get_upgrade_time(current_level: int) -> int` - Get upgrade time in hours
- `get_resource_delta_at_level(level: int) -> Dictionary` - Get total production at specific level

### BuildController Extensions

New data structures:
- `building_level: Dictionary` - Tracks current level of each building (axial_key -> int)
- `_upgrade_queue: Array` - Queue of pending upgrades

New methods:
- `get_building_level(axial: Vector2i) -> int` - Get current level of a building
- `can_upgrade_building(axial: Vector2i, resource: GameResource, owner_id: StringName) -> bool` - Check if upgrade is possible
- `upgrade_building(axial: Vector2i, resource: GameResource, owner_id: StringName) -> bool` - Start building upgrade
- `get_upgrade_queue_for_faction(faction_id: StringName) -> Array[Dictionary]` - Get faction's upgrade queue
- `_process_upgrade_queue(hours_passed: float)` - Process upgrades over time
- `_complete_upgrade(upgrade_data: Dictionary)` - Complete an upgrade

### EconomySystem Integration

The economy system now accounts for building levels when calculating production:

1. Loads GameResource definitions with upgrade data from `building.yaml`
2. Queries BuildController for building levels
3. Applies level-appropriate production rates using `get_resource_delta_at_level()`

New methods:
- `_load_resources_from_yaml(path: String)` - Parse full building data including upgrades
- `_add_type_delta_with_level(totals, faction_id, type_id, level)` - Apply production based on level
- `_parse_resources_yaml(text: String) -> Array` - Enhanced YAML parser supporting upgrade_levels

## YAML Configuration Format

Example building definition with upgrades:

```yaml
resources:
  well:
    id: well
    title: Well
    description: "Fresh spring for nearby tiles."
    icon: res://icon.svg
    scene: res://assets/resources/well.gltf.glb
    category: resource
    buildable_tiles:
      - plains
      - sand
    resource_delta_per_hour:
      food: 10
    build_cost:
      coal: 5
      gold: 5
    build_time_hours: 2
    max_level: 3
    upgrade_levels:
      - level: 2
        upgrade_cost:
          coal: 10
          gold: 15
        upgrade_time_hours: 2
        resource_delta_bonus:
          food: 5
      - level: 3
        upgrade_cost:
          coal: 20
          gold: 30
        upgrade_time_hours: 3
        resource_delta_bonus:
          food: 10
```

## Usage Guide

### For Players

1. **Check Building Level**: Select a building to see its current level
2. **View Upgrade Options**: If the building is upgradable, upgrade information will be displayed
3. **Start Upgrade**: Click upgrade button (when implemented in UI)
4. **Monitor Progress**: Upgrades appear in the construction/upgrade queue
5. **Production Increase**: Once upgrade completes, production automatically increases

### For Developers

#### Adding Upgrades to a Building

1. Edit `building.yaml`
2. Set `max_level` to desired maximum (e.g., 3)
3. Add `upgrade_levels` array with one entry per upgrade level
4. Each entry must have: level, upgrade_cost, upgrade_time_hours, resource_delta_bonus

#### Checking if Building Can Be Upgraded

```gdscript
var build_controller = get_tree().get_first_node_in_group("build_controller")
var axial = Vector2i(5, 3)  # Building position
var resource = # ... get GameResource for this building type
var faction_id = StringName("kingdom")

if build_controller.can_upgrade_building(axial, resource, faction_id):
    print("Building can be upgraded!")
```

#### Starting an Upgrade

```gdscript
var success = build_controller.upgrade_building(axial, resource, faction_id)
if success:
    print("Upgrade started!")
else:
    print("Cannot upgrade (insufficient resources or already upgrading)")
```

## Future Enhancements

### Planned Features

1. **UI Integration**: Add upgrade buttons to city screen and building selection panels
2. **Visual Indicators**: Show building level on buildings (e.g., small number badge)
3. **Upgrade Previews**: Show production changes before confirming upgrade
4. **Bulk Upgrades**: Queue multiple buildings for upgrade at once
5. **Upgrade Requirements**: Add prerequisites (e.g., "requires level 2 market")
6. **Visual Upgrades**: Change building appearance at higher levels
7. **Special Abilities**: Unlock new capabilities at certain levels

### Technical TODOs

- [ ] Add building level display to UI
- [ ] Create upgrade confirmation dialog
- [ ] Add upgrade button to resource cards when viewing existing buildings
- [ ] Implement upgrade cancellation
- [ ] Save/load building levels
- [ ] Add upgrade notifications
- [ ] Create visual effects for upgrade completion

## Testing

### Manual Testing Checklist

1. Build a well, mine, or market
2. Wait for construction to complete
3. Verify building is at level 1
4. Check that production matches level 1 rate
5. Call upgrade_building() method programmatically
6. Verify upgrade cost is deducted from resources
7. Wait for upgrade to complete
8. Check building is now at level 2
9. Verify production increased to level 2 rate

### Automated Tests

See `scripts/tests/test_building_upgrade.gd` for unit tests of upgrade logic.

## Balancing Notes

Upgrade costs and benefits are designed with these principles:

1. **Payback Time**: Upgrades should pay for themselves within 10-15 game hours
2. **Increasing Costs**: Each level costs significantly more than the previous
3. **Strategic Choices**: Players must choose which buildings to upgrade first
4. **Late Game Content**: Higher levels provide content for established players

## Known Limitations

1. Building levels are not yet saved/loaded (will be lost on game restart)
2. No UI for triggering upgrades (must be done programmatically for now)
3. Upgrading doesn't change building appearance
4. Cannot cancel upgrades once started
5. No upgrade prerequisites or requirements system

## Version History

- **v1.0** (Initial Implementation): Core upgrade system with BuildController, EconomySystem integration, and YAML configuration
