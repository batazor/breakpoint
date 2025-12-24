# Player Interaction System Architecture

## Component Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         Main Scene                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌────────────────┐         ┌─────────────────────┐            │
│  │   HexGrid      │────────▶│ PlayerInteraction   │            │
│  │                │ signals  │    Controller       │            │
│  │ • tile_selected│         │                     │            │
│  │ • hover        │         │ • Keyboard input    │            │
│  │ • collision    │         │ • State management  │            │
│  └────────────────┘         │ • Coordination      │            │
│         │                    └─────────┬───────────┘            │
│         │                              │                         │
│         │                              │                         │
│         │                    ┌─────────▼───────────┐            │
│         │                    │   UnitController    │            │
│         │                    │                     │            │
│         │                    │ • Select units      │            │
│         │                    │ • Track selection   │            │
│         └───────────────────▶│ • Execute movement  │            │
│           occupancy          │ • Visual feedback   │            │
│           queries            └─────────┬───────────┘            │
│                                        │                         │
│                                        │                         │
│                              ┌─────────▼───────────┐            │
│                              │    Characters       │            │
│                              │                     │            │
│                              │ • CharacterBrain    │            │
│                              │ • CharacterWander   │            │
│                              │ • Movement logic    │            │
│                              └─────────────────────┘            │
│                                                                   │
│  ┌────────────────┐         ┌─────────────────────┐            │
│  │ TileActionMenu │◀────────│ PlayerInteraction   │            │
│  │                │         │    Controller       │            │
│  │ • Build        │ actions  │                     │            │
│  │ • Tile Info    │         │ handles action      │            │
│  │ • Move Unit    │         │ selection signals   │            │
│  │ • Unit Info    │         │                     │            │
│  └────────────────┘         └─────────────────────┘            │
│                                                                   │
│  ┌────────────────┐         ┌─────────────────────┐            │
│  │   BuildMenu    │◀────────│ PlayerInteraction   │            │
│  │                │         │    Controller       │            │
│  │ • Visibility   │ toggle   │                     │            │
│  │ • Build items  │         │ build_mode_toggled  │            │
│  └────────────────┘         └─────────────────────┘            │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘
```

## Interaction Flow Diagrams

### Unit Selection Flow

```
┌────────┐    ┌────────────┐    ┌───────────┐    ┌──────────┐
│ Player │    │  HexGrid   │    │  Player   │    │   Unit   │
│        │    │            │    │Interaction│    │Controller│
└───┬────┘    └─────┬──────┘    └─────┬─────┘    └────┬─────┘
    │               │                  │               │
    │ Left Click    │                  │               │
    ├──────────────▶│                  │               │
    │               │ tile_selected    │               │
    │               ├─────────────────▶│               │
    │               │ (axial, biome)   │               │
    │               │                  │ select_unit_  │
    │               │                  │ at_tile()     │
    │               │                  ├──────────────▶│
    │               │                  │               │
    │               │                  │               │ _find_unit_
    │               │                  │               │ at_tile()
    │               │                  │               │
    │               │◀─────────────────┼───────────────┤
    │               │ is_character_    │               │
    │               │ tile_occupied()  │               │
    │               │                  │               │
    │               ├─────────────────▶│               │
    │               │ true/false       │               │
    │               │                  │               │
    │               │                  │               │ _add_
    │               │                  │               │ selection_
    │               │                  │               │ visual()
    │               │                  │               │
    │               │                  │ unit_selected │
    │               │                  │ (signal)      │
    │◀──────────────┼──────────────────┼───────────────┤
    │ Unit now has  │                  │               │
    │ yellow ring   │                  │               │
    │               │                  │               │
```

### Unit Movement Flow

```
┌────────┐    ┌────────────┐    ┌───────────┐    ┌──────────┐    ┌──────────┐
│ Player │    │  HexGrid   │    │  Player   │    │   Unit   │    │Character │
│        │    │            │    │Interaction│    │Controller│    │ Wander   │
└───┬────┘    └─────┬──────┘    └─────┬─────┘    └────┬─────┘    └────┬─────┘
    │               │                  │               │               │
    │ Click dest    │                  │               │               │
    │ tile          │                  │               │               │
    ├──────────────▶│                  │               │               │
    │               │ tile_selected    │               │               │
    │               ├─────────────────▶│               │               │
    │               │                  │ command_move_ │               │
    │               │                  │ to_tile()     │               │
    │               │                  ├──────────────▶│               │
    │               │                  │               │               │
    │               │                  │               │ _is_tile_     │
    │               │                  │               │ valid_for_    │
    │               │                  │               │ movement()    │
    │               │◀─────────────────┼───────────────┤               │
    │               │ get_tile_biome   │               │               │
    │               ├─────────────────▶│               │               │
    │               │ is_occupied()    │               │               │
    │               │                  │               │               │
    │               │                  │               │ _execute_     │
    │               │                  │               │ movement()    │
    │               │                  │               │               │
    │               │◀─────────────────┼───────────────┤               │
    │               │ vacate_character_│               │               │
    │               │ tile()           │               │               │
    │               │                  │               │               │
    │               │◀─────────────────┼───────────────┤               │
    │               │ request_character│               │               │
    │               │ _occupy()        │               │               │
    │               │                  │               │               │
    │               │                  │               │ create_tween()│
    │               │                  │               │ (1 sec)       │
    │               │                  │               ├──────────────▶│
    │               │                  │               │ set_current_  │
    │               │                  │               │ tile()        │
    │◀──────────────┼──────────────────┼───────────────┼───────────────┤
    │ Unit smoothly │                  │               │               │
    │ moves to new  │                  │               │               │
    │ location      │                  │               │               │
    │               │                  │               │               │
