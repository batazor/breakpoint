# Player Interaction & Controls - Implementation Guide

## Overview

This document describes the implementation of Phase 2.1 Player Interaction & Controls features for the Breakpoint game.

## Features Implemented

### 1. Keyboard Shortcuts

The following keyboard shortcuts have been added to enhance player interaction:

| Key | Action | Description |
|-----|--------|-------------|
| **B** | Toggle Build Mode | Opens/closes the build menu |
| **I** | Show Tile Info | Displays information about the selected tile |
| **Space** | Pause/Unpause | Pauses or resumes the game |
| **Esc** | Cancel Action | Closes menus, deselects units, cancels actions |
| **Right Click** | Open Action Menu | Opens context menu for the selected tile |

### 2. Tile Action Menu

A context menu that appears when right-clicking on a tile or using the action menu shortcut. The menu shows actions relevant to the current tile state:

**Available Actions:**
- **Build Here**: Opens the build menu (available on non-water tiles)
- **Tile Info**: Shows detailed information about the tile
- **Move Unit**: Initiates unit movement (when a unit is selected)
- **Unit Info**: Shows detailed information about the selected unit

The menu automatically positions itself to stay within the viewport boundaries.

### 3. Unit Selection System

Click on a hex tile containing a unit to select it. Selected units are indicated by a yellow glowing ring at their base.

**Features:**
- Visual feedback with emission glow
- Tracks selected unit and its tile position
- Automatically deselects when clicking on an empty tile
- Only one unit can be selected at a time

### 4. Unit Movement System

After selecting a unit, click on a destination tile to move the unit there.

**Movement Features:**
- Smooth tween-based animation (1 second duration)
- Automatic pathfinding (direct path for now, A* for future)
- Validates movement (checks for water, occupancy, bounds)
- Updates hex grid occupancy tracking
- Cancellable with Esc key

**Movement Flow:**
1. Select a unit by clicking on its tile
2. Either:
   - Click "Move Unit" in the action menu, then click destination
   - Simply click the destination tile (when a unit is selected)
3. Watch the unit smoothly move to the new location

### 5. Game Pause

Press Space to pause/unpause the game simulation. The game tree is paused, but UI remains responsive.

## Architecture

### Scripts

#### `PlayerInteractionController`
**Location:** `scripts/player_interaction_controller.gd`

Main coordinator for all player interactions. Handles:
- Keyboard input processing
- Coordination between hex grid, action menu, and unit controller
- State management (build mode, movement mode, pause state)

#### `UnitController`
**Location:** `scripts/unit_controller.gd`

Manages unit selection and movement:
- Finds units at tile positions
- Maintains selection state
- Executes movement commands
- Adds/removes visual selection indicators

#### `TileActionMenu`
**Location:** `scripts/ui/tile_action_menu.gd`, `scenes/ui/tile_action_menu.tscn`

Context menu popup for tile-based actions:
- Dynamically generates action buttons based on tile state
- Emits signals when actions are selected
- Handles positioning and visibility

### Integration

The `PlayerInteractionController` is added to the main scene and connects to:
- `HexGrid`: For tile selection events and position queries
- `TileActionMenu`: For displaying and handling action selections
- `BuildMenu`: For toggling build mode visibility
- `UnitController`: For unit selection and movement

### Character Integration

The system integrates with existing character scripts:
- `CharacterWander`: Added `get_current_tile()` and `set_current_tile()` methods
- `CharacterBrain`: Used to access character components
- Hex grid occupancy tracking prevents multiple units on the same tile

## Usage Examples

### Selecting and Moving a Unit

```gdscript
# In any script with access to PlayerInteractionController
var player_controller = get_node("PlayerInteractionController")
var unit_controller = player_controller.unit_controller

# Programmatically select a unit at a tile
if unit_controller.select_unit_at_tile(Vector2i(5, 3)):
    print("Unit selected!")
    
# Command movement to another tile
if unit_controller.command_move_to_tile(Vector2i(7, 4)):
    print("Unit moving!")
```

### Showing Custom Action Menu

```gdscript
# Get reference to action menu
var action_menu = get_node("TileActionMenu")

# Show for a specific tile
var tile_pos = Vector2i(10, 10)
var biome = "plains"
var has_unit = true
var screen_pos = get_viewport().get_mouse_position()

action_menu.show_for_tile(tile_pos, biome, has_unit, screen_pos)
```

### Listening to Interaction Events

```gdscript
# Connect to PlayerInteractionController signals
func _ready():
    var player_controller = get_node("PlayerInteractionController")
    player_controller.build_mode_toggled.connect(_on_build_mode_changed)
    player_controller.tile_info_requested.connect(_on_tile_info_requested)
    player_controller.game_paused_toggled.connect(_on_pause_changed)

func _on_build_mode_changed(enabled: bool):
    print("Build mode is now: ", "ON" if enabled else "OFF")

func _on_tile_info_requested(tile: Vector2i):
    print("Show info for tile: ", tile)

func _on_pause_changed(paused: bool):
    print("Game is now: ", "PAUSED" if paused else "RUNNING")
```

