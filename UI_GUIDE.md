# Phase 3.2 In-Game UI - Quick Reference

## Overview
Phase 3.2 adds comprehensive in-game UI components to enhance player experience.

## New UI Components

### 1. Enhanced HUD (Top Bar)
**Location**: Always visible at the top of the screen

**Left Section - Resources:**
- 🍎 Food: Amount and production rate (+/-X.X/s)
- ⛏️ Coal: Amount and production rate (+/-X.X/s)
- 💰 Gold: Amount and production rate (+/-X.X/s)

**Center Section - Time & Speed:**
- Current day and time (e.g., "Day 5 - 14:30")
- Game speed indicator (e.g., "Speed: 2x" or "PAUSED")

**Right Section - Faction Info:**
- Faction name (e.g., "Kingdom")
- Territory count (e.g., "Territory: 45")

### 2. Faction Status Panel
**Toggle**: Press **F** key  
**Location**: Left side of screen (slides in/out)

**Contains:**
- Statistics (resources, territory, buildings)
- Relationships with other factions (Allied/Neutral/Hostile)
- Production summary
- Close button

### 3. Minimap
**Location**: Bottom-right corner (200x200 pixels)

**Features:**
- Shows entire world at a glance
- Color-coded terrain (water=blue, grass=green, etc.)
- Faction territory overlay (semi-transparent colors)
- Click on minimap to jump camera to that location
- Updates every 0.5 seconds

### 4. Notification System
**Location**: Top-right corner

**Features:**
- Toast-style notifications with icons
- Up to 3 visible at once
- Auto-dismiss after 5 seconds
- Types: Info (ℹ️), Warning (⚠️), Error (❌), Success (✅)
- Click notification to jump to related location
- Close button on each notification

### 5. Selection Info Panel
**Location**: Bottom-center (appears when selecting objects)

**Shows for Buildings:**
- Building name and type
- Health bar
- Owner faction
- Production info
- Action buttons (e.g., Destroy)

**Shows for Units:**
- Unit name and role
- Health bar
- Current action status
- Owner faction
- Action buttons (e.g., Move, Dismiss)

### 6. Background Music
**Music Tracks:**
- World music: "Desert Sirocco" (plays by default)
- City music: "The Blackpenny Pub" (context-based)

**Features:**
- Smooth 2-second crossfade between tracks
- Volume control available
- Auto-starts on game load

## New Controls

| Key | Action |
|-----|--------|
| **F** | Toggle Faction Status Panel |
| **1** | Set game speed to 1x (normal) |
| **2** | Set game speed to 2x (fast) |
| **3** | Set game speed to 3x (very fast) |
| **4** | Set game speed to 4x (ultra fast) |

## Existing Controls (Unchanged)

| Key/Input | Action |
|-----------|--------|
| **WASD** | Move camera |
| **Mouse Wheel** / **-/+** | Zoom in/out |
| **Left Click** | Select tile or unit |
| **Right Click** | Open action menu |
| **B** | Toggle build mode |
| **I** | Show tile/unit info |
| **T** | Toggle territory overlay |
| **Space** | Pause/unpause game |
| **Esc** | Cancel action, close menus |

## UI Color Coding

### Resource Rates
- **Green (+X.X/s)**: Resources increasing
- **Red (-X.X/s)**: Resources decreasing

### Faction Relationships
- **Green**: Allied (relationship > 30)
- **Yellow**: Neutral (relationship -30 to 30)
- **Red**: Hostile (relationship < -30)

### Notifications
- **Blue**: Information
- **Yellow**: Warning
- **Red**: Error
- **Green**: Success

## Tips for Use

1. **Check Resources Regularly**: The HUD shows real-time resource rates to help plan your economy
2. **Use Faction Panel**: Press F to see detailed stats and relationships with other factions
3. **Navigate with Minimap**: Click on the minimap to quickly move around the world
4. **Watch Notifications**: Important events appear as notifications in the top-right
5. **Adjust Speed**: Use 1/2/3/4 keys to control game speed for different situations
6. **Inspect Objects**: Click on buildings or units to see detailed information

## Performance Notes

- All UI components update every 0.5 seconds for optimal performance
- Panels only update when visible
- Minimap uses efficient image-based rendering
- Notifications are managed with a queue system to prevent spam

## Future Enhancements

Planned improvements (post-MVP):
- Context-sensitive tooltips for all elements
- Notification history/log
- More detailed minimap with building/unit icons
- UI theme customization
- Accessibility options (font scaling, colorblind modes)

---

**Implementation**: Phase 3.2 (December 2024)  
**Status**: ✅ Completed and Integrated