```

### Action Menu Flow

```
┌────────┐    ┌────────────┐    ┌───────────┐    ┌──────────────┐
│ Player │    │  HexGrid   │    │  Player   │    │TileAction    │
│        │    │            │    │Interaction│    │Menu          │
└───┬────┘    └─────┬──────┘    └─────┬─────┘    └──────┬───────┘
    │               │                  │                 │
    │ Right Click   │                  │                 │
    │ (or hotkey)   │                  │                 │
    ├──────────────────────────────────▶│                 │
    │               │                  │ _open_action_   │
    │               │                  │ menu_at_cursor()│
    │               │                  │                 │
    │               │◀─────────────────┤                 │
    │               │ get_selected_    │                 │
    │               │ axial()          │                 │
    │               │                  │                 │
    │               │◀─────────────────┤                 │
    │               │ get_tile_biome_  │                 │
    │               │ name()           │                 │
    │               │                  │ show_for_tile() │
    │               │                  ├────────────────▶│
    │               │                  │ (tile, biome,   │
    │               │                  │  has_unit, pos) │
    │               │                  │                 │
    │               │                  │                 │ _build_
    │               │                  │                 │ action_list()
    │               │                  │                 │
    │◀──────────────┼──────────────────┼─────────────────┤
    │ Action menu   │                  │                 │ popup()
    │ appears with  │                  │                 │
    │ buttons       │                  │                 │
    │               │                  │                 │
    │ Click "Move   │                  │                 │
    │ Unit" button  │                  │                 │
    ├──────────────────────────────────┼─────────────────▶│
    │               │                  │                 │
    │               │                  │ action_selected │
    │               │                  │ (signal)        │
    │               │                  │◀────────────────┤
    │               │                  │ "move_unit"     │
    │               │                  │                 │
    │               │                  │ _start_unit_    │
    │               │                  │ movement()      │
    │               │                  │                 │
    │◀──────────────┼──────────────────┤                 │
    │ Awaiting      │                  │                 │
    │ destination   │                  │                 │
    │               │                  │                 │
```

### Keyboard Shortcut Flow

```
┌────────┐    ┌───────────┐    ┌──────────┐    ┌──────────────┐
│ Player │    │  Input    │    │  Player  │    │ Target       │
│        │    │  System   │    │Interaction│   │ System       │
└───┬────┘    └─────┬─────┘    └─────┬────┘    └──────┬───────┘
    │               │                 │                │
    │ Press "B"     │                 │                │
    ├──────────────▶│                 │                │
    │               │ InputEvent      │                │
    │               │ "toggle_build_  │                │
    │               │ mode"           │                │
    │               ├────────────────▶│                │
    │               │                 │ _toggle_build_ │
    │               │                 │ mode()         │
    │               │                 │                │
    │               │                 │ build_mode_    │
    │               │                 │ toggled        │
    │               │                 │ (signal)       │
    │               │                 ├───────────────▶│
    │               │                 │ true/false     │ BuildMenu
    │               │                 │                │ .visible
    │◀──────────────┼─────────────────┼────────────────┤
    │ Build menu    │                 │                │
    │ shows/hides   │                 │                │
    │               │                 │                │
    │ Press "I"     │                 │                │
    ├──────────────▶│                 │                │
    │               │ InputEvent      │                │
    │               │ "show_tile_     │                │
    │               │ info"           │                │
    │               ├────────────────▶│                │
    │               │                 │ _show_tile_    │
    │               │                 │ info()         │
    │               │                 │                │
    │               │                 │ tile_info_     │
    │               │                 │ requested      │
    │               │                 │ (signal)       │
    │               │                 ├───────────────▶│
    │               │                 │ Vector2i       │
    │◀──────────────┼─────────────────┼────────────────┤
    │ Info printed  │                 │                │ Console/UI
    │ to console    │                 │                │
    │               │                 │                │
    │ Press "Esc"   │                 │                │
    ├──────────────▶│                 │                │
    │               │ InputEvent      │                │
    │               │ "cancel_action" │                │
    │               ├────────────────▶│                │
    │               │                 │ _cancel_       │
    │               │                 │ current_action()│
    │               │                 │                │
    │               │                 │ • Hide menus   │
    │               │                 │ • Deselect unit│
    │               │                 │ • Exit build   │
    │◀──────────────┼─────────────────┤                │
    │ Action        │                 │                │
    │ cancelled     │                 │                │
    │               │                 │                │