## Input Configuration

The keyboard shortcuts are configured in `project.godot` under the `[input]` section:

```ini
toggle_build_mode={
"events": [{
"keycode": 66,  # B key
"physical_keycode": 66,
}]
}

show_tile_info={
"events": [{
"keycode": 73,  # I key
"physical_keycode": 73,
}]
}

toggle_pause={
"events": [{
"keycode": 32,  # Space key
"physical_keycode": 32,
}]
}

cancel_action={
"events": [{
"keycode": 4194305,  # Escape key
"physical_keycode": 4194305,
}]
}

open_action_menu={
"events": [{
"button_index": 2,  # Right mouse button
}]
}
```

## Future Enhancements

### Planned Features
1. **A* Pathfinding**: Implement proper pathfinding algorithm for complex paths around obstacles
2. **Movement Path Preview**: Show dotted line indicating the path the unit will take
3. **Multi-Unit Selection**: Select multiple units with Shift+Click or drag selection
4. **Unit Info Panel**: Detailed UI panel showing unit stats, inventory, and actions
5. **Hotkey Hints**: Show keyboard shortcuts in tooltips and UI elements
6. **Formation Movement**: Move multiple units while maintaining formation
7. **Unit Queuing**: Queue multiple movement commands with Shift+Click
8. **Attack Move**: Command units to attack enemies while moving to destination

### Extension Points

To extend the system:

1. **Add New Actions**: Modify `TileActionMenu._build_action_list()` to add context-specific actions
2. **Custom Movement Validation**: Override `UnitController._is_tile_valid_for_movement()` for custom rules
3. **New Keyboard Shortcuts**: Add to `project.godot` and handle in `PlayerInteractionController._input()`
4. **Unit Selection Visuals**: Modify `UnitController._add_selection_visual()` for custom indicators

## Testing

### Manual Testing Checklist

- [ ] Press B to toggle build menu on/off
- [ ] Press I to show tile information in console
- [ ] Press Space to pause/unpause the game
- [ ] Press Esc to cancel actions and close menus
- [ ] Right-click on a tile to open action menu
- [ ] Click on a character to select it (yellow ring appears)
- [ ] Click another tile to move the selected character
- [ ] Selected character moves smoothly to destination
- [ ] Cannot move to water tiles
- [ ] Cannot move to occupied tiles
- [ ] Action menu shows "Move Unit" when unit is selected
- [ ] Action menu shows "Build Here" on non-water tiles
- [ ] Esc deselects the selected unit

### Known Limitations

1. **Direct Path Only**: Units currently move in straight line, no pathfinding around obstacles
2. **Single Unit Selection**: Only one unit can be selected at a time
3. **No Path Preview**: Movement path is not visualized before executing
4. **Limited Unit Detection**: Only works with characters that have CharacterBrain component
5. **No Undo**: Movement commands cannot be cancelled once initiated (except with Esc before destination click)

## Troubleshooting

### Unit Selection Not Working

**Symptoms:** Clicking on units doesn't select them

**Possible Causes:**
1. CharacterBrain not properly attached to character node
2. CharacterWander component missing or not named correctly
3. Character not registered in hex grid occupancy system

**Solution:** Ensure character scene has CharacterBrain → CharacterWander hierarchy

### Movement Not Working

**Symptoms:** Selected unit doesn't move when clicking destination

**Possible Causes:**
1. Destination tile is invalid (water, occupied, out of bounds)
2. Hex grid reference not properly set
3. Character occupancy system not initialized

**Solution:** Check console for error messages, verify hex grid setup

### Action Menu Not Appearing

**Symptoms:** Right-click doesn't show action menu

**Possible Causes:**
1. TileActionMenu scene not added to main scene
2. PlayerInteractionController not connected to action menu
3. No tile selected

**Solution:** Verify scene hierarchy and node paths in PlayerInteractionController

## Performance Considerations

- **Unit Selection**: O(n) search through character nodes - consider spatial partitioning for large numbers of units
- **Movement**: Single tween per unit - efficient for small to medium numbers of units
- **Action Menu**: Dynamic button creation - cached after first show for better performance
- **Input Handling**: Event-based, no polling - efficient for keyboard shortcuts

## Compatibility

- **Godot Version**: 4.5+
- **Platform**: Cross-platform (Windows, macOS, Linux)
- **Dependencies**: Requires existing HexGrid, CharacterBrain, and CharacterWander systems

---

**Last Updated:** December 24, 2024
**Version:** 1.0 (MVP Phase 2.1)
**Status:** Feature Complete, Testing Phase
