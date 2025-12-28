# Breakpoint

A strategy simulation game built with Godot 4.5 featuring hex-based world generation, faction management, and economic systems.

## Overview

Breakpoint is a simulation game that combines strategic gameplay elements with procedural world generation. The game features a hexagonal grid-based world, multiple factions with AI-driven behavior, dynamic economy systems, and a day-night cycle.

## Features

- **Hex Grid System**: Navigate and interact with a procedurally generated hexagonal grid world
- **Faction Management**: Multiple factions with unique behaviors and relationships
  - ✅ **NEW**: Faction relationship system (allied, neutral, hostile)
  - ✅ **NEW**: Territory and influence mechanics
  - ✅ **NEW**: Faction-to-faction interactions (trade, diplomacy, conflict)
- **AI Systems**: Advanced AI decision-making
  - ✅ **NEW**: Utility-based AI behavior trees
  - ✅ **NEW**: Resource gathering prioritization
  - ✅ **NEW**: Expansion and defense strategies
- **Economy System**: Complex economic simulation with resource management
- **AI NPCs**: Non-player characters with autonomous decision-making
  - ✅ **NEW**: NPC Dialog System - Interactive conversations with NPCs
    - Dialog trees with branching conversation paths
    - Response options that affect relationships and resources
    - Dynamic dialog content based on NPC faction and relationship status
    - Typewriter text effect for immersive storytelling
- **Dynamic World**: Day-night cycle and procedural world generation
- **Build Mode**: Construction and development mechanics
- **Building Upgrade System**: Progressive building development ✨ **NEW**
  - ✅ **NEW**: Multi-level buildings with upgrade paths
  - ✅ **NEW**: Resource production increases with building level
  - ✅ **NEW**: Upgrade queue system with time-based progression
  - ✅ **NEW**: Upgrade action in tile context menu
- **City Screen**: Dedicated UI for managing city buildings (Phase 3+)
  - ✅ **NEW**: City building management interface (C key)
  - ✅ **NEW**: 8 new city building types: Archery Range, Barracks, Blacksmith, Church, Houses (2 types), Market, Tavern
  - ✅ **NEW**: Construction queue system for buildings
  - ✅ **NEW**: Resource cost validation and display
- **Camera Controls**: Flexible camera system with zoom and movement
- **Player Interaction**: Tile selection, unit control, and action menus
- **In-Game UI**: Comprehensive HUD and game interface (Phase 3.2)
  - ✅ **NEW**: Enhanced HUD with resources, time, and faction info
  - ✅ **NEW**: Faction status panel (F key) - view stats, relationships, and production
  - ✅ **NEW**: Minimap in bottom-right corner for world overview
  - ✅ **NEW**: Notification system for important game events
  - ✅ **NEW**: Background music system with world and city tracks
  - ✅ **NEW**: Game speed controls (1x, 2x, 3x, 4x)

## Controls

### Camera Controls
- **W**: Move forward
- **S**: Move backward
- **A**: Move left
- **D**: Move right
- **Mouse Wheel Up / -**: Zoom in
- **Mouse Wheel Down / =**: Zoom out

### Interaction Controls
- **Left Click**: Select tile or unit
- **E / Space**: Talk to selected NPC (opens dialog)
- **Right Click**: Open action menu
- **Right Click**: Open action menu for selected tile
  - Build, Upgrade Building, Building Info, Move Unit, Tile Info
- **B**: Toggle build mode
- **C**: Open city screen for building management
- **I**: Show tile/unit information
- **F**: Toggle faction status panel
- **T**: Toggle territory influence overlay
- **Space**: Pause/unpause game
- **1/2/3/4**: Set game speed (1x, 2x, 3x, 4x)
- **Esc**: Cancel action, close menus, deselect units

### Building Management
1. **Construct Buildings**: Press **B** to enter build mode, select a building, click on a valid tile
2. **View Building Info**: Right-click on a building tile and select "Building Info"
3. **Upgrade Buildings**: Right-click on a building tile and select "Upgrade Building"
   - Upgrades cost resources and take time to complete
   - Production increases with each level
   - Available upgrades: Well (3 levels), Mine (3 levels), Fortress (2 levels), Market (3 levels), Blacksmith (2 levels)

### Unit Controls
1. **Select Unit**: Left-click on a tile containing a unit
2. **Move Unit**: After selecting, click destination tile or use action menu
3. **Deselect**: Click on empty tile or press Esc

## Requirements

- Godot Engine 4.5 or later
- Operating System: Windows, macOS, or Linux

## Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/batazor/breakpoint.git
   cd breakpoint
   ```

2. Open the project in Godot:
   - Launch Godot Engine 4.5+
   - Click "Import"
   - Navigate to the cloned repository
   - Select the `project.godot` file
   - Click "Import & Edit"

## Running the Game

1. Open the project in Godot Engine
2. Press F5 or click the "Play" button in the editor
3. The game will start from the main scene (`scenes/main.tscn`)

## Project Structure

```
breakpoint/
├── addons/           # Editor plugins and extensions
├── assets/           # Game assets (sprites, textures, models)
├── scenes/           # Game scenes
│   ├── characters/   # Character scenes
│   ├── ui/          # User interface scenes
│   └── main.tscn    # Main game scene
├── scripts/          # Game scripts
│   ├── ai/          # AI systems
│   ├── characters/  # Character scripts
│   ├── hex_grid/    # Hex grid implementation
│   ├── social/      # Social systems
│   ├── ui/          # UI controllers
│   └── game_store.gd # Global game state management
└── project.godot    # Godot project configuration
```

## Key Systems

### Game Store
Central state management system that handles:
- Faction registration and management
- World state coordination
- Event signaling between systems

### Hex Grid System
Procedurally generated hexagonal grid world with:
- Terrain height generation
- Tile-based interactions
- Navigation and pathfinding

### Faction System
- Multiple competing or cooperating factions
- Unique faction behaviors and goals
- Dynamic relationships and interactions
- **NEW**: Faction relationship system (allied, neutral, hostile states)
- **NEW**: Territory control with influence mechanics
- **NEW**: Visual territory influence overlay (toggle with T key)
- **NEW**: Inter-faction interactions (trade, diplomacy, conflict)

### Economy System
- Resource management
- Economic simulation
- Trade and production

### AI System
- Autonomous NPC behavior
- Decision-making algorithms
- Role-based character actions
- **NEW**: Utility-based AI behavior trees
- **NEW**: Action prioritization (resource gathering, expansion, defense)
- **NEW**: Cooldown and inertia mechanics for strategic consistency

## Testing

The project includes automated tests for core systems:

```bash
# Run Faction & AI System tests
godot --headless --script scripts/tests/test_faction_ai_systems.gd

# Run Territory Overlay Visualization tests
godot --headless --script scripts/tests/test_territory_overlay.gd

# Run River Generation tests
godot --headless --script scripts/tests/river_generation_test.gd
```

Tests are automatically run via GitHub Actions on push and pull requests.

## Development Progress

- ✅ **Phase 1**: Core Foundation (Completed)
- ✅ **Phase 2.1**: Player Interaction & Controls (Completed)
- ✅ **Phase 2.2**: Faction & AI Systems (Completed) - [Details](PHASE_2.2_SUMMARY.md)
- ✅ **Phase 2.3**: Economy & Resources (Completed) - [Details](PHASE_2.3_SUMMARY.md)
- ✅ **Phase 2.4**: Building & Development via City Screen (Completed) - [Details](PHASE_2.4_SUMMARY.md)
  - Current buildings managed through hex map placement
  - Territory influence visualization system implemented
  - City screen for complex buildings planned for Phase 3+
- ✅ **Phase 3.2**: In-Game UI (Completed) - [Details](PHASE_3.2_SUMMARY.md)
  - Enhanced HUD with resources, time, and faction info
  - Faction status panel (F key) - view stats, relationships, and production
  - Minimap in bottom-right corner for world overview
  - Notification system for important game events
  - Background music system with world and city tracks
  - Game speed controls (1x, 2x, 3x, 4x)
  - Selection info panels for buildings and units
- 📋 **Phase 3.1**: Main Menu & Game Flow (Planned)
- 📋 **Phase 4**: Polish & Balance (Planned)
- 📚 **Phase 5**: Quest & Narrative System (In Progress) - [Details](QUEST_SYSTEM.md)
  - ✅ **NEW**: Quest Manager - Core quest state management system
  - ✅ **NEW**: Quest Generator - Dynamic quest creation from game events
  - ✅ **NEW**: Quest Templates - Procedural quest generation system
  - ✅ **NEW**: Quest Library - Pre-defined tutorial and faction quests
  - ✅ **NEW**: NPC Quest System - NPCs can pursue their own missions - [Details](NPC_QUEST_SYSTEM.md)
  - 40+ quests across 3-act story structure (designed)
  - Branching narrative with multiple endings (designed)
  - Quest system integrated with dialog and faction systems
  - Complete world-building: The Fractured Lands post-Sundering
  - See also: [GAME_PLOT.md](GAME_PLOT.md), [QUEST_ROADMAP.md](QUEST_ROADMAP.md)

**Current Status**: ~65% complete toward MVP (Quest Manager implemented)  
**Target Release**: Q2 2025

See [ROADMAP.md](ROADMAP.md) for complete development timeline.

## Development

### Editor Plugins

The project includes custom Godot editor plugins:
- **Tile Sides Editor**: Enhanced tools for hex tile editing

### Building

The project uses Godot's built-in build system. To export the game:

1. Go to Project → Export
2. Select your target platform
3. Configure export settings
4. Click "Export Project"

## Roadmap

See [ROADMAP.md](ROADMAP.md) for the detailed MVP development plan, feature timeline, and future version roadmap.

## Contributing

Contributions are welcome! To contribute:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is open source. Please check the repository for license information.

## Acknowledgments

Built with [Godot Engine](https://godotengine.org/) 4.5

## Contact

Repository: [https://github.com/batazor/breakpoint](https://github.com/batazor/breakpoint)