```

## State Management

### PlayerInteractionController States

```
┌─────────────────────────────────────────────────────────┐
│ PlayerInteractionController State Variables              │
├─────────────────────────────────────────────────────────┤
│                                                           │
│ _build_mode_active: bool                                │
│   └─ Controls BuildMenu visibility                       │
│   └─ Toggled by: "B" key, Build action in menu         │
│                                                           │
│ _game_paused: bool                                       │
│   └─ Controls get_tree().paused                         │
│   └─ Toggled by: "Space" key                            │
│                                                           │
│ _awaiting_move_destination: bool                        │
│   └─ Indicates waiting for player to click destination  │
│   └─ Set by: "Move Unit" action                         │
│   └─ Cleared by: Destination click, Esc, new selection │
│                                                           │
└─────────────────────────────────────────────────────────┘
```

### UnitController States

```
┌─────────────────────────────────────────────────────────┐
│ UnitController State Variables                           │
├─────────────────────────────────────────────────────────┤
│                                                           │
│ selected_unit: Node3D                                    │
│   └─ Currently selected unit node                       │
│   └─ null when no unit selected                         │
│                                                           │
│ selected_unit_tile: Vector2i                            │
│   └─ Tile position of selected unit                     │
│   └─ Vector2i(-1, -1) when no unit selected            │
│                                                           │
│ hex_grid: Node3D                                        │
│   └─ Reference to HexGrid for queries                   │
│   └─ Set in _ready()                                    │
│                                                           │
└─────────────────────────────────────────────────────────┘
```

## Signal Flow

```
┌─────────────────────────────────────────────────────────┐
│                      Signal Emissions                     │
├─────────────────────────────────────────────────────────┤
│                                                           │
│ HexGrid.tile_selected(axial, biome, surface_pos)        │
│   └─ Emitted when: Player clicks on tile                │
│   └─ Connected to: PlayerInteractionController          │
│                                                           │
│ TileActionMenu.action_selected(action_name)             │
│   └─ Emitted when: Player clicks action button          │
│   └─ Connected to: PlayerInteractionController          │
│                                                           │
│ UnitController.unit_selected(unit, axial)               │
│   └─ Emitted when: Unit successfully selected           │
│   └─ Connected to: PlayerInteractionController          │
│                                                           │
│ UnitController.unit_deselected()                        │
│   └─ Emitted when: Unit deselected                      │
│   └─ Connected to: PlayerInteractionController          │
│                                                           │
│ UnitController.unit_move_commanded(unit, from, to)      │
│   └─ Emitted when: Movement command issued              │
│   └─ Connected to: (optional) Game analytics/logging    │
│                                                           │
│ PlayerInteractionController.build_mode_toggled(enabled) │
│   └─ Emitted when: Build mode state changes             │
│   └─ Connected to: (optional) External UI systems       │
│                                                           │
│ PlayerInteractionController.tile_info_requested(tile)   │
│   └─ Emitted when: Info requested for tile              │
│   └─ Connected to: (optional) Info panel UI             │
│                                                           │
│ PlayerInteractionController.game_paused_toggled(paused) │
│   └─ Emitted when: Pause state changes                  │
│   └─ Connected to: (optional) Pause menu UI             │
│                                                           │
└─────────────────────────────────────────────────────────┘
```

## Data Flow Summary

1. **Input → Controller**: Keyboard/mouse events captured by PlayerInteractionController
2. **Controller → Grid**: Queries hex grid for tile info, occupancy, positions
3. **Controller → Unit**: Commands unit controller for selection and movement
4. **Unit → Character**: Updates character wander component tile positions
5. **Controller → UI**: Shows/hides menus, triggers UI updates
6. **UI → Controller**: Reports user actions from buttons and menus
7. **Controller → Game**: Emits signals for game state changes (pause, build mode)

## Performance Notes

- **Event-Driven**: System uses signals, not polling - efficient
- **Lazy Evaluation**: Action menus built only when shown
- **Single Pass**: Unit finding is O(n) but only on selection
- **Cached References**: Node paths resolved once in _ready()
- **Tween-Based**: Movement uses Godot's optimized Tween system

---

**Created:** December 24, 2024
**Version:** 1.0
